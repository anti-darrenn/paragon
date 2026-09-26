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
 *   node jobs.js --job=guests   [--days=30] [--max-deletes=2000] [--apply]
 *   node jobs.js --job=deletions [--apply]
 *   node jobs.js --job=orphans  [--apply]
 *   node jobs.js --job=counts   [--apply]
 *   node jobs.js --job=all      [--apply]
 *
 * And one that is deliberately NOT in `all`, to be run once by hand:
 *
 *   node jobs.js --job=dropstreak [--apply]
 *   node jobs.js --job=resourcestatus [--apply]
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

// ─── What a student owns ─────────────────────────────────────────────

/**
 * Every document a uid owns. **Keep in step with
 * `AccountRepository.deleteOwnedDocuments`** (and its export twin) — a
 * collection missing here is data left behind when an account is removed
 * by a job rather than by the student. A null field means the document id
 * is itself the uid.
 */
const OWNED = [
  ["attempts", "userId"],
  ["flags", "userId"],
  ["notes", "userId"],
  ["progress", null],
  ["learn", null],
  ["study", null],
  ["accountRequests", null],
  ["users", null],
];

/** Deletes everything [uid] owns, then the Auth user. Returns doc count. */
async function deleteAccountCompletely(uid) {
  const refs = [];
  for (const [collection, field] of OWNED) {
    if (field) {
      const snap = await db
        .collection(collection)
        .where(field, "==", uid)
        .select()
        .get();
      refs.push(...snap.docs.map((d) => d.ref));
    } else {
      refs.push(db.collection(collection).doc(uid));
    }
  }
  const n = await deleteDocs(refs);
  if (APPLY) await auth.deleteUser(uid).catch(() => {});
  return n;
}

// ─── Job: stale guest accounts ───────────────────────────────────────

/**
 * Deletes anonymous accounts nobody has used for [DAYS], with everything
 * they own.
 *
 * Every tap of "Browse as Guest" creates a permanent Auth user and a
 * Firestore document; without this they accumulate for the life of the
 * project.
 *
 * **Inactivity, not age.** This used to delete only guests that had never
 * answered a question, and keep any that had "because a guest who has
 * practised has something worth keeping". Nobody could ever reach that
 * work again, though — a guest who signs out or clears the browser gets a
 * new uid — so it was kept for no one, forever. Guests can now link their
 * session to an account (`/account/upgrade`), which keeps the uid; one
 * that has not been used for [DAYS] has not been upgraded and will not
 * be. `lastRefreshTime` is the last time the session was used at all,
 * falling back to sign-in and then creation for accounts that predate it.
 *
 * Deletions cost writes against the shared Spark quota, so a run stops
 * after [MAX_DELETES] documents and finishes the rest the next night.
 */
const MAX_DELETES = Number(
  (args.find((a) => a.startsWith("--max-deletes=")) || "").split("=")[1] ||
    2000
);

function lastUsedMs(user) {
  for (const t of [
    user.metadata.lastRefreshTime,
    user.metadata.lastSignInTime,
    user.metadata.creationTime,
  ]) {
    const ms = Date.parse(t || "");
    if (Number.isFinite(ms)) return ms;
  }
  return NaN;
}

async function jobGuests() {
  log(`
── Guest accounts idle for ${DAYS}+ days [${mode()}]`);

  const cutoff = Date.now() - DAYS * 24 * 60 * 60 * 1000;
  let pageToken;
  let examined = 0;
  let accounts = 0;
  let docs = 0;

  do {
    const page = await auth.listUsers(1000, pageToken);
    pageToken = page.pageToken;

    for (const user of page.users) {
      // Anonymous means no linked provider at all. A guest who upgraded
      // has one, and is never touched here.
      if (user.providerData.length !== 0) continue;
      examined++;

      const used = lastUsedMs(user);
      if (!Number.isFinite(used) || used > cutoff) continue;

      if (docs >= MAX_DELETES) {
        log(`   stopping at ${MAX_DELETES} documents; the rest tomorrow`);
        pageToken = undefined;
        break;
      }
      docs += await deleteAccountCompletely(user.uid);
      accounts++;
    }
  } while (pageToken);

  log(
    `   ${examined} guests examined, ${accounts} idle ` +
      `${APPLY ? "deleted" : "would be deleted"} (${docs} documents)`
  );
}

// ─── Job: scheduled account deletions ────────────────────────────────

/**
 * Finishes deletions students scheduled from Settings, once the grace
 * period has passed.
 *
 * "Delete my account" stamps `users/{uid}.deletionRequestedAt` with the
 * server time and signs the student out; signing back in within the
 * period offers to restore it. **GRACE_DAYS must match
 * `kDeletionGracePeriod` in account_repository.dart and the privacy
 * policy.** Deletes everything in OWNED and the Auth user; the username
 * reservations stay, as they do for every deletion.
 */
const GRACE_DAYS = 30;

async function jobDeletions() {
  log(`
── Scheduled deletions older than ${GRACE_DAYS} days [${mode()}]`);

  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - GRACE_DAYS * 24 * 60 * 60 * 1000
  );
  const due = await db
    .collection("users")
    .where("deletionRequestedAt", "<=", cutoff)
    .select()
    .get();

  let docs = 0;
  for (const user of due.docs) {
    docs += await deleteAccountCompletely(user.id);
  }
  log(
    `   ${due.size} account(s) ${APPLY ? "deleted" : "would be deleted"} ` +
      `(${docs} documents)`
  );
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

  // The same list the account deleters use, so a collection added there
  // is reaped here too. (This one reads whole collections — cheap while
  // there are few users, and worth replacing before there are many.)
  for (const [collection, field] of OWNED) {
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

// ─── Job: backfill resource status (one-shot) ────────────────────────

/**
 * Stamps `status: 'published'` on every Learn resource that has no
 * `status`.
 *
 * The student query is `where('status', '==', 'published')`, equality
 * filters never match a missing field, and the rules hide any resource
 * without `status: 'published'`. A status-less resource is therefore
 * invisible to students. Ran once on 2026-09-24 (6 resources); kept for
 * any restore from an old backup.
 *
 * One-shot and not in `all`, like dropstreak: the seeder now writes the
 * field and the editor always does, so nothing produces a status-less
 * resource again.
 *
 *   node jobs.js --job=resourcestatus            # dry run
 *   node jobs.js --job=resourcestatus --apply
 */
async function jobResourceStatus() {
  log(`\n── Backfill status on Learn resources [${mode()}]`);

  const all = await db.collectionGroup("resources").get();
  const missing = all.docs.filter((d) => d.data().status === undefined);

  log(`   ${missing.length} of ${all.size} resources have no status`);

  if (APPLY) {
    for (let i = 0; i < missing.length; i += 400) {
      const batch = db.batch();
      for (const doc of missing.slice(i, i + 400)) {
        batch.update(doc.ref, { status: "published" });
      }
      await batch.commit();
    }
  }

  log(`   ${missing.length} ${APPLY ? "stamped" : "would be stamped"} published`);
}

// ─── Job: subject.topicCount and questionCount ───────────────────────

/**
 * Recomputes `topicCount` and `questionCount` on every subject document
 * from the live `topics` and `questions` collections.
 *
 * `questionCount` counts only `hasAnswer: true` — what a student can be
 * served — and is shown on the welcome screen. It drifts whenever an
 * admin retires a reported question or new content is seeded.
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
 * rather than per document, the same reason the seeders use them. Two
 * aggregates per subject, roughly twenty in total, and a write only where
 * a stored value is actually wrong.
 *
 * Reclassification moves questions between topics but never moves a topic
 * between subjects, so this drifts only when topics are added or removed.
 * Running nightly is ample.
 */
async function jobTopicCounts() {
  log(`
── Recompute subject.topicCount and questionCount [${mode()}]`);

  const subjects = await db.collection("subjects").get();
  let updated = 0;

  for (const subject of subjects.docs) {
    const topics = await db
      .collection("topics")
      .where("subjectId", "==", subject.id)
      .count()
      .get();
    // Only questions a student can actually be served: drill, WAEC and
    // tests all filter on hasAnswer. One aggregate per subject, billed
    // per 1000 index entries, not per document.
    const questions = await db
      .collection("questions")
      .where("subjectId", "==", subject.id)
      .where("hasAnswer", "==", true)
      .count()
      .get();
    const actual = {
      topicCount: topics.data().count,
      questionCount: questions.data().count,
    };
    const stored = subject.data();

    const changes = Object.fromEntries(
      Object.entries(actual).filter(([field, value]) => stored[field] !== value),
    );
    if (Object.keys(changes).length === 0) continue;

    log(
      `   ${stored.name}: ` +
        Object.entries(changes)
          .map(([field, value]) => `${field} ${stored[field] ?? "unset"} -> ${value}`)
          .join(", "),
    );
    updated++;
    if (APPLY) {
      await subject.ref.update(changes);
    }
  }

  log(`   ${updated} subjects ${APPLY ? "updated" : "would be updated"}`);
}

// ─── Job: topic.lessonCount ──────────────────────────────────────────

/**
 * Mirrors `LearnResource.isAvailable` in lib/core/models/learn_resource.dart:
 * a video needs a YouTube id, an article a body; an exercise always opens.
 * Change both together.
 */
function isAvailableResource(r) {
  if (r.type === "video") return String(r.youtubeId || "").trim() !== "";
  if (r.type === "article") return String(r.body || "").trim() !== "";
  return r.type === "exercise";
}

/**
 * Recomputes `lessonCount` on every topic — published, openable Learn
 * items — the denominator of "2 of 6 lessons" on the course index.
 *
 * The editor keeps it current as it publishes; this is the backstop for a
 * missed update and for anything the seeder or the console changed. Reads
 * only published resources (collection-group, one query) and only the
 * topics that have lessons or claim to — not all 216.
 */
async function jobLessonCounts() {
  log(`\n── Recompute topic.lessonCount [${mode()}]`);

  const published = await db
    .collectionGroup("resources")
    .where("status", "==", "published")
    .get();
  const actual = new Map();
  for (const doc of published.docs) {
    const topicId = doc.ref.parent.parent.id;
    if (!actual.has(topicId)) actual.set(topicId, 0);
    if (isAvailableResource(doc.data())) {
      actual.set(topicId, actual.get(topicId) + 1);
    }
  }

  const claiming = await db.collection("topics").where("lessonCount", ">", 0).get();
  const ids = new Set([...actual.keys(), ...claiming.docs.map((d) => d.id)]);

  let updated = 0;
  for (const id of ids) {
    const ref = db.collection("topics").doc(id);
    const snap = await ref.get();
    if (!snap.exists) continue;
    const stored = snap.data().lessonCount ?? 0;
    const count = actual.get(id) ?? 0;
    if (stored === count) continue;
    log(`   ${snap.data().name}: ${stored} -> ${count}`);
    updated++;
    if (APPLY) await ref.update({ lessonCount: count });
  }
  log(`   ${updated} topics ${APPLY ? "updated" : "would be updated"}`);
}

// ─── Main ────────────────────────────────────────────────────────────

async function main() {
  log(`Paragon maintenance — job=${JOB} mode=${mode()}`);

  if (JOB === "guests" || JOB === "all") await jobGuests();
  if (JOB === "deletions" || JOB === "all") await jobDeletions();
  if (JOB === "orphans" || JOB === "all") await jobOrphans();
  if (JOB === "counts" || JOB === "all") await jobTopicCounts();
  if (JOB === "counts" || JOB === "all") await jobLessonCounts();
  // Not in `all` — see jobDropStreakFields. One-shot, run by hand.
  if (JOB === "dropstreak") await jobDropStreakFields();
  if (JOB === "resourcestatus") await jobResourceStatus();

  if (!APPLY) log("\nDry run — nothing written. Re-run with --apply.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
