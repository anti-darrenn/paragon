// Applies reviewed topic reclassifications to the questions collection.
//
// Only rows marked confidence:"high" whose proposed topic differs from the
// current one are applied. Low-confidence rows (diagram-dependent or genuinely
// dual-fit questions) are deliberately left alone rather than guessed at.
//
// Dry run by default. Pass --commit to write.
//
//   node 8_apply_reclass.js
//   node 8_apply_reclass.js --commit
//   node 8_apply_reclass.js --commit --slice=math_a

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const RECLASS_DIR = process.env.RECLASS_DIR ||
  'C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Desktop-paragon/93725bc5-06fa-4fad-9892-e167d83e2c2f/scratchpad/reclass';

const SLICES = [
  ['math_a', 'math', 'gdv7zeXkoASauMlcmMnV'],
  ['math_b', 'math', 'gdv7zeXkoASauMlcmMnV'],
  ['physics_a', 'physics', '3DenliOp1ceDhiVDvNTX'],
  ['physics_b', 'physics', '3DenliOp1ceDhiVDvNTX'],
  ['fmaths', 'fmaths', 'iXlgqvDtHn3rTWykgqoA'],
];

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const sliceArg = args.find((a) => a.startsWith('--slice='));
const only = sliceArg ? sliceArg.split('=')[1] : null;
const BATCH = 400;

const key = require('./data/serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(key) });
const db = admin.firestore();

function loadSlice(slice, subj) {
  const inp = JSON.parse(fs.readFileSync(path.join(RECLASS_DIR, `in_${slice}.json`), 'utf8'));
  const out = JSON.parse(fs.readFileSync(path.join(RECLASS_DIR, `out_${slice}.json`), 'utf8'));
  const tops = JSON.parse(fs.readFileSync(path.join(RECLASS_DIR, `topics_${subj}.json`), 'utf8'));
  const valid = new Set(tops.map((t) => t.topicId));

  // revalidate here too - never apply a file that has not been checked in this process
  if (out.length !== inp.length) throw new Error(`${slice}: length mismatch`);
  const seen = new Set();
  out.forEach((r, i) => {
    if (r.id !== inp[i].id) throw new Error(`${slice}: row ${i} id mismatch`);
    if (seen.has(r.id)) throw new Error(`${slice}: duplicate id ${r.id}`);
    seen.add(r.id);
    if (!valid.has(r.proposedTopicId)) throw new Error(`${slice}: invalid topicId ${r.proposedTopicId}`);
    if (r.confidence !== 'high' && r.confidence !== 'low') throw new Error(`${slice}: bad confidence`);
  });

  const current = {};
  inp.forEach((r) => { current[r.id] = r.currentTopicId; });
  const changes = out
    .filter((r) => r.confidence === 'high' && current[r.id] !== r.proposedTopicId)
    .map((r) => ({ id: r.id, from: current[r.id], to: r.proposedTopicId }));
  const lowSkipped = out.filter((r) => r.confidence === 'low' && current[r.id] !== r.proposedTopicId).length;
  return { changes, lowSkipped, total: out.length };
}

(async () => {
  console.log(COMMIT ? '=== COMMIT MODE - writing to Firestore ===' : '=== DRY RUN - no writes (pass --commit) ===\n');

  const plans = [];
  for (const [slice, subj, subjectId] of SLICES) {
    if (only && slice !== only) continue;
    const p = loadSlice(slice, subj);
    plans.push({ slice, subjectId, ...p });
    console.log(`${slice.padEnd(11)} ${String(p.changes.length).padStart(4)} high-confidence reassignments` +
                `  (${p.lowSkipped} low-confidence differences deliberately skipped, of ${p.total})`);
  }

  const all = plans.flatMap((p) => p.changes);
  const subjects = Array.from(new Set(plans.map((p) => p.subjectId)));
  console.log(`\ntotal to reassign: ${all.length} questions across ${subjects.length} subject(s)`);

  if (!COMMIT) {
    console.log('\nDry run only. Re-run with --commit to write.');
    return;
  }

  let done = 0;
  for (let i = 0; i < all.length; i += BATCH) {
    const chunk = all.slice(i, i + BATCH);
    const batch = db.batch();
    for (const c of chunk) {
      batch.update(db.collection('questions').doc(c.id), {
        topicId: c.to,
        reclassifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        previousTopicId: c.from,
      });
    }
    await batch.commit();
    done += chunk.length;
    process.stdout.write(`\r  reassigning... ${done}/${all.length}`);
  }
  process.stdout.write('\r');
  console.log(`  reassigned ${done} questions.`);

  // questionCount is now stale for every topic in every affected subject
  console.log('\nrecomputing topic.questionCount from live data...');
  let touched = 0;
  for (const subjectId of subjects) {
    const topics = await db.collection('topics').where('subjectId', '==', subjectId).get();
    for (const t of topics.docs) {
      const snap = await db.collection('questions').where('topicId', '==', t.id).get();
      if ((t.data().questionCount ?? -1) !== snap.size) {
        await db.collection('topics').doc(t.id).update({ questionCount: snap.size });
        touched++;
      }
    }
  }
  console.log(`  updated questionCount on ${touched} topics.`);
  console.log('\nDONE.');
})().catch((e) => { console.error(e); process.exit(1); });
