/**
 * Exercises the live `progress/{uid}` security rules as a real client
 * sees them.
 *
 *   node verify_rules.js
 *
 * ── Why this exists ──────────────────────────────────────────────────
 *
 * `firestore.rules` had never been tested dynamically. The usual answer
 * is the Firestore emulator, which needs Java, which this machine does
 * not have — so the rules were shipped on a `--dry-run` compile and
 * careful reading, and `docs/audit/NEXT.md` has carried that as a stated
 * verification gap.
 *
 * This closes it for one collection without needing Java. It signs in
 * anonymously through the Identity Toolkit REST API and writes through
 * the Firestore REST API, so every request is evaluated by the real
 * deployed rules. It deliberately uses **no Admin SDK**: the Admin SDK
 * bypasses rules entirely, so a test written with it would pass no matter
 * how wrong the rules were.
 *
 * ── Why the failures matter more than the successes ──────────────────
 *
 * A write that succeeds tells you only that something allowed it. The
 * rule is doing its job only if a write that ought to be refused actually
 * is, so the unlisted-field and other-user cases are the real content
 * here. Delete them and this file stops meaning anything.
 *
 * Runs against production. It writes one document and creates one
 * anonymous account, then removes both. The API key is the public web
 * key already shipped in `firebase_options.dart` and the web bundle;
 * it identifies the project and grants nothing on its own.
 */

const API_KEY = 'AIzaSyDgPksUP3MZ9gX-baZSyXiMIg07wWwjGOA';
const PROJECT = 'paragon-hq';
// The commit endpoint wants a resource path; the REST URLs want it
// prefixed. Conflating the two is what the first run of this got wrong.
const RESOURCE = `projects/${PROJECT}/databases/(default)/documents`;
const DOCS = `https://firestore.googleapis.com/v1/${RESOURCE}`;

let pass = 0;
let fail = 0;

function check(label, ok, detail) {
  if (ok) {
    pass++;
    console.log(`  PASS  ${label}`);
  } else {
    fail++;
    console.log(`  FAIL  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

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

// One commit, shaped like what `ProgressRepository.addSession` sends:
// merge semantics (updateMask) plus a serverTimestamp transform.
async function commitProgress(idToken, docUid, { extraField = false } = {}) {
  const fields = {
    userId: { stringValue: docUid },
    topics: {
      mapValue: {
        fields: {
          topicVerify: {
            mapValue: {
              fields: {
                answered: { integerValue: '5' },
                correct: { integerValue: '4' },
                subjectId: { stringValue: 'subjectVerify' },
              },
            },
          },
        },
      },
    },
  };
  const mask = ['userId', 'topics'];

  if (extraField) {
    fields.totalXP = { integerValue: '9999' };
    mask.push('totalXP');
  }

  const res = await fetch(`${DOCS}:commit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: { name: `${RESOURCE}/progress/${docUid}`, fields },
          updateMask: { fieldPaths: mask },
          updateTransforms: [
            { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
          ],
        },
      ],
    }),
  });
  return { status: res.status, body: await res.json() };
}

(async () => {
  console.log(`Verifying progress/{uid} rules on ${PROJECT} as a real client\n`);

  const me = await signInAnonymously();
  console.log(`anonymous uid: ${me.uid}\n`);

  // 1. The write the app actually makes.
  const valid = await commitProgress(me.idToken, me.uid);
  check(
    'a drill session write is accepted',
    valid.status === 200,
    `HTTP ${valid.status} ${JSON.stringify(valid.body).slice(0, 200)}`,
  );

  // 2. Control: a field outside the closed set must be refused. This is
  //    the rule that stops `progress` becoming a place a client can park
  //    whatever it likes — a stray `totalXP` among them.
  const extra = await commitProgress(me.idToken, me.uid, { extraField: true });
  check(
    'a write carrying an unlisted field is refused',
    extra.status === 403,
    `HTTP ${extra.status} (expected 403)`,
  );

  // 3. Control: another student's document is not writable.
  const other = await commitProgress(me.idToken, 'someone-elses-uid');
  check(
    "another student's progress is not writable",
    other.status === 403,
    `HTTP ${other.status} (expected 403)`,
  );

  // 4. Own document reads back, with the server timestamp the rule pinned.
  const read = await fetch(`${DOCS}/progress/${me.uid}`, {
    headers: { Authorization: `Bearer ${me.idToken}` },
  });
  const doc = await read.json();
  check('own progress reads back', read.status === 200, `HTTP ${read.status}`);
  check(
    'updatedAt was written as a real server timestamp',
    Boolean(doc.fields?.updatedAt?.timestampValue),
    JSON.stringify(doc.fields?.updatedAt),
  );
  const answered =
    doc.fields?.topics?.mapValue?.fields?.topicVerify?.mapValue?.fields
      ?.answered?.integerValue;
  check('the session counters round-trip', answered === '5', `got ${answered}`);

  // 5. Control: another student's document is not readable either.
  const readOther = await fetch(`${DOCS}/progress/someone-elses-uid`, {
    headers: { Authorization: `Bearer ${me.idToken}` },
  });
  check(
    "another student's progress is not readable",
    readOther.status === 403,
    `HTTP ${readOther.status} (expected 403)`,
  );

  // ── Cleanup ─────────────────────────────────────────────────────────
  const del = await fetch(`${DOCS}/progress/${me.uid}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${me.idToken}` },
  });
  check('a student can delete their own progress', del.status === 200);

  await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: me.idToken }),
    },
  );
  console.log('\nthrowaway anonymous account deleted');

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
