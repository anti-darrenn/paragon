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
 *   node jobs.js --job=challenges [--apply]
 *   node jobs.js --job=rooms    [--apply]
 *   node jobs.js --job=insights [--apply]
 *   node jobs.js --job=metrics  [--apply]
 *   node jobs.js --job=difficulty [--apply]
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

/**
 * The service account from FIREBASE_SERVICE_ACCOUNT. A parse error is
 * rethrown without its message: Node quotes part of the input in it, and
 * the Actions logs are public.
 */
function parseServiceAccount(text) {
  try {
    return JSON.parse(text);
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON.");
  }
}

function loadCredential() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return admin.credential.cert(
      parseServiceAccount(process.env.FIREBASE_SERVICE_ACCOUNT)
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
  ["feedback", "userId"],
  ["notes", "userId"],
  ["examResults", "userId"],
  ["challenges", "userId"],
  ["difficultyVotes", "userId"],
  ["decks", "userId"],
  ["quizzes", "userId"],
  ["quizAssets", "createdBy"],
  ["quizHistory", "userId"],
  ["rooms", "hostUid"],
  ["progress", null],
  ["learn", null],
  ["study", null],
  ["accountRequests", null],
  ["staffProfiles", null],
  ["waitlist", null],
  ["plan", null],
  ["avatarImages", null],
  // A takedown record goes with the account (Admin SDK only).
  ["avatarBlocks", null],
  // Public bylines are Admin-SDK-written, so the app cannot delete them;
  // scheduled deletion and the orphan sweep do.
  ["contributors", null],
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

// ─── Job: question counts, topic and subject ─────────────────────────

/**
 * Counts one topic's questions a student can be served (`hasAnswer: true`),
 * split into past questions from real papers and Paragon's generated
 * practice. Three `count()` aggregates, billed per 1000 index entries, not
 * per document — equality filters only, so no composite index is needed.
 *
 * "Past" is `source == 'waec'`; generated questions are stamped
 * `source: 'drill'`, so the two never overlap. `Question.isPastQuestion`
 * in the app reads the same fields — change both together.
 */
/**
 * What students can be served in a topic — answered **and vetted** (the
 * app's `servable()`, owner's decision 2026-10-17) — split into past
 * (source waec) and practice (source drill: generated and studio-written),
 * plus `pendingCount`, the answered questions still waiting for the
 * founder, which the question bank shows.
 */
async function countTopicQuestions(topicId) {
  const answered = db
    .collection("questions")
    .where("topicId", "==", topicId)
    .where("hasAnswer", "==", true);
  const base = answered.where("vetted", "==", true);
  const [all, total, past, practice] = await Promise.all([
    answered.count().get(),
    base.count().get(),
    base.where("source", "==", "waec").count().get(),
    base.where("source", "==", "drill").count().get(),
  ]);
  return {
    questionCount: total.data().count,
    pastQuestionCount: past.data().count,
    practiceQuestionCount: practice.data().count,
    pendingCount: all.data().count - total.data().count,
  };
}

/** Logs and (with --apply) writes only the fields whose stored value is wrong. */
async function writeIfChanged(ref, stored, actual, name) {
  const changes = Object.fromEntries(
    Object.entries(actual).filter(([field, value]) => stored[field] !== value),
  );
  if (Object.keys(changes).length === 0) return false;
  log(
    `   ${name}: ` +
      Object.entries(changes)
        .map(([field, value]) => `${field} ${stored[field] ?? "unset"} -> ${value}`)
        .join(", "),
  );
  if (APPLY) await ref.update(changes);
  return true;
}

/**
 * Recomputes the question counts on every topic, then each subject's
 * `topicCount` and question counts **as the sum of its topics'**.
 *
 * Summing, rather than counting the subject separately, is the point: the
 * welcome ticker reads the subject and the course page sums the topics,
 * and the two disagreed (14,602 vs 14,616) because topic counts were
 * written at seed time, without the `hasAnswer` filter, and never
 * recounted. Now one set of aggregates feeds both, and
 * `check_counts.js` asserts they agree.
 *
 * `topicCount` is the denominator of a subject-level progress ring; zero
 * means "not known" in the app, so it is always written here.
 *
 * Cost: three aggregates per topic (about 700 reads for ~230 topics) plus
 * one read per topic document. Nightly is ample: counts drift only when
 * content is seeded, reclassified or retired.
 */
async function jobTopicCounts() {
  log(`
── Recompute topic and subject question counts [${mode()}]`);

  const subjects = await db.collection("subjects").get();
  let topicsUpdated = 0;
  let subjectsUpdated = 0;

  for (const subject of subjects.docs) {
    const topics = await db
      .collection("topics")
      .where("subjectId", "==", subject.id)
      .get();
    const sum = { questionCount: 0, pastQuestionCount: 0, practiceQuestionCount: 0, pendingCount: 0 };
    for (const topic of topics.docs) {
      const actual = await countTopicQuestions(topic.id);
      for (const k of Object.keys(sum)) sum[k] += actual[k];
      const stored = topic.data();
      if (await writeIfChanged(topic.ref, stored, actual, `${subject.data().name} / ${stored.name}`)) {
        topicsUpdated++;
      }
    }
    const theory = await db
      .collection("theoryQuestions")
      .where("subjectId", "==", subject.id)
      .where("status", "==", "published")
      .count()
      .get();
    const actual = { topicCount: topics.size, ...sum, theoryCount: theory.data().count };
    if (await writeIfChanged(subject.ref, subject.data(), actual, subject.data().name)) {
      subjectsUpdated++;
    }
  }

  log(
    `   ${topicsUpdated} topics and ${subjectsUpdated} subjects ` +
      `${APPLY ? "updated" : "would be updated"}`,
  );
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

// ─── Job: expired challenge links ───────────────────────────────────

/**
 * Deletes "Challenge a friend" links older than 30 days. They are made to
 * be sent and played within days; kept for ever they would only be names
 * on links nobody opens. Reads only the expired ones.
 */
async function jobChallenges() {
  log(`\n── Delete challenge links older than 30 days [${mode()}]`);
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const old = await db
    .collection("challenges")
    .where("createdAt", "<", cutoff)
    .select()
    .get();
  log(`   ${old.size} ${APPLY ? "deleted" : "would be deleted"}`);
  if (APPLY && old.size) await deleteDocs(old.docs.map((d) => d.ref));
}

// ─── Job: examiner-insight flags ─────────────────────────────────────

/**
 * Stamps `questions.hasInsight` and `topics.hasExaminerThemes` from the
 * published `insights` (and clears flags whose insight is gone or was
 * unpublished), so the app reads an insight only where one exists. Reads
 * every insight (a few hundred at most) and the documents flagged now.
 */
async function jobInsights() {
  log(`\n── Examiner-insight flags [${mode()}]`);
  const insights = await db.collection("insights").where("status", "==", "published").get();
  const wantQ = new Set();
  const wantT = new Set();
  for (const d of insights.docs) {
    const i = d.data();
    if (i.kind === "topic" && i.topicId) wantT.add(i.topicId);
    else if (i.kind === "question") wantQ.add(d.id);
  }
  const haveQ = new Set(
    (await db.collection("questions").where("hasInsight", "==", true).select().get()).docs.map((d) => d.id),
  );
  const haveT = new Set(
    (await db.collection("topics").where("hasExaminerThemes", "==", true).select().get()).docs.map((d) => d.id),
  );
  const changes = [
    ...[...wantQ].filter((id) => !haveQ.has(id)).map((id) => ["questions", id, { hasInsight: true }]),
    ...[...haveQ].filter((id) => !wantQ.has(id)).map((id) => ["questions", id, { hasInsight: false }]),
    ...[...wantT].filter((id) => !haveT.has(id)).map((id) => ["topics", id, { hasExaminerThemes: true }]),
    ...[...haveT].filter((id) => !wantT.has(id)).map((id) => ["topics", id, { hasExaminerThemes: false }]),
  ];
  for (const [col, id, data] of changes) log(`   ${col}/${id} ${JSON.stringify(data)}`);
  log(`   ${changes.length} ${APPLY ? "updated" : "would be updated"}`);
  if (APPLY) {
    for (const [col, id, data] of changes) {
      await db.collection(col).doc(id).update(data).catch((e) => log(`   ! ${col}/${id}: ${e.message}`));
    }
  }
}

// ─── Job: daily traction metrics ─────────────────────────────────────

/** Lagos is UTC+1 all year. The day before [now], as [startUtc, endUtc). */
function lagosYesterday(now = new Date()) {
  const lagos = new Date(now.getTime() + 60 * 60 * 1000);
  const todayLagos = Date.UTC(lagos.getUTCFullYear(), lagos.getUTCMonth(), lagos.getUTCDate());
  const end = new Date(todayLagos - 60 * 60 * 1000);
  const start = new Date(end.getTime() - 24 * 60 * 60 * 1000);
  const id = new Date(todayLagos - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  return { id, start, end };
}

/**
 * Writes yesterday's numbers (Lagos day) to `metrics/{YYYY-MM-DD}`:
 * aggregates only, never a uid or a name. Read by admins in the studio's
 * Traction panel, "copy for pitch deck". About ten count() aggregates —
 * billed per 1000 index entries, so a few reads a day.
 */
async function jobMetrics() {
  const { id, start, end } = lagosYesterday();
  log(`\n── Traction metrics for ${id} [${mode()}]`);
  const between = (col, field, extra = (q) => q) =>
    extra(db.collection(col).where(field, ">=", start).where(field, "<", end)).count().get()
      .then((s) => s.data().count)
      .catch((e) => {
        log(`   ! ${col}.${field}: ${e.message}`);
        return null;
      });
  const metrics = {
    questionsAnswered: await between("attempts", "timestamp"),
    drillLearners: await between("progress", "updatedAt"),
    newAccounts: await between("users", "createdAt", (q) => q.where("isAnonymous", "==", false)),
    newGuests: await between("users", "createdAt", (q) => q.where("isAnonymous", "==", true)),
    examsSat: await between("examResults", "submittedAt"),
    challengesMade: await between("challenges", "createdAt"),
    roomsHosted: await between("rooms", "createdAt"),
    feedback: await between("feedback", "createdAt"),
  };
  log(`   ${JSON.stringify(metrics)}`);
  if (APPLY) {
    await db.collection("metrics").doc(id).set({
      ...metrics,
      day: id,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// ─── One-shot: retired profile fields ────────────────────────────────

/**
 * Deletes `profile.age`, `profile.gender`, `profile.country` and
 * `profile.state` from every user (the owner's decision of 2026-10-15:
 * data about minors with no reader). School and class stay. Not in
 * `all`: run once by hand, dry first. Reads every user document once.
 */
async function jobDropProfile() {
  log(`\n── Retired profile fields [${mode()}]`);
  const RETIRED = ["age", "gender", "country", "state"];
  const users = await db.collection("users").select("profile").get();
  const hit = users.docs.filter((d) => {
    const p = d.data().profile;
    return p && RETIRED.some((f) => p[f] !== undefined);
  });
  log(`   ${hit.length} of ${users.size} users hold a retired field`);
  if (!APPLY) return;
  const del = admin.firestore.FieldValue.delete();
  for (let i = 0; i < hit.length; i += 400) {
    const batch = db.batch();
    for (const d of hit.slice(i, i + 400)) {
      batch.update(d.ref, Object.fromEntries(RETIRED.map((f) => [`profile.${f}`, del])));
    }
    await batch.commit();
  }
  log(`   ${hit.length} cleaned`);
}

// ─── Job: expired quiz rooms ─────────────────────────────────────────

/**
 * Deletes live quiz rooms more than a day old, with their players and
 * answers (recursiveDelete). The rules stop anyone joining after a day;
 * this is the tidy-up, and what keeps nicknames from lingering.
 */
async function jobRooms() {
  log(`\n── Delete quiz rooms older than a day [${mode()}]`);
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const old = await db.collection("rooms").where("createdAt", "<", cutoff).select().get();
  log(`   ${old.size} ${APPLY ? "deleted" : "would be deleted"}`);
  if (APPLY) {
    for (const d of old.docs) await db.recursiveDelete(d.ref);
  }
}

// ─── Job: students' difficulty ratings ───────────────────────────────

/**
 * Adds the "how hard was this?" ratings sent since the last run into each
 * question's `crowdDifficulty {n, sum}`, then deletes the vote documents.
 * Oldest first, and capped so one night touches at most 3,000 questions
 * (one write each); the rest wait for the next run. The app blends the
 * tally with Paragon's estimate (`blendTier`), so the estimate stays the
 * baseline. A rating for a question that no longer exists is dropped.
 */
async function jobDifficulty() {
  log(`\n── Students' difficulty ratings [${mode()}]`);
  const { tally, takeWithin } = require("./difficulty_votes");
  const snap = await db.collection("difficultyVotes").orderBy("createdAt").limit(1000).get();
  const docs = takeWithin(
    snap.docs.map((d) => ({ ref: d.ref, ...d.data() })),
    3000,
  );
  const totals = tally(docs);
  log(`   ${docs.length} session(s), ${totals.size} question(s) rated`);
  if (!APPLY || !docs.length) return;
  const inc = admin.firestore.FieldValue.increment;
  const entries = [...totals];
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    const chunk = entries.slice(i, i + 400);
    const refs = chunk.map(([qid]) => db.collection("questions").doc(qid));
    const exists = await db.getAll(...refs, { fieldMask: ["topicId"] });
    chunk.forEach(([, t], k) => {
      if (!exists[k].exists) return;
      batch.update(refs[k], {
        "crowdDifficulty.n": inc(t.n),
        "crowdDifficulty.sum": inc(t.sum),
      });
    });
    await batch.commit();
  }
  await deleteDocs(docs.map((d) => d.ref));
}

// ─── Main ────────────────────────────────────────────────────────────

async function main() {
  log(`Paragon maintenance — job=${JOB} mode=${mode()}`);

  if (JOB === "guests" || JOB === "all") await jobGuests();
  if (JOB === "deletions" || JOB === "all") await jobDeletions();
  if (JOB === "orphans" || JOB === "all") await jobOrphans();
  if (JOB === "counts" || JOB === "all") await jobTopicCounts();
  if (JOB === "counts" || JOB === "all") await jobLessonCounts();
  if (JOB === "challenges" || JOB === "all") await jobChallenges();
  if (JOB === "rooms" || JOB === "all") await jobRooms();
  if (JOB === "insights" || JOB === "all") await jobInsights();
  if (JOB === "metrics" || JOB === "all") await jobMetrics();
  if (JOB === "difficulty" || JOB === "all") await jobDifficulty();
  // Not in `all` — see jobDropStreakFields. One-shot, run by hand.
  if (JOB === "dropstreak") await jobDropStreakFields();
  if (JOB === "resourcestatus") await jobResourceStatus();
  if (JOB === "dropprofile") await jobDropProfile();

  if (!APPLY) log("\nDry run — nothing written. Re-run with --apply.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
