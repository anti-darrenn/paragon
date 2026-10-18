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

/**
 * A throwaway email/password account, for the rules that refuse guests
 * (username reservations). The address is on example.com, which never
 * receives mail; the account is deleted in teardown.
 */
async function signUpWithPassword() {
  const email = `zz-verify-${Math.random().toString(36).slice(2, 10)}@example.com`;
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: `${Math.random().toString(36)}Aa1!${Date.now()}`,
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`password sign-up failed: ${JSON.stringify(body)}`);
  return { idToken: body.idToken, uid: body.localId, email };
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
    await verifyResources().parent.set({ name: 'zz verify', subjectId: 'zz', lessonCount: 0 });
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
        profile: map({ school: str('Kings College'), classYear: str('SS2') }),
      }),
    ),
  );
  // School and class only: a retired field cannot come back, and the two
  // that remain are shape-checked.
  for (const [why, profile] of [
    ['an age', map({ school: str('Kings College'), age: int(16) })],
    ['a gender', map({ gender: str('female') })],
    ['an unknown class', map({ classYear: str('SS4') })],
    ['a 101-character school', map({ school: str('s'.repeat(101)) })],
    ['a school that is not a string', map({ school: int(1) })],
  ]) {
    expectOutcome(
      `a profile with ${why} is refused`,
      DENY,
      await commit(a.idToken, write(`users/${a.uid}`, { profile })),
    );
  }

  // Avatar and bio: allow-listed, and shape-checked by
  // clientFieldsAreValid(). The denials are the content.
  expectOutcome(
    'a preset avatar is writable',
    ALLOW,
    await commit(a.idToken, write(`users/${a.uid}`, { avatar: str('preset:owl') })),
  );
  expectOutcome(
    'an initials avatar is writable',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, { avatar: str('initials:teal') }),
    ),
  );
  for (const [why, value] of [
    ['a URL', str('https://example.com/me.png')],
    ['an unknown kind', str('photo:owl')],
    ['upper case', str('preset:OWL')],
    ['a number', int(3)],
  ]) {
    expectOutcome(
      `an avatar that is ${why} is refused`,
      DENY,
      await commit(a.idToken, write(`users/${a.uid}`, { avatar: value })),
    );
  }
  expectOutcome(
    'a 160-character bio is writable',
    ALLOW,
    await commit(a.idToken, write(`users/${a.uid}`, { bio: str('b'.repeat(160)) })),
  );
  expectOutcome(
    'a 161-character bio is refused',
    DENY,
    await commit(a.idToken, write(`users/${a.uid}`, { bio: str('b'.repeat(161)) })),
  );
  expectOutcome(
    'a bio that is not a string is refused',
    DENY,
    await commit(a.idToken, write(`users/${a.uid}`, { bio: int(1) })),
  );

  // A scheduled deletion: server time or nothing.
  expectOutcome(
    'scheduling deletion with the server time is accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {}, {
        transforms: [serverTime('deletionRequestedAt')],
      }),
    ),
  );
  expectOutcome(
    'a client-chosen deletion date is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        deletionRequestedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    'a scheduled deletion can be cancelled',
    ALLOW,
    await commit(a.idToken, {
      update: { name: `${RESOURCE}/users/${a.uid}`, fields: {} },
      updateMask: { fieldPaths: ['deletionRequestedAt'] },
    }),
  );

  // Accepting the terms: version and server time, together.
  expectOutcome(
    'accepting the terms with the server time is accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, { legalVersion: str('2026-09-26') }, {
        transforms: [serverTime('legalAcceptedAt')],
      }),
    ),
  );
  expectOutcome(
    'a terms version without the acceptance time is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, { legalVersion: str('2099-01-01') }),
    ),
  );
  expectOutcome(
    'a backdated acceptance is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        legalVersion: str('2026-09-26'),
        legalAcceptedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );

  // Synced settings: a closed, typed set.
  expectOutcome(
    'valid synced settings are accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        prefs: map({
          textScaleStep: int(2),
          lineSpacing: str('relaxed'),
          font: str('hyperlegible'),
          lowDataMode: bool(true),
          analytics: bool(false),
          theme: str('system'),
        }),
      }),
    ),
  );
  for (const [why, prefs] of [
    ['an unknown key', map({ isAdmin: bool(true) })],
    ['an out-of-range text size', map({ textScaleStep: int(9) })],
    ['an unknown font', map({ font: str('comic') })],
    ['a non-bool analytics choice', map({ analytics: str('no') })],
    ['an unknown theme', map({ theme: str('neon') })],
  ]) {
    expectOutcome(
      `settings with ${why} are refused`,
      DENY,
      await commit(a.idToken, write(`users/${a.uid}`, { prefs })),
    );
  }

  // The reason the allow-list is an allow-list. These fields do not exist
  // on any document yet; the point is that they are server-only from the
  // moment they do, with nothing to remember to lock down first.
  for (const [field, value] of [
    ['totalXP', int(100000)],
    ['level', int(99)],
    ['topicStats', map({ t1: int(1) })],
    ['isAdmin', bool(true)],
    // Retired with streaks. Named in the allow-list for a while so old
    // tabs were not refused; the shim is gone, so they are refused now.
    ['currentStreak', int(5)],
    ['lastActiveDate', str('2026-09-01')],
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

  // The email copy is the token's own or blank; a guest's token has none.
  expectOutcome(
    "someone else's email cannot be planted on an account",
    DENY,
    await commit(a.idToken, write(`users/${a.uid}`, { email: str('victim@example.com') })),
  );
  expectOutcome(
    'a display name over 256 characters is refused',
    DENY,
    await commit(a.idToken, write(`users/${a.uid}`, { displayName: str('n'.repeat(257)) })),
  );
}

/** Provisions a password account's user document, as createUserIfNew does. */
async function provision(user) {
  await commit(
    user.idToken,
    write(`users/${user.uid}`, { ...provisioningFields(user.uid), email: str(user.email), isAnonymous: bool(false) }, {
      transforms: [serverTime('createdAt')],
      precondition: { exists: false },
    }),
  );
}

async function usernames(a, b, key, guest) {
  suite('usernames/{key} — uniqueness and permanence');

  // Reservations are permanent, so a guest sign-up must not be a free way
  // to squat them, and nobody may take a name that passes as Paragon.
  expectOutcome(
    'a guest cannot reserve a name',
    DENY,
    await commit(
      guest.idToken,
      write(`usernames/${key}_g`, { uid: str(guest.uid), raw: str(`${key}_g`) }),
    ),
  );
  expectOutcome(
    'a name containing "paragon" is reserved',
    DENY,
    await commit(
      a.idToken,
      write('usernames/zz_paragon_team', { uid: str(a.uid), raw: str('zz_paragon_team') }),
    ),
  );

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
    'a username cannot change to a handle with no reservation',
    DENY,
    await commit(
      a.idToken,
      write(
        `users/${a.uid}`,
        {
          username: str('somethingelse'),
          usernameKey: str('somethingelse'),
        },
        { transforms: [serverTime('usernameChangedAt')] },
      ),
    ),
  );

  // Changing: to a second reservation a owns, once, with the server's
  // clock — and not again for 90 days.
  const second = `${key}_2`;
  const theirs = `${key}_3`;
  await commit(
    a.idToken,
    write(`usernames/${second}`, { uid: str(a.uid), raw: str(second) }),
  );
  await commit(
    b.idToken,
    write(`usernames/${theirs}`, { uid: str(b.uid), raw: str(theirs) }),
  );

  expectOutcome(
    'a change without usernameChangedAt is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        username: str(second),
        usernameKey: str(second),
      }),
    ),
  );
  expectOutcome(
    'a change with a client-chosen usernameChangedAt is refused',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        username: str(second),
        usernameKey: str(second),
        usernameChangedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    "a change to someone else's reservation is refused",
    DENY,
    await commit(
      a.idToken,
      write(
        `users/${a.uid}`,
        { username: str(theirs), usernameKey: str(theirs) },
        { transforms: [serverTime('usernameChangedAt')] },
      ),
    ),
  );
  expectOutcome(
    'a change to your own second reservation is accepted',
    ALLOW,
    await commit(
      a.idToken,
      write(
        `users/${a.uid}`,
        { username: str(second), usernameKey: str(second) },
        { transforms: [serverTime('usernameChangedAt')] },
      ),
    ),
  );
  expectOutcome(
    'a second change inside 90 days is refused',
    DENY,
    await commit(
      a.idToken,
      write(
        `users/${a.uid}`,
        { username: str(key), usernameKey: str(key) },
        { transforms: [serverTime('usernameChangedAt')] },
      ),
    ),
  );
  expectOutcome(
    'usernameChangedAt cannot be backdated on its own',
    DENY,
    await commit(
      a.idToken,
      write(`users/${a.uid}`, {
        usernameChangedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    'a handle given up cannot be released',
    DENY,
    await deleteDoc(a.idToken, `usernames/${key}`),
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
  const stamped = { transforms: [serverTime('timestamp')] };

  const attemptId = `verify_${a.uid.slice(0, 8)}`;
  expectOutcome(
    'an attempt can be recorded for yourself',
    ALLOW,
    await commit(a.idToken, write(`attempts/${attemptId}`, attempt(a.uid), stamped)),
  );

  expectOutcome(
    "an attempt cannot be recorded against another student",
    DENY,
    await commit(
      b.idToken,
      write(`attempts/${attemptId}_b`, attempt(a.uid), stamped),
    ),
  );

  // Exactly AttemptRepository's shape, with the server's clock.
  for (const [why, fields, opts] of [
    ['an extra field', { ...attempt(a.uid), xp: int(50) }, stamped],
    ['an unknown source', { ...attempt(a.uid), source: str('ranked') }, stamped],
    ['a client-chosen time', { ...attempt(a.uid), timestamp: { timestampValue: '2020-01-01T00:00:00Z' } }, {}],
    ['no time at all', attempt(a.uid), {}],
  ]) {
    expectOutcome(
      `an attempt with ${why} is refused`,
      DENY,
      await commit(a.idToken, write(`attempts/${attemptId}_x`, fields, opts)),
    );
  }

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
  const flagStamp = { transforms: [serverTime('createdAt')] };
  expectOutcome(
    'a problem report can be filed',
    ALLOW,
    await commit(
      a.idToken,
      write(`flags/${flagId}`, {
        userId: str(a.uid),
        questionId: str('q-verify'),
        reason: str('wrong_answer'),
      }, flagStamp),
    ),
  );

  // notify_drafts.js pages through reports by createdAt: one dated in the
  // future would move its cursor past every real report to come.
  expectOutcome(
    'a problem report dated in the future is refused',
    DENY,
    await commit(
      a.idToken,
      write(`flags/${flagId}_future`, {
        userId: str(a.uid),
        questionId: str('q-verify'),
        reason: str('wrong_answer'),
        createdAt: { timestampValue: '9999-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    'a problem report with an extra field is refused',
    DENY,
    await commit(
      a.idToken,
      write(`flags/${flagId}_extra`, {
        userId: str(a.uid),
        questionId: str('q-verify'),
        reason: str('wrong_answer'),
        note: str('x'.repeat(5000)),
      }, flagStamp),
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
      }, flagStamp),
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

async function feedbackAndUsage(a, b) {
  suite('feedback and usage');

  const fb = (uid, extra = {}) => ({
    userId: str(uid),
    kind: str('idea'),
    message: str('Please add Biology'),
    screen: str('/settings'),
    ...extra,
  });
  const at = { transforms: [serverTime('createdAt')] };
  const id = `verify_${a.uid.slice(0, 8)}`;

  // "How hard was this?" ratings (2026-10-17): one document per session.
  const rating = (uid, n = 1) => ({
    userId: str(uid),
    votes: map(
      Object.fromEntries(
        Array.from({ length: n }, (_, i) => [`zz_verify_q${i}`, int(3)]),
      ),
    ),
  });
  expectOutcome(
    'a session of difficulty ratings can be sent, by a guest too',
    ALLOW,
    await commit(a.idToken, write(`difficultyVotes/${id}`, rating(a.uid), at)),
  );
  expectOutcome(
    'difficulty ratings cannot be sent as another student',
    DENY,
    await commit(b.idToken, write(`difficultyVotes/${id}_b`, rating(a.uid), at)),
  );
  expectOutcome(
    'a session cannot send more than 30 ratings',
    DENY,
    await commit(
      a.idToken,
      write(`difficultyVotes/${id}_many`, rating(a.uid, 31), at),
    ),
  );
  expectOutcome(
    "nobody reads another student's ratings",
    DENY,
    await readDoc(b.idToken, `difficultyVotes/${id}`),
  );
  expectOutcome(
    'the owner can delete their ratings',
    ALLOW,
    await commit(a.idToken, { delete: `${RESOURCE}/difficultyVotes/${id}` }),
  );

  expectOutcome(
    'feedback can be sent, by a guest too',
    ALLOW,
    await commit(a.idToken, write(`feedback/${id}`, fb(a.uid), at)),
  );
  expectOutcome(
    'feedback cannot be sent as another student',
    DENY,
    await commit(b.idToken, write(`feedback/${id}_b`, fb(a.uid), at)),
  );
  expectOutcome(
    'feedback cannot carry a client clock',
    DENY,
    await commit(
      a.idToken,
      write(`feedback/${id}_clock`, {
        ...fb(a.uid),
        createdAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    'feedback cannot be filed already triaged',
    DENY,
    await commit(
      a.idToken,
      write(`feedback/${id}_status`, fb(a.uid, { status: str('done') }), at),
    ),
  );
  expectOutcome(
    'feedback over 2000 characters is refused',
    DENY,
    await commit(
      a.idToken,
      write(
        `feedback/${id}_long`,
        fb(a.uid, { message: str('x'.repeat(2001)) }),
        at,
      ),
    ),
  );
  expectOutcome(
    'feedback with an unknown kind is refused',
    DENY,
    await commit(
      a.idToken,
      write(`feedback/${id}_kind`, fb(a.uid, { kind: str('spam') }), at),
    ),
  );
  expectOutcome(
    'a student cannot mark their own feedback done',
    DENY,
    await commit(a.idToken, write(`feedback/${id}`, { status: str('done') })),
  );
  expectOutcome(
    "another student's feedback is not readable",
    DENY,
    await readDoc(b.idToken, `feedback/${id}`),
  );
  expectOutcome(
    "a student cannot list everyone's feedback",
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'feedback' }] }),
  );
  expectOutcome(
    'your own feedback is readable (account deletion finds it)',
    ALLOW,
    await readDoc(a.idToken, `feedback/${id}`),
  );

  // _meta is Admin-SDK-only except usage, which reviewers read.
  expectOutcome(
    'a student cannot read Firestore usage',
    DENY,
    await readDoc(a.idToken, '_meta/usage'),
  );
  expectOutcome(
    'a student cannot read the content audit',
    DENY,
    await readDoc(a.idToken, '_meta/contentAudit'),
  );
  expectOutcome(
    'a student cannot write the content audit',
    DENY,
    await commit(a.idToken, write('_meta/contentAudit', { total: int(1) })),
  );
  expectOutcome(
    'a student cannot read the notify cursor',
    DENY,
    await readDoc(a.idToken, '_meta/notify'),
  );
  expectOutcome(
    'a student cannot write Firestore usage',
    DENY,
    await commit(a.idToken, write('_meta/usage', { days: map({}) })),
  );

  await deleteDoc(a.idToken, `feedback/${id}`);
}

async function examResults(a, b) {
  suite('examResults — own, closed shape, never edited');

  // exactly what ExamResultRepository.save sends
  const exam = (uid, extra = {}) => ({
    userId: str(uid),
    subjectId: str('s-verify'),
    items: arr([
      map({ q: str('q1'), t: str('t1'), s: int(0) }),
      map({ q: str('q2'), t: str('t1'), s: int(-1) }),
    ]),
    total: int(2),
    correct: int(1),
    timed: bool(true),
    durationSeconds: int(300),
    ...extra,
  });
  const at = { transforms: [serverTime('submittedAt')] };
  const id = `verify_${a.uid.slice(0, 8)}`;

  expectOutcome(
    'an exam result can be saved for yourself',
    ALLOW,
    await commit(a.idToken, write(`examResults/${id}`, exam(a.uid), at)),
  );
  expectOutcome(
    'an exam result cannot be saved against another student',
    DENY,
    await commit(b.idToken, write(`examResults/${id}_b`, exam(a.uid), at)),
  );
  expectOutcome(
    'an exam result cannot be edited — a score is not rewritable',
    DENY,
    await commit(a.idToken, write(`examResults/${id}`, { correct: int(2) })),
  );
  expectOutcome(
    'an exam result cannot carry an unlisted field',
    DENY,
    await commit(
      a.idToken,
      write(`examResults/${id}_x`, exam(a.uid, { grade: str('A1') }), at),
    ),
  );
  expectOutcome(
    'an exam result cannot claim more right than it has questions',
    DENY,
    await commit(
      a.idToken,
      write(`examResults/${id}_y`, exam(a.uid, { correct: int(3) }), at),
    ),
  );
  expectOutcome(
    'an exam result cannot set its own time',
    DENY,
    await commit(
      a.idToken,
      write(`examResults/${id}_z`, {
        ...exam(a.uid),
        submittedAt: { timestampValue: '2020-01-01T00:00:00Z' },
      }),
    ),
  );
  expectOutcome(
    "another student's exam result is not readable",
    DENY,
    await readDoc(b.idToken, `examResults/${id}`),
  );
  expectOutcome(
    'your own exam result is readable',
    ALLOW,
    await readDoc(a.idToken, `examResults/${id}`),
  );

  await deleteDoc(a.idToken, `examResults/${id}`);
}

async function studyData(a, b) {
  suite('notes and study/{uid} — own data, real accounts only');

  // The test accounts are anonymous, i.e. guests. Guests keep notes on the
  // device, so every write here is refused; the signed-in allow path is
  // exercised by hand.
  const note = {
    userId: str(a.uid),
    topicId: str('t'),
    resourceId: str('r'),
    subjectId: str('s'),
    blockKey: str('paragraph:00000000:0'),
    colour: str('yellow'),
    text: str('note'),
    snapshot: str('text'),
  };
  expectOutcome(
    'a guest cannot store a note in Firestore',
    DENY,
    await commit(
      a.idToken,
      write('notes/zz_verify_note', note, {
        transforms: [serverTime('createdAt'), serverTime('updatedAt')],
      }),
    ),
  );
  expectOutcome(
    "another student's study document is not readable",
    DENY,
    await readDoc(b.idToken, `study/${a.uid}`),
  );
  expectOutcome(
    "another student's study document is not writable",
    DENY,
    await commit(
      b.idToken,
      write(`study/${a.uid}`, { userId: str(a.uid), bookmarks: map({}) }, {
        transforms: [serverTime('updatedAt')],
      }),
    ),
  );
  expectOutcome(
    "a student cannot list everyone's notes",
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'notes' }] }),
  );
}

async function accountRequests(a, b) {
  suite('accountRequests/{uid} — sign out everywhere');

  // As with study data, the test accounts are guests, and a guest has no
  // sessions worth revoking: the anonymous clause refuses them. The
  // real-account allow path is exercised by hand.
  expectOutcome(
    'a guest cannot file a sign-out request',
    DENY,
    await commit(
      a.idToken,
      write(`accountRequests/${a.uid}`, { type: str('revokeSessions') }, {
        transforms: [serverTime('requestedAt')],
      }),
    ),
  );
  expectOutcome(
    "a request on another student's uid is refused",
    DENY,
    await commit(
      b.idToken,
      write(`accountRequests/${a.uid}`, { type: str('revokeSessions') }, {
        transforms: [serverTime('requestedAt')],
      }),
    ),
  );
  expectOutcome(
    "another student's request is not readable",
    DENY,
    await readDoc(b.idToken, `accountRequests/${a.uid}`),
  );
  expectOutcome(
    'account requests cannot be listed',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'accountRequests' }] }),
  );
}

async function waitlist(a, b) {
  suite('waitlist/{uid} — "Notify me", accounts only');

  // The test accounts are guests, and the anonymous clause refuses every
  // guest write — a guest has no address to be told at. The real-account
  // allow path is exercised by hand.
  const list = { userId: str(a.uid), subjects: arr([str('biology')]) };
  expectOutcome(
    'a guest cannot join a waitlist',
    DENY,
    await commit(
      a.idToken,
      write(`waitlist/${a.uid}`, list, { transforms: [serverTime('updatedAt')] }),
    ),
  );
  expectOutcome(
    "a waitlist on another student's uid is refused",
    DENY,
    await commit(
      b.idToken,
      write(`waitlist/${a.uid}`, list, { transforms: [serverTime('updatedAt')] }),
    ),
  );
  expectOutcome(
    "another student's waitlist is not readable",
    DENY,
    await readDoc(b.idToken, `waitlist/${a.uid}`),
  );
  expectOutcome(
    'a student cannot list or count the waitlist',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'waitlist' }] }),
  );
}

async function challenges(a, b) {
  suite('challenges/{id} — create once, get by id, list your own');
  const c = (uid, score = 5) => ({
    userId: str(uid),
    name: str('Ada'),
    subjectId: str('s1'),
    topicId: str('t1'),
    topicName: str('Indices'),
    questionIds: arr([str('q1'), str('q2')]),
    score: { integerValue: String(score) },
    total: { integerValue: '2' },
  });
  const id = `verify-${Date.now()}`;
  expectOutcome(
    "a challenge in someone else's name is refused",
    DENY,
    await commit(a.idToken, write(`challenges/${id}-x`, c(b.uid), { transforms: [serverTime('createdAt')] })),
  );
  expectOutcome(
    'a score above the total is refused',
    DENY,
    await commit(a.idToken, write(`challenges/${id}-y`, c(a.uid, 3), { transforms: [serverTime('createdAt')] })),
  );
  expectOutcome(
    'challenges cannot be listed wholesale',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'challenges' }] }),
  );
}

async function rooms(a, b) {
  suite('rooms/{code} — accounts host, guests join');
  // The test accounts are guests: hosting is refused them. The full
  // game is exercised on the emulator (tools/rules-test).
  const room = {
    hostUid: str(a.uid),
    subjectId: str('s1'),
    topicId: str('t1'),
    topicName: str('Indices'),
    questionIds: arr([str('q1')]),
    state: str('lobby'),
    index: { integerValue: '0' },
    results: { mapValue: { fields: {} } },
  };
  expectOutcome(
    'a guest cannot host a room',
    DENY,
    await commit(a.idToken, write('rooms/VRFY23', room, { transforms: [serverTime('createdAt')] })),
  );
  expectOutcome(
    'rooms cannot be listed',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'rooms' }] }),
  );
}

async function plan(a, b) {
  suite('plan/{uid} — weekly goal and exam date, accounts only');

  // Guests again: the anonymous clause refuses them; the account path is
  // exercised by hand and on the emulator (tools/rules-test).
  const p = (uid) => ({ userId: str(uid), weeklyGoal: { integerValue: '100' } });
  expectOutcome(
    'a guest cannot save a plan',
    DENY,
    await commit(a.idToken, write(`plan/${a.uid}`, p(a.uid), { transforms: [serverTime('updatedAt')] })),
  );
  expectOutcome(
    "a plan on another student's uid is refused",
    DENY,
    await commit(b.idToken, write(`plan/${a.uid}`, p(a.uid), { transforms: [serverTime('updatedAt')] })),
  );
  expectOutcome(
    "another student's plan is not readable",
    DENY,
    await readDoc(b.idToken, `plan/${a.uid}`),
  );
}

async function staffProfiles(a, b) {
  suite('staffProfiles/{uid} — the team only');

  const profile = { displayName: str('Ada'), avatar: str('preset:owl') };
  expectOutcome(
    'a student cannot publish a staff profile',
    DENY,
    await commit(
      a.idToken,
      write(`staffProfiles/${a.uid}`, profile, {
        transforms: [serverTime('updatedAt')],
      }),
    ),
  );
  expectOutcome(
    "a student cannot read another's staff profile",
    DENY,
    await readDoc(b.idToken, `staffProfiles/${a.uid}`),
  );
  // Allowed, and there is nothing there: 404 is the answer, not 403.
  const own = await readDoc(a.idToken, `staffProfiles/${a.uid}`);
  record(
    'a student can look for their own (for export and deletion)',
    own.status === 200 || own.status === 404,
    `HTTP ${own.status} ${brief(own)}`,
  );
  expectOutcome(
    'staff profiles cannot be listed by a student',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'staffProfiles' }] }),
  );
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
    // The studio's edit path (2026-10-17) is reviewer-only, and needs a
    // history record in the same batch; a student gets neither.
    expectOutcome(
      "a student cannot edit a question's text",
      DENY,
      await commit(a.idToken, write(questionPath, { text: str('rewritten'), lastEditId: str('zz_verify') })),
    );
    expectOutcome(
      'a student cannot mark a content-audit finding checked',
      DENY,
      await commit(a.idToken, write(questionPath, { auditDismissed: arr([str('raw-latex-question')]) })),
    );
    expectOutcome(
      "a student cannot write a question's edit history",
      DENY,
      await commit(
        a.idToken,
        write(`${questionPath}/history/zz_verify`, { by: str(a.uid), reason: str('x') }),
      ),
    );
  }

  // ── The review workflow (docs/CONTENT_ROLES.md) ──
  // Students hold no content role, so every one of these is refused. The
  // staff allow-paths need a writer/reviewer token, which a test cannot
  // mint; they are exercised by hand in the studio.
  expectOutcome(
    'a student cannot create a lesson item, even as a draft',
    DENY,
    await commit(
      a.idToken,
      write('topics/zz_verify_topic/resources/zz_student_draft', {
        type: str('article'),
        title: str('sneaky'),
        status: str('draft'),
      }),
    ),
  );
  if (seeded) {
    expectOutcome(
      "a student cannot read a draft's version history",
      DENY,
      await readDoc(a.idToken, 'topics/zz_verify_topic/resources/zz_verify_draft/versions'),
    );
    expectOutcome(
      "a student cannot read a draft's review comments",
      DENY,
      await readDoc(a.idToken, 'topics/zz_verify_topic/resources/zz_verify_draft/comments'),
    );
    expectOutcome(
      'a student cannot comment on a draft',
      DENY,
      await commit(
        a.idToken,
        write('topics/zz_verify_topic/resources/zz_verify_draft/comments/zz_c', {
          authorUid: str(a.uid),
          text: str('hi'),
        }),
      ),
    );
    expectOutcome(
      'a student cannot publish a draft',
      DENY,
      await commit(
        a.idToken,
        write('topics/zz_verify_topic/resources/zz_verify_draft', {
          status: str('published'),
        }),
      ),
    );
  }
  expectOutcome(
    'a student cannot upload a lesson image',
    DENY,
    await commit(
      a.idToken,
      write('lessonAssets/zz_verify_asset', {
        mime: str('image/png'),
        data: str('AAAA'),
        createdBy: str(a.uid),
      }),
    ),
  );
  expectOutcome(
    "a student cannot write a subject's glossary index",
    DENY,
    await commit(
      a.idToken,
      write('subjectIndex/zz_verify_subject', { topics: map({}) }),
    ),
  );

  // The Team page's requests turn into roles. A student who could write
  // one could make themselves a reviewer.
  expectOutcome(
    'a student cannot request a content-team role',
    DENY,
    await commit(
      a.idToken,
      write(`staffInvites/zz_verify_${a.uid.slice(0, 6)}@example.com`, {
        email: str('x@example.com'),
        role: str('reviewer'),
        subjects: arr([]),
        status: str('pending'),
      }),
    ),
  );
  expectOutcome(
    'a student cannot list the content team',
    DENY,
    await runQuery(a.idToken, '', { from: [{ collectionId: 'staffInvites' }] }),
  );

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
async function teardown(users, usernameKey) {
  console.log('\n  cleanup');

  for (const user of users) {
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
    const reservations = getAdmin().firestore().collection('usernames');
    for (const k of [usernameKey, `${usernameKey}_2`, `${usernameKey}_3`]) {
      await reservations.doc(k).delete();
    }
    console.log(`    reservations ${usernameKey}{,_2,_3} removed (admin)`);
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
  // Reservations refuse guests, so that suite runs as two password
  // accounts on example.com addresses, deleted in teardown.
  const c = await signUpWithPassword();
  const d = await signUpWithPassword();
  const usernameKey = randomKey();
  console.log(`  two throwaway anonymous users, two password users; test handle "${usernameKey}"`);

  await usersCreate(a, b);
  await usersAllowList(a, b);
  await provision(c);
  await provision(d);
  await usernames(c, d, usernameKey, a);
  await attemptsAndFlags(a, b);
  await feedbackAndUsage(a, b);
  await examResults(a, b);
  await progress(a, b);
  await studyData(a, b);
  await accountRequests(a, b);
  await waitlist(a, b);
  await plan(a, b);
  await challenges(a, b);
  await rooms(a, b);
  await staffProfiles(a, b);
  await learnGate(a, b);
  await content(a);

  await teardown([a, b, c, d], usernameKey);

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
