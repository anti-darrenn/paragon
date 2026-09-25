/**
 * Exercises the live Firestore security rules as a real client sees them.
 *
 *   node verify_rules.js
 *
 * ── Why this exists ──────────────────────────────────────────────────
 *
 * `firestore.rules` had never been tested dynamically. The usual answer
 * is the Firestore emulator, which needs Java, which this machine does
 * not have — so the rules shipped on a `--dry-run` compile and careful
 * reading, and `docs/audit/NEXT.md` carried that as a stated verification
 * gap on the `users/{uid}` lockdown in particular.
 *
 * This closes it without Java. It signs in anonymously through the
 * Identity Toolkit REST API and reads and writes through the Firestore
 * REST API, so every request is evaluated by the real deployed rules. It
 * uses **no Admin SDK for any assertion**: the Admin SDK bypasses rules
 * entirely, so a test written with it would pass no matter how wrong the
 * rules were. Admin is used only for setup and cleanup: seeding a draft
 * for the draft-wall checks to run against (no client can create one —
 * that is the point), then removing it and the one other thing a client
 * deliberately cannot delete, a username reservation.
 *
 * ── Why the failures matter more than the successes ──────────────────
 *
 * A write that succeeds tells you only that something allowed it. The
 * rules are doing their job only if the writes that ought to be refused
 * actually are, so the `DENY` cases are the content here. Delete them and
 * this file stops meaning anything.
 *
 * The single most important one is the `users/{uid}` allow-list: a future
 * `totalXP`, `level` or `topicStats` must be server-only from the moment
 * it exists, without anyone remembering to lock it first. That is the
 * guarantee a leaderboard will eventually rest on.
 *
 * ── What it costs ────────────────────────────────────────────────────
 *
 * Runs against production. It creates two throwaway anonymous accounts
 * and their documents, then removes them. Reads and writes are a few
 * dozen — negligible against the Spark daily quota, but not zero.
 *
 * The API key is the public web key already shipped in
 * `firebase_options.dart` and in the deployed web bundle; it identifies
 * the project and grants nothing on its own.
 */

const API_KEY = 'AIzaSyDgPksUP3MZ9gX-baZSyXiMIg07wWwjGOA';
const PROJECT = 'paragon-hq';
// The commit endpoint wants a bare resource path; the REST URLs want it
// prefixed. Conflating the two is what the first version of this got wrong.
const RESOURCE = `projects/${PROJECT}/databases/(default)/documents`;
const DOCS = `https://firestore.googleapis.com/v1/${RESOURCE}`;

const ALLOW = 'allow';
const DENY = 'deny';

// ─── Harness ──────────────────────────────────────────────────────────

let passed = 0;
const failures = [];
let currentSuite = '';

function record(label, ok, detail) {
  if (ok) {
    passed++;
    console.log(`    ok    ${label}`);
  } else {
    failures.push(`${currentSuite} — ${label}${detail ? ` (${detail})` : ''}`);
    console.log(`    FAIL  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

function suite(name) {
  currentSuite = name;
  console.log(`\n  ${name}`);
}

/**
 * Asserts an HTTP result against an intent.
 *
 * Anything other than 200 or 403 is reported as its own failure rather
 * than quietly counting as a denial — a 400 from a malformed request
 * would otherwise look exactly like a rule doing its job, which is how
 * the first run of this file produced two meaningless passes.
 */
function expectOutcome(label, intent, result) {
  const { status } = result;
  if (intent === ALLOW) {
    record(label, status === 200, `HTTP ${status} ${brief(result)}`);
    return;
  }
  if (status === 403) {
    record(label, true);
  } else if (status === 200) {
    record(label, false, 'the write was ACCEPTED but should have been refused');
  } else {
    record(label, false, `HTTP ${status} — not a rules denial: ${brief(result)}`);
  }
}

function brief(result) {
  const message = result.body?.error?.message;
  return message ? String(message).slice(0, 120) : '';
}

// ─── REST ─────────────────────────────────────────────────────────────

async function signInAnonymously() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`anon sign-in failed: ${JSON.stringify(body)}`);
  return { idToken: body.idToken, uid: body.localId };
}

async function deleteAccount(idToken) {
  await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );
}

async function commit(idToken, write) {
  const res = await fetch(`${DOCS}:commit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ writes: [write] }),
  });
  return { status: res.status, body: await res.json() };
}

async function readDoc(idToken, path) {
  const res = await fetch(`${DOCS}/${path}`, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  return { status: res.status, body: await res.json() };
}

/**
 * Runs a structured query under `parentPath` ('' for the database root,
 * which is where collection-group queries run).
 */
async function runQuery(idToken, parentPath, structuredQuery) {
  const url = parentPath ? `${DOCS}/${parentPath}:runQuery` : `${DOCS}:runQuery`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ structuredQuery }),
  });
  const body = await res.json();
  // runQuery answers with an array; surface its error for brief().
  return {
    status: res.status,
    body: Array.isArray(body) ? body.find((r) => r.error) || {} : body,
    rows: Array.isArray(body) ? body.filter((r) => r.document) : [],
  };
}

// ─── Admin SDK — setup and teardown only, never an assertion ─────────

let adminSdk;
function getAdmin() {
  if (!adminSdk) adminSdk = require('./credential').initAdmin();
  return adminSdk;
}

const verifyResources = () =>
  getAdmin().firestore().collection('topics').doc('zz_verify_topic').collection('resources');

/** Seeds one draft and one published article. False without credentials. */
async function seedResources() {
  try {
    const now = getAdmin().firestore.Timestamp.now();
    const base = { type: 'article', topicId: 'zz_verify_topic', subjectId: 'zz', body: 'x' };
    await verifyResources().doc('zz_verify_draft').set({
      ...base, title: 'draft', order: 1, status: 'draft',
      // Pre-stamped so the draft notifier never emails about it.
      notifiedAt: now,
    });
    await verifyResources().doc('zz_verify_published').set({
      ...base, title: 'published', order: 0, status: 'published',
    });
    // The parent topic document, for the lessonCount update checks. No
    // unitId, so no course page ever lists it.
    await verifyResources().parent.set({ name: 'zz verify', lessonCount: 0 });
    return true;
  } catch (e) {
    console.log(`    (could not seed resources: ${e.message.slice(0, 80)})`);
    return false;
  }
}

const statusIs = (value) => ({
  fieldFilter: {
    field: { fieldPath: 'status' },
    op: 'EQUAL',
    value: { stringValue: value },
  },
});

async function deleteDoc(idToken, path) {
  const res = await fetch(`${DOCS}/${path}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${idToken}` },
  });
  return { status: res.status, body: await res.json() };
}

// ─── Value helpers ────────────────────────────────────────────────────

const str = (v) => ({ stringValue: v });
const int = (v) => ({ integerValue: String(v) });
const bool = (v) => ({ booleanValue: v });
const map = (fields) => ({ mapValue: { fields } });
const arr = (values) => ({ arrayValue: { values } });

/** A write that sets exactly `fields`, leaving everything else alone. */
function write(path, fields, { transforms = [], precondition } = {}) {
  const w = {
    update: { name: `${RESOURCE}/${path}`, fields },
    updateMask: { fieldPaths: Object.keys(fields) },
  };
  if (transforms.length) w.updateTransforms = transforms;
  if (precondition) w.currentDocument = precondition;
  return w;
}

const serverTime = (fieldPath) => ({
  fieldPath,
  setToServerValue: 'REQUEST_TIME',
});

function randomKey() {
  return `zz_v${Math.random().toString(36).slice(2, 10)}`.slice(0, 20);
}

/** The exact document `UserRepository.createUserIfNew` sends. */
function provisioningFields(uid) {
  return {
    uid: str(uid),
    email: str(''),
    displayName: str(''),
    isAnonymous: bool(true),
  };
}

// ─── Suites ───────────────────────────────────────────────────────────

async function usersCreate(a, b) {
  suite('users/{uid} — provisioning');

  const created = await commit(
    a.idToken,
    write(`users/${a.uid}`, provisioningFields(a.uid), {
      transforms: [serverTime('createdAt')],
      precondition: { exists: false },
    }),
  );
  expectOutcome('the exact provisioning document is accepted', ALLOW, created);

  // Every negative below targets one clause of the create rule.
  expectOutcome(
    'a create carrying an extra field is refused',
    DENY,
    await commit(
      b.idToken,
      write(
        `users/${b.uid}`,
        { ...provisioningFields(b.uid), level: int(99) },
        { transforms: [serverTime('createdAt')], precondition: { exists: false } },
      ),
    ),
  );

  // createdAt must be the real serverTimestamp sentinel, not a value the
  // client chose — otherwise account age is whatever a client says.
  expectOutcome(
    'a client-supplied createdAt is refused',
    DENY,
    await commit(
      b.idToken,
      write(
        `users/${b.uid}`,
        {
          ...provisioningFields(b.uid),
          createdAt: { timestampValue: '2020-01-01T00:00:00Z' },
        },
        { precondition: { exists: false } },
      ),
    ),
  );

  expectOutcome(
    "a create on another student's uid is refused",
    DENY,
    await commit(
      b.idToken,
      write(`users/${a.uid}`, provisioningFields(a.uid), {
        transforms: [serverTime('createdAt')],
      }),
    ),
  );

  // b needs a real document for the later suites.
  await commit(
    b.idToken,
    write(`users/${b.uid}`, provisioningFields(b.uid), {
      transforms: [serverTime('createdAt')],
      precondition: { exists: false },
    }),
  );
}

async function usersAllowList(a, b) {
  suite('users/{uid} — the client-writable allow-list');

  expectOutcome(
    'displayName is writable',
    ALLOW,
    await commit(a.idToken, write(`users/${a.uid}`, { displayName: str('Ada') })),
  );

  expectOutcome(
    'selectedSubjects is writable',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        selectedSubjects: arr([str('mathematics'), str('physics')]),
      }),
    ),
  );

  expectOutcome(
    'profile is writable',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        profile: map({ school: str('Kings College'), age: int(16) }),
      }),
    ),
  );

  // The reason the allow-list is an allow-list. These fields do not exist
  // on any document yet; the point is that they are server-only from the
  // moment they do, with nothing to remember to lock down first.
  for (const [field, value] of [
    ['totalXP', int(100000)],
    ['level', int(99)],
    ['topicStats', map({ t1: int(1) })],
    ['isAdmin', bool(true)],
  ]) {
    expectOutcome(
      `${field} is not client-writable`,
      DENY,
      await commit(a.idToken, write(`users/${a.uid}`, { [field]: value })),
    );
  }

  expectOutcome(
    'own document is readable',
    ALLOW,
    await readDoc(a.idToken, `users/${a.uid}`),
  );

  expectOutcome(
    "another student's document is not readable",
    DENY,
    await readDoc(b.idToken, `users/${a.uid}`),
  );

  expectOutcome(
    "another student's document is not writable",
    DENY,
    await commit(
      b.idToken,
      write(`users/${a.uid}`, { displayName: str('hijacked') }),
    ),
  );
}

async function usernames(a, b, key) {
  suite('usernames/{key} — uniqueness and permanence');

  // Claiming before reserving is the hole the two-phase write exists to
  // close: the rule reads committed data, so the reservation must already
  // be there.
  expectOutcome(
    'a username with no reservation behind it is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        username: str(key),
        usernameKey: str(key),
      }),
    ),
  );

  expectOutcome(
    'a reservation can be created',
    ALLOW,
    await commit(
      a.idToken,
      write(`usernames/${key}`, { uid: str(a.uid), raw: str(key) }),
    ),
  );

  expectOutcome(
    'a reservation whose id is not the lower-cased spelling is refused',
    DENY,
    await commit(
      a.idToken,
      write(`usernames/${key}_x`, { uid: str(a.uid), raw: str('SOMETHINGELSE') }),
    ),
  );

  expectOutcome(
    'the matching claim is now accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        username: str(key),
        usernameKey: str(key),
      }),
    ),
  );

  expectOutcome(
    'a username is immutable once set',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        username: str('somethingelse'),
        usernameKey: str('somethingelse'),
      }),
    ),
  );

  expectOutcome(
    "another student cannot overwrite the reservation",
    DENY,
    await commit(
      b.idToken,
      write(`usernames/${key}`, { uid: str(b.uid), raw: str(key) }),
    ),
  );

  expectOutcome(
    "another student cannot claim the reserved handle",
    DENY,
    await commit(
      b.idToken,
      write(`users/${b.uid}`, {
        username: str(key),
        usernameKey: str(key),
      }),
    ),
  );

  expectOutcome(
    'a reservation cannot be released',
    DENY,
    await deleteDoc(a.idToken, `usernames/${key}`),
  );
}

async function attemptsAndFlags(a, b) {
  suite('attempts and flags — own data only');

  const attempt = (uid) => ({
    userId: str(uid),
    questionId: str('q-verify'),
    topicId: str('t-verify'),
    subjectId: str('s-verify'),
    selectedIndex: int(1),
    isCorrect: bool(true),
    source: str('drill'),
  });

  const attemptId = `verify_${a.uid.slice(0, 8)}`;
  expectOutcome(
    'an attempt can be recorded for yourself',
    ALLOW,
    await commit(a.idToken, write(`attempts/${attemptId}`, attempt(a.uid))),
  );

  expectOutcome(
    "an attempt cannot be recorded against another student",
    DENY,
    await commit(
      b.idToken,
      write(`attempts/${attemptId}_b`, attempt(a.uid)),
    ),
  );

  // An attempt is a record of what happened and must not be editable
  // after the fact — otherwise a wrong answer can be rewritten as right.
  expectOutcome(
    'an attempt cannot be edited after the fact',
    DENY,
    await commit(
      a.idToken,
      write(`attempts/${attemptId}`, { isCorrect: bool(false) }),
    ),
  );

  expectOutcome(
    "another student's attempt is not readable",
    DENY,
    await readDoc(b.idToken, `attempts/${attemptId}`),
  );

  const flagId = `verify_${a.uid.slice(0, 8)}`;
  expectOutcome(
    'a problem report can be filed',
    ALLOW,
    await commit(
      a.idToken,
      write(`flags/${flagId}`, {
        userId: str(a.uid),
        questionId: str('q-verify'),
        reason: str('wrong_answer'),
      }),
    ),
  );

  expectOutcome(
    'a problem report cannot be edited',
    DENY,
    await commit(a.idToken, write(`flags/${flagId}`, { reason: str('other') })),
  );

  // Review is admin-only. A student closing their own report would hide
  // it from the queue; closing it at birth would do the same.
  expectOutcome(
    'a student cannot close their own problem report',
    DENY,
    await commit(a.idToken, write(`flags/${flagId}`, { status: str('dismissed') })),
  );

  const closedFlagId = `${flagId}_closed`;
  expectOutcome(
    'a problem report cannot be filed already closed',
    DENY,
    await commit(
      a.idToken,
      write(`flags/${closedFlagId}`, {
        userId: str(a.uid),
        questionId: str('q-verify'),
        reason: str('wrong_answer'),
        status: str('dismissed'),
      }),
    ),
  );

  expectOutcome(
    "a student cannot list everyone's problem reports",
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'flags' }] }),
  );

  expectOutcome(
    "another student's problem report is not readable",
    DENY,
    await readDoc(b.idToken, `flags/${flagId}`),
  );

  // Cleanup of what this suite created — both are delete-own by rule.
  await deleteDoc(a.idToken, `attempts/${attemptId}`);
  await deleteDoc(a.idToken, `flags/${flagId}`);
  await deleteDoc(a.idToken, `flags/${closedFlagId}`);
}

async function progress(a, b) {
  suite('progress/{uid} — the mastery cache');

  const fields = (uid) => ({
    userId: str(uid),
    topics: map({
      topicVerify: map({
        answered: int(5),
        correct: int(4),
        subjectId: str('subjectVerify'),
      }),
    }),
  });

  expectOutcome(
    'a drill session write is accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(`progress/${a.uid}`, fields(a.uid), {
        transforms: [serverTime('updatedAt')],
      }),
    ),
  );

  expectOutcome(
    'a write carrying an unlisted field is refused',
    DENY,
    await commit(
      a.idToken,
      write(
        `progress/${a.uid}`,
        { ...fields(a.uid), totalXP: int(9999) },
        { transforms: [serverTime('updatedAt')] },
      ),
    ),
  );

  expectOutcome(
    'a client-supplied updatedAt is refused',
    DENY,
    await commit(
      a.idToken,
      write(`progress/${a.uid}`, {
        ...fields(a.uid),
        updatedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );

  expectOutcome(
    "another student's progress is not writable",
    DENY,
    await commit(
      b.idToken,
      write(`progress/${a.uid}`, fields(a.uid), {
        transforms: [serverTime('updatedAt')],
      }),
    ),
  );

  expectOutcome(
    "another student's progress is not readable",
    DENY,
    await readDoc(b.idToken, `progress/${a.uid}`),
  );

  const own = await readDoc(a.idToken, `progress/${a.uid}`);
  expectOutcome('own progress reads back', ALLOW, own);
  record(
    'updatedAt was written as a real server timestamp',
    Boolean(own.body?.fields?.updatedAt?.timestampValue),
    JSON.stringify(own.body?.fields?.updatedAt),
  );
  record(
    'the session counters round-trip',
    own.body?.fields?.topics?.mapValue?.fields?.topicVerify?.mapValue?.fields
      ?.answered?.integerValue === '5',
  );
}

async function learnGate(a, b) {
  suite('learn/{uid} — topic test results');

  const path = `learn/${a.uid}`;
  const fields = (uid) => ({
    userId: str(uid),
    topics: map({
      topicVerify: map({
        passed: bool(true),
        bestScore: int(90),
        attempts: int(1),
        subjectId: str('subjVerify'),
      }),
    }),
  });

  expectOutcome(
    'a topic-test result can be written for yourself',
    ALLOW,
    await commit(
      a.idToken,
      write(path, fields(a.uid), { transforms: [serverTime('updatedAt')] }),
    ),
  );

  // The closed field set. `learn` carries the drill gate, so it is exactly
  // the document someone would try to smuggle an unlock flag onto.
  expectOutcome(
    'a write carrying an unlisted field is refused',
    DENY,
    await commit(
      a.idToken,
      write(
        path,
        { ...fields(a.uid), unlockedEverything: bool(true) },
        { transforms: [serverTime('updatedAt')] },
      ),
    ),
  );

  expectOutcome(
    'a client-supplied updatedAt is refused',
    DENY,
    await commit(a.idToken, write(path, {
      ...fields(a.uid),
      updatedAt: { timestampValue: '2020-01-01T00:00:00Z' },
    })),
  );

  expectOutcome(
    "another student's topic-test results are not writable",
    DENY,
    await commit(
      a.idToken,
      write(`learn/${b.uid}`, fields(b.uid), {
        transforms: [serverTime('updatedAt')],
      }),
    ),
  );

  expectOutcome(
    "another student's topic-test results are not readable",
    DENY,
    await readDoc(b.idToken, path),
  );

  // Lesson completion shares this document, nested under the topic, so it
  // must pass the same closed top-level field set. This is the exact shape
  // `LearnProgressRepository.markComplete` sends.
  const completion = (uid) => ({
    userId: str(uid),
    topics: map({
      topicLesson: map({
        subjectId: str('subjVerify'),
        completed: map({ resVerify: bool(true) }),
        lastCompletedId: str('resVerify'),
      }),
    }),
  });
  const completionTimes = [
    serverTime('updatedAt'),
    serverTime('topics.topicLesson.lastCompletedAt'),
  ];

  expectOutcome(
    'a lesson completion can be written for yourself',
    ALLOW,
    await commit(
      a.idToken,
      write(path, completion(a.uid), { transforms: completionTimes }),
    ),
  );

  expectOutcome(
    "another student's lesson completion is not writable",
    DENY,
    await commit(
      a.idToken,
      write(`learn/${b.uid}`, completion(b.uid), {
        transforms: completionTimes,
      }),
    ),
  );

  // The completion write above replaced `topics` wholesale (an update
  // mask on a map field does), so put the test result back before reading.
  await commit(
    a.idToken,
    write(path, fields(a.uid), { transforms: [serverTime('updatedAt')] }),
  );

  const own = await readDoc(a.idToken, path);
  expectOutcome('own topic-test results read back', ALLOW, own);
  record(
    'the pass flag round-trips',
    own.body?.fields?.topics?.mapValue?.fields?.topicVerify?.mapValue?.fields
      ?.passed?.booleanValue === true,
  );
}

async function content(a) {
  suite('content — readable, never writable by a student');

  expectOutcome(
    'a signed-in student can read subjects',
    ALLOW,
    await readDoc(a.idToken, 'subjects'),
  );

  // ── The draft wall ──
  // Run against a topic that REALLY holds a draft and a published article.
  // An earlier version checked an empty collection, passed, and missed a
  // live leak: an unfiltered list returned drafts to any student. Seeding
  // is setup only; every assertion below is still made as a client.
  const seeded = await seedResources();
  if (!seeded) {
    record(
      'draft-wall checks need a real draft to test against',
      false,
      'no admin credentials to seed one — these checks did not run',
    );
  } else {
    // Resources live in a SUBcollection and rules do not cascade. This is
    // the exact query `topicResourcesProvider` runs, so it also proves the
    // status + order index exists — a missing one comes back as a 400.
    const published = await runQuery(a.idToken, 'topics/zz_verify_topic', {
      from: [{ collectionId: 'resources' }],
      where: statusIs('published'),
      orderBy: [{ field: { fieldPath: 'order' }, direction: 'ASCENDING' }],
    });
    expectOutcome(
      "a signed-in student can run the app's published-resources query",
      ALLOW,
      published,
    );
    const ids = (published.rows || []).map((r) => r.document.name.split('/').pop());
    record(
      'that query returns the published article and not the draft',
      ids.includes('zz_verify_published') && !ids.includes('zz_verify_draft'),
      `returned ${JSON.stringify(ids)}`,
    );

    // Rules are not filters: an unfiltered list could return a draft, so
    // it must be refused whole. If this passes, drafts are public.
    expectOutcome(
      'an unfiltered list of resources is refused (it contains a draft)',
      DENY,
      await readDoc(a.idToken, 'topics/zz_verify_topic/resources'),
    );

    expectOutcome(
      'a student cannot read a draft directly by id',
      DENY,
      await readDoc(a.idToken, 'topics/zz_verify_topic/resources/zz_verify_draft'),
    );
  }

  expectOutcome(
    'a student cannot query for drafts',
    DENY,
    await runQuery(a.idToken, 'topics/zz_verify_topic', {
      from: [{ collectionId: 'resources' }],
      where: statusIs('draft'),
    }),
  );

  expectOutcome(
    'a student cannot run the admin drafts query across all topics',
    DENY,
    await runQuery(a.idToken, '', {
      from: [{ collectionId: 'resources', allDescendants: true }],
      where: statusIs('draft'),
    }),
  );

  // Only DENY cases for writes: an anonymous token cannot carry the
  // `admin` claim, so the admin ALLOW path is exercised by hand in the
  // editor, not here.
  expectOutcome(
    'learn resources cannot be written by a non-admin client',
    DENY,
    await commit(
      a.idToken,
      write('topics/zz_verify_topic/resources/zz_injected', {
        type: str('article'),
        title: str('injected'),
      }),
    ),
  );

  // `lessonCount` is the one topic field a client may update, and only an
  // admin. An update to a document that does not exist would be refused
  // for the wrong reason, so these run against a real (seeded) topic.
  if (seeded) {
    expectOutcome(
      "a student cannot set a topic's lessonCount",
      DENY,
      await commit(
        a.idToken,
        write('topics/zz_verify_topic', { lessonCount: int(99) }),
      ),
    );
    expectOutcome(
      'a student cannot change any other topic field',
      DENY,
      await commit(
        a.idToken,
        write('topics/zz_verify_topic', { name: str('renamed') }),
      ),
    );
  }

  // Questions take one admin-only update (resolving a report). Against a
  // real question: an update to a missing document is refused as a
  // create, which would pass for the wrong reason.
  const oneQuestion = await runQuery(a.idToken, '', {
    from: [{ collectionId: 'questions' }],
    limit: 1,
  });
  const questionPath = (oneQuestion.rows || [])[0]?.document?.name
    ?.split('/documents/')[1];
  if (!questionPath) {
    record('question write checks need a real question', false, 'none returned');
  } else {
    expectOutcome(
      "a student cannot change a question's marked answer",
      DENY,
      await commit(a.idToken, write(questionPath, { correctIndex: int(0) })),
    );
    expectOutcome(
      'a student cannot retire a question',
      DENY,
      await commit(a.idToken, write(questionPath, { hasAnswer: bool(false) })),
    );
  }

  for (const collection of ['subjects', 'units', 'topics', 'questions']) {
    expectOutcome(
      `${collection} cannot be written by a client`,
      DENY,
      await commit(
        a.idToken,
        write(`${collection}/zz_verify_write`, { name: str('injected') }),
      ),
    );
  }
}

// ─── Teardown ─────────────────────────────────────────────────────────

/**
 * Removes what the run created.
 *
 * Everything a client is allowed to delete is deleted as that client.
 * The username reservation is the exception — `allow update, delete: if
 * false` makes it permanent by design, which is the correct behaviour and
 * exactly why a test cannot clean up after itself. Admin is used for that
 * one document and nothing else; if credentials are absent the key is
 * printed so it can be removed by hand.
 */
async function teardown(a, b, usernameKey) {
  console.log('\n  cleanup');

  for (const user of [a, b]) {
    await deleteDoc(user.idToken, `progress/${user.uid}`);
    await deleteDoc(user.idToken, `learn/${user.uid}`);
    await deleteDoc(user.idToken, `users/${user.uid}`);
    await deleteAccount(user.idToken);
  }
  console.log('    throwaway accounts and their documents removed');

  try {
    for (const id of ['zz_verify_draft', 'zz_verify_published']) {
      await verifyResources().doc(id).delete();
    }
    await verifyResources().parent.delete();
    console.log('    seeded verify resources removed (admin)');
  } catch (e) {
    console.log(
      `    NOTE: could not remove topics/zz_verify_topic/resources/* ` +
        `(${e.message.slice(0, 60)}). Delete them by hand.`,
    );
  }

  try {
    await getAdmin().firestore().collection('usernames').doc(usernameKey).delete();
    console.log(`    reservation ${usernameKey} removed (admin)`);
  } catch (e) {
    console.log(
      `    NOTE: reservation "${usernameKey}" could not be removed ` +
        `(${e.message.slice(0, 60)}). Delete it by hand — reservations are ` +
        'permanent to clients by design.',
    );
  }
}

// ─── Main ─────────────────────────────────────────────────────────────

(async () => {
  console.log(`Verifying firestore.rules on ${PROJECT}, as a real client`);

  const a = await signInAnonymously();
  const b = await signInAnonymously();
  const usernameKey = randomKey();
  console.log(`  two throwaway anonymous users; test handle "${usernameKey}"`);

  await usersCreate(a, b);
  await usersAllowList(a, b);
  await usernames(a, b, usernameKey);
  await attemptsAndFlags(a, b);
  await progress(a, b);
  await learnGate(a, b);
  await content(a);

  await teardown(a, b, usernameKey);

  console.log(`\n${passed} passed, ${failures.length} failed`);
  if (failures.length) {
    console.log('\nFailures:');
    for (const f of failures) console.log(`  - ${f}`);
  }
  process.exit(failures.length === 0 ? 0 : 1);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
