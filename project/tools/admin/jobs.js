#!/usr/bin/env node
/**
 * Scheduled maintenance jobs — the Blaze-free alternative to Cloud
 * Functions.
 *
 * ── Why this exists ──────────────────────────────────────────────────
 *
 * Blaze is not a product we need; it is the billing plan that unlocks
 * *Cloud Functions*, i.e. Google-hosted compute. Everything Cloud
 * Functions would do here — deleting stale guests, reaping orphaned
 * documents, computing streaks the client is not trusted to compute — is
 * plain `firebase-admin` code. The Admin SDK bypasses security rules and
 * runs anywhere Node runs. The only thing Cloud Functions actually
 * provides is a place to run it and a trigger.
 *
 * So: same logic, run from a free scheduler instead. The repo already
 * uses `firebase-admin` with a service account for the scraper, so there
 * is no new infrastructure and no new vendor.
 *
 * ── What this cannot do ──────────────────────────────────────────────
 *
 * Cloud Functions can fire *on an event* (a document write, an account
 * deletion) within milliseconds. A scheduled job cannot. Anything needing
 * real-time server authority — rejecting a bad write as it happens —
 * still needs Functions or an always-on server. For derived values like
 * streaks and XP that is fine: `attempts` carries a server timestamp and
 * is the source of truth, so recomputing on a schedule is correct, just
 * eventually.
 *
 * ── Usage ────────────────────────────────────────────────────────────
 *
 *   node jobs.js --job=guests   [--days=30] [--apply]
 *   node jobs.js --job=orphans  [--apply]
 *   node jobs.js --job=streaks  [--apply]
 *   node jobs.js --job=counts   [--apply]
 *   node jobs.js --job=all      [--apply]
 *
 * Dry run by default. Nothing is written without --apply.
 *
 * Credentials: set GOOGLE_APPLICATION_CREDENTIALS to a service account
 * JSON path, or FIREBASE_SERVICE_ACCOUNT to its contents (for CI), or
 * drop the file at ../scraper/data/serviceAccountKey.json.
 */
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// ─── Credentials ─────────────────────────────────────────────────────

function loadCredential() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
    );
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return admin.credential.applicationDefault();
  }
  const local = path.join(
    __dirname,
    "..",
    "scraper",
    "data",
    "serviceAccountKey.json"
  );
  if (fs.existsSync(local)) {
    return admin.credential.cert(require(local));
  }
  throw new Error(
    "No credentials. Set FIREBASE_SERVICE_ACCOUNT or " +
      "GOOGLE_APPLICATION_CREDENTIALS, or place serviceAccountKey.json " +
      "in tools/scraper/data/."
  );
}

admin.initializeApp({ credential: loadCredential() });
const db = admin.firestore();
const auth = admin.auth();

// ─── Args ────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const JOB = (args.find((a) => a.startsWith("--job=")) || "--job=all").split(
  "="
)[1];
const DAYS = Number(
  (args.find((a) => a.startsWith("--days=")) || "").split("=")[1] || 30
);

const log = (...a) => console.log(...a);
const mode = () => (APPLY ? "APPLY" : "DRY RUN");

async function deleteDocs(refs) {
  if (!APPLY) return refs.length;
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + 400)) batch.delete(ref);
    await batch.commit();
  }
  return refs.length;
}

// ─── Job: stale guest accounts ───────────────────────────────────────

/**
 * Deletes anonymous accounts older than [DAYS] that never answered a
 * question.
 *
 * Every tap of "Browse as Guest" creates a permanent Auth user and a
 * Firestore document. Without this they accumulate for the life of the
 * project. The "never answered anything" condition is deliberate: a guest
 * who has practised has something worth keeping, and deleting it would be
 * destroying a student's work to save a row.
 */
async function jobGuests() {
  log(`\n── Stale guest accounts (older than ${DAYS} days) [${mode()}]`);

  const cutoff = Date.now() - DAYS * 24 * 60 * 60 * 1000;
  let pageToken;
  let examined = 0;
  let deleted = 0;

  do {
    const page = await auth.listUsers(1000, pageToken);
    pageToken = page.pageToken;

    for (const user of page.users) {
      const isAnon = user.providerData.length === 0;
      if (!isAnon) continue;

      const createdMs = Date.parse(user.metadata.creationTime);
      if (!Number.isFinite(createdMs) || createdMs > cutoff) continue;

      examined++;

      // One aggregate, not a document read, and limited to a single hit.
      const agg = await db
        .collection("attempts")
        .where("userId", "==", user.uid)
        .limit(1)
        .count()
        .get();
      if (agg.data().count > 0) continue;

      if (APPLY) {
        await db.collection("users").doc(user.uid).delete().catch(() => {});
        await auth.deleteUser(user.uid).catch(() => {});
      }
      deleted++;
    }
  } while (pageToken);

  log(`   ${examined} idle guests examined, ${deleted} ${APPLY ? "deleted" : "would be deleted"}`);
}

// ─── Job: orphaned documents ─────────────────────────────────────────

/**
 * Removes documents whose owner no longer exists in Auth.
 *
 * The in-app deletion flow deletes the auth user first and then its
 * documents, so an interruption mid-cleanup leaves exactly this. Also
 * catches anything deleted straight from the Firebase console.
 */
async function jobOrphans() {
  log(`\n── Orphaned documents [${mode()}]`);

  const liveUids = new Set();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    pageToken = page.pageToken;
    for (const u of page.users) liveUids.add(u.uid);
  } while (pageToken);
  log(`   ${liveUids.size} live auth users`);

  // Keep in step with AccountRepository.deleteOwnedDocuments. A null
  // field means the document id is itself the uid.
  for (const [collection, field] of [
    ["users", null],
    ["progress", null],
    ["attempts", "userId"],
    ["flags", "userId"],
  ]) {
    const snap = await db.collection(collection).get();
    const orphans = snap.docs.filter((d) => {
      const uid = field ? d.data()[field] : d.id;
      return typeof uid === "string" && !liveUids.has(uid);
    });
    const n = await deleteDocs(orphans.map((d) => d.ref));
    log(`   ${collection}: ${n} ${APPLY ? "deleted" : "orphans found"}`);
  }
}

// ─── Job: authoritative streaks ──────────────────────────────────────

/**
 * Recomputes `currentStreak` and `lastActiveDate` from the `attempts`
 * collection.
 *
 * `attempts.timestamp` is a server timestamp, so unlike the client's own
 * calculation this cannot be moved by changing a device clock. The rules
 * constrain what a client may write; this is what makes the number
 * actually true, on whatever cadence the job runs.
 *
 * Dates are bucketed in UTC. Nigeria is UTC+1, so a session just before
 * midnight local time lands on the previous UTC day. That can shorten a
 * streak by a day at the boundary and is a known, deliberate
 * simplification — fixing it properly means storing each user's timezone.
 */
async function jobStreaks() {
  log(`\n── Recompute streaks from attempts [${mode()}]`);

  const users = await db.collection("users").get();
  let updated = 0;

  for (const userDoc of users.docs) {
    const uid = userDoc.id;

    // 180 days is far more than any plausible streak and bounds the read.
    const since = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000);
    const attempts = await db
      .collection("attempts")
      .where("userId", "==", uid)
      .where("timestamp", ">=", since)
      .orderBy("timestamp", "desc")
      .get();

    const days = new Set();
    for (const a of attempts.docs) {
      const ts = a.data().timestamp;
      if (!ts || !ts.toDate) continue;
      days.add(ts.toDate().toISOString().slice(0, 10));
    }

    const key = (d) => d.toISOString().slice(0, 10);
    const today = new Date();
    const yesterday = new Date(today.getTime() - 86400000);

    // A streak only counts if it reaches today or yesterday; otherwise it
    // is broken and the answer is zero.
    let cursor;
    if (days.has(key(today))) cursor = today;
    else if (days.has(key(yesterday))) cursor = yesterday;

    let streak = 0;
    while (cursor && days.has(key(cursor))) {
      streak++;
      cursor = new Date(cursor.getTime() - 86400000);
    }

    const current = userDoc.data().currentStreak ?? 0;
    const lastActive = userDoc.data().lastActiveDate ?? null;
    const newest = attempts.docs.length
      ? key(attempts.docs[0].data().timestamp.toDate())
      : null;

    if (current === streak && lastActive === newest) continue;

    updated++;
    if (APPLY) {
      await userDoc.ref.update({
        currentStreak: streak,
        lastActiveDate: newest,
      });
    }
  }

  log(`   ${updated} users ${APPLY ? "updated" : "would be updated"}`);
}

// ─── Job: subject.topicCount ─────────────────────────────────────────

/**
 * Recomputes `topicCount` on every subject document from the live
 * `topics` collection.
 *
 * The app needs a denominator to draw a subject-level progress ring. The
 * numerator is free — it comes from the student's own `progress/{uid}`
 * document — but "how many topics does Physics have" is not on the
 * subject document, and deriving it in the client means loading every
 * unit and every unit's topics, per subject, on the dashboard. That is
 * the read pattern `docs/audit/NEXT.md` keeps having to reclassify as
 * live breakage, so the number is precomputed here instead and read for
 * free alongside `unitCount`.
 *
 * Counted with `count()` aggregates — billed per 1000 index entries
 * rather than per document, the same reason the seeders use them. One
 * aggregate per subject, roughly ten in total, and a write only where the
 * stored value is actually wrong.
 *
 * Reclassification moves questions between topics but never moves a topic
 * between subjects, so this drifts only when topics are added or removed.
 * Running nightly is ample.
 */
async function jobTopicCounts() {
  log(`\n── Recompute subject.topicCount [${mode()}]`);

  const subjects = await db.collection("subjects").get();
  let updated = 0;

  for (const subject of subjects.docs) {
    const agg = await db
      .collection("topics")
      .where("subjectId", "==", subject.id)
      .count()
      .get();
    const actual = agg.data().count;
    const stored = subject.data().topicCount;

    if (stored === actual) continue;

    log(
      `   ${subject.data().name}: ${stored ?? "unset"} -> ${actual}`,
    );
    updated++;
    if (APPLY) {
      await subject.ref.update({ topicCount: actual });
    }
  }

  log(`   ${updated} subjects ${APPLY ? "updated" : "would be updated"}`);
}

// ─── Main ────────────────────────────────────────────────────────────

async function main() {
  log(`Paragon maintenance — job=${JOB} mode=${mode()}`);

  if (JOB === "guests" || JOB === "all") await jobGuests();
  if (JOB === "orphans" || JOB === "all") await jobOrphans();
  if (JOB === "streaks" || JOB === "all") await jobStreaks();
  if (JOB === "counts" || JOB === "all") await jobTopicCounts();

  if (!APPLY) log("\nDry run — nothing written. Re-run with --apply.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
