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
 * documents, recounting a subject's topics — is plain `firebase-admin`
 * code. The Admin SDK bypasses security rules and
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
 * derived values that is fine: `attempts` carries a server timestamp and
 * is the source of truth, so recomputing on a schedule is correct, just
 * eventually.
 *
 * ── Usage ────────────────────────────────────────────────────────────
 *
 *   node jobs.js --job=guests   [--days=30] [--apply]
 *   node jobs.js --job=orphans  [--apply]
 *   node jobs.js --job=counts   [--apply]
 *   node jobs.js --job=all      [--apply]
 *
 * And one that is deliberately NOT in `all`, to be run once by hand:
 *
 *   node jobs.js --job=dropstreak [--apply]
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

// ─── Job: drop the retired streak fields (one-shot) ──────────────────

/**
 * Deletes `currentStreak` and `lastActiveDate` from every `users/{uid}`
 * document.
 *
 * Streaks were removed from the product. The fields stayed behind on
 * every existing account because nothing migrates them — read by no
 * code, written by no code, and indistinguishable from live data to
 * anyone reading the collection later. That is the quiet kind of wrong
 * worth spending one job on.
 *
 * **One-shot, and deliberately not part of `--job=all`.** There is
 * nothing to re-run: once the fields are gone, no client writes them
 * back. Leaving it on the nightly schedule would mean scanning every
 * user document forever to find nothing, on a plan where reads are the
 * scarce resource. Run it by hand, once, after the streak-free build is
 * deployed:
 *
 *   node jobs.js --job=dropstreak            # dry run, counts only
 *   node jobs.js --job=dropstreak --apply
 *
 * Batched at 400 (the hard limit is 500) and only users actually
 * carrying a field are touched, so the write cost is one per affected
 * account and zero thereafter.
 */
async function jobDropStreakFields() {
  log(`\n── Drop retired streak fields from users [${mode()}]`);

  const users = await db.collection("users").get();
  const stale = users.docs.filter(
    (d) =>
      d.data().currentStreak !== undefined ||
      d.data().lastActiveDate !== undefined,
  );

  log(`   ${stale.length} of ${users.size} user documents still carry them`);

  if (!APPLY || stale.length === 0) {
    log(`   ${stale.length} ${APPLY ? "cleared" : "would be cleared"}`);
    return;
  }

  const FieldValue = admin.firestore.FieldValue;
  let cleared = 0;
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    for (const doc of stale.slice(i, i + 400)) {
      batch.update(doc.ref, {
        currentStreak: FieldValue.delete(),
        lastActiveDate: FieldValue.delete(),
      });
    }
    await batch.commit();
    cleared += Math.min(400, stale.length - i);
  }

  log(`   ${cleared} cleared`);
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
  if (JOB === "counts" || JOB === "all") await jobTopicCounts();
  // Not in `all` — see jobDropStreakFields. One-shot, run by hand.
  if (JOB === "dropstreak") await jobDropStreakFields();

  if (!APPLY) log("\nDry run — nothing written. Re-run with --apply.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
