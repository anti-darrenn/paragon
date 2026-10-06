/**
 * Firestore usage against the Spark plan's daily quota, for the studio.
 *
 *   node usage.js            # print today's and yesterday's counts
 *   node usage.js --apply    # also store them in _meta/usage
 *
 * Spark allows 50,000 reads, 20,000 writes and 20,000 deletes a day, for
 * every student together, and the day is the *Pacific* calendar day. When a
 * quota runs out every request fails until midnight Pacific, and the app
 * shows its "very busy" banner (lib/core/data/quota_status.dart). This job
 * is how the team sees that coming instead of finding out from students.
 *
 * The counts come from Cloud Monitoring
 * (firestore.googleapis.com/document/{read,write,delete}_count), which is
 * free and lags real usage by a few minutes. Reading them needs the
 * service account to hold **Monitoring Viewer** (roles/monitoring.viewer)
 * on the project; without it the job says so and exits cleanly, because a
 * failing scheduled step sends an email every 15 minutes.
 *
 * Stores one document, _meta/usage:
 *   { updatedAt, quota: {reads, writes, deletes},
 *     days: { 'YYYY-MM-DD': {reads, writes, deletes} } }   // last 7 days
 * The studio reads it (the rule allows reviewers only). One write per run.
 */
const { initAdmin } = require("./credential");

const APPLY = process.argv.includes("--apply");
const QUOTA = { reads: 50000, writes: 20000, deletes: 20000 };
const METRICS = {
  reads: "firestore.googleapis.com/document/read_count",
  writes: "firestore.googleapis.com/document/write_count",
  deletes: "firestore.googleapis.com/document/delete_count",
};

/** Midnight Pacific at the start of the quota day containing `now`, in UTC.
 * Mirrors quotaResetUtc in lib/core/data/quota_status.dart: daylight time
 * runs from 10:00 UTC on the second Sunday of March to 09:00 UTC on the
 * first Sunday of November. */
function nthSunday(year, month, n) {
  const first = new Date(Date.UTC(year, month, 1));
  const toSunday = (7 - first.getUTCDay()) % 7;
  return new Date(Date.UTC(year, month, 1 + toSunday + 7 * (n - 1)));
}
function pacificOffsetHours(utc) {
  const y = utc.getUTCFullYear();
  const start = nthSunday(y, 2, 2).getTime() + 10 * 3600e3;
  const end = nthSunday(y, 10, 1).getTime() + 9 * 3600e3;
  const t = utc.getTime();
  return t >= start && t < end ? -7 : -8;
}
function quotaDayStart(now) {
  const local = new Date(now.getTime() + pacificOffsetHours(now) * 3600e3);
  const midnightAsUtc = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate()
  );
  // The offset in force at that midnight, found by trying both.
  for (const h of [7, 8]) {
    const candidate = new Date(midnightAsUtc + h * 3600e3);
    if (pacificOffsetHours(candidate) === -h) return candidate;
  }
  return new Date(midnightAsUtc + 8 * 3600e3);
}
function dayKey(start) {
  const local = new Date(start.getTime() + pacificOffsetHours(start) * 3600e3);
  return local.toISOString().slice(0, 10);
}

async function sumMetric(token, projectId, metric, start, end) {
  const seconds = Math.max(60, Math.round((end - start) / 1000));
  const params = new URLSearchParams({
    filter: `metric.type="${metric}"`,
    "interval.startTime": start.toISOString(),
    "interval.endTime": end.toISOString(),
    "aggregation.alignmentPeriod": `${seconds}s`,
    "aggregation.perSeriesAligner": "ALIGN_SUM",
    "aggregation.crossSeriesReducer": "REDUCE_SUM",
  });
  const url =
    `https://monitoring.googleapis.com/v3/projects/${projectId}/timeSeries?` +
    params;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 403) {
    const e = new Error("permission");
    e.permission = true;
    throw e;
  }
  if (!res.ok) throw new Error(`Monitoring ${res.status}: ${await res.text()}`);
  const body = await res.json();
  let total = 0;
  for (const series of body.timeSeries || []) {
    for (const p of series.points || []) {
      total += Number(p.value.int64Value || p.value.doubleValue || 0);
    }
  }
  return total;
}

async function main() {
  const admin = initAdmin();
  const app = admin.app();
  const projectId =
    app.options.projectId ||
    app.options.credential.projectId ||
    process.env.GCLOUD_PROJECT;
  const { access_token: token } = await app.options.credential.getAccessToken();

  const now = new Date();
  const days = {};
  // Today so far and the six full days before it.
  let end = now;
  let start = quotaDayStart(now);
  try {
    for (let i = 0; i < 7; i++) {
      const row = {};
      for (const [name, metric] of Object.entries(METRICS)) {
        row[name] = await sumMetric(token, projectId, metric, start, end);
      }
      days[dayKey(start)] = row;
      end = start;
      start = quotaDayStart(new Date(start.getTime() - 3600e3));
    }
  } catch (e) {
    if (e.permission) {
      console.log(
        "::notice::The service account cannot read Cloud Monitoring. Grant it " +
          "Monitoring Viewer (roles/monitoring.viewer) on the project to " +
          "record usage. Skipping."
      );
      await app.delete();
      return;
    }
    throw e;
  }

  for (const [day, row] of Object.entries(days)) {
    const pct = (k) => `${Math.round((100 * row[k]) / QUOTA[k])}%`;
    console.log(
      `${day}  reads ${row.reads} (${pct("reads")})  writes ${row.writes} ` +
        `(${pct("writes")})  deletes ${row.deletes} (${pct("deletes")})`
    );
  }

  if (!APPLY) {
    console.log("\nDry run: nothing written. Re-run with --apply.");
    await app.delete();
    return;
  }
  await admin.firestore().doc("_meta/usage").set({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    quota: QUOTA,
    days,
  });
  console.log("Wrote _meta/usage.");
  await app.delete();
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
  });
}

module.exports = { quotaDayStart, dayKey };
