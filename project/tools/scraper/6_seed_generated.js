// Additive seeder for AI-generated drill questions.
//
// Unlike 3_seed.js this NEVER creates subject/unit/topic documents - it inserts
// questions against IDs that already exist and then corrects topic.questionCount.
// Running 3_seed.js against a live subject would create a duplicate subject doc.
//
// Dry run by default. Pass --commit to actually write.
//
//   node 6_seed_generated.js --file=generated_math_number-bases.json
//   node 6_seed_generated.js --file=generated_math_number-bases.json --commit
//   node 6_seed_generated.js --all --commit
//   node 6_seed_generated.js --all --commit --force   (re-seed topics already seeded)

const fs = require('fs');
const path = require('path');
const Q = require('./seed_quota');
const admin = Q.admin;

const DATA = path.join(__dirname, 'data');
const BATCH = 400;                       // Firestore hard limit is 500 ops
const REQUIRED = ['text', 'options', 'correctIndex', 'explanation',
                  'subjectId', 'unitId', 'topicId', 'source', 'origin', 'hasAnswer'];

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const FORCE = args.includes('--force');
const ALL = args.includes('--all');
const fileArg = args.find((a) => a.startsWith('--file='));

if (!ALL && !fileArg) {
  console.error('usage: node 6_seed_generated.js (--all | --file=<name>.json) [--commit] [--force]');
  process.exit(1);
}

admin.initializeApp({ credential: Q.loadCredential() });
const db = admin.firestore();

// Files for subjects that do not exist in Firestore yet are keyed by name, not
// id - those belong to 7_create_subject.js, so --all leaves them alone.
function isPending(f) {
  try {
    const rows = JSON.parse(fs.readFileSync(path.join(DATA, f), 'utf8'));
    return Array.isArray(rows) && rows.length > 0 && !rows[0].topicId;
  } catch (e) { return false; }
}

let pendingSkipped = 0;
const files = ALL
  ? fs.readdirSync(DATA)
      .filter((f) => f.startsWith('generated_') && f.endsWith('.json'))
      .filter((f) => { if (isPending(f)) { pendingSkipped++; return false; } return true; })
      .sort()
  : [fileArg.split('=')[1]];

// Validates the file is internally consistent and its IDs exist in Firestore.
async function inspect(file) {
  const full = path.join(DATA, file);
  if (!fs.existsSync(full)) throw new Error(`no such file: ${file}`);
  const rows = JSON.parse(fs.readFileSync(full, 'utf8'));
  if (!Array.isArray(rows) || rows.length === 0) throw new Error(`${file}: empty`);

  for (let i = 0; i < rows.length; i++) {
    for (const f of REQUIRED) {
      if (rows[i][f] === undefined) throw new Error(`${file}[${i}]: missing ${f}`);
    }
    if (!Array.isArray(rows[i].options) || rows[i].options.length !== 4) {
      throw new Error(`${file}[${i}]: options must have 4 entries`);
    }
    const ci = rows[i].correctIndex;
    if (typeof ci !== 'number' || ci < 0 || ci > 3) {
      throw new Error(`${file}[${i}]: bad correctIndex`);
    }
    if (rows[i].hasAnswer !== true) throw new Error(`${file}[${i}]: hasAnswer must be true`);
  }

  const { subjectId, unitId, topicId } = rows[0];
  for (const r of rows) {
    if (r.subjectId !== subjectId || r.unitId !== unitId || r.topicId !== topicId) {
      throw new Error(`${file}: mixed subject/unit/topic ids in one file`);
    }
  }

  const [subjSnap, unitSnap, topicSnap] = await Promise.all([
    db.collection('subjects').doc(subjectId).get(),
    db.collection('units').doc(unitId).get(),
    db.collection('topics').doc(topicId).get(),
  ]);
  if (!subjSnap.exists) throw new Error(`${file}: subject ${subjectId} does not exist`);
  if (!unitSnap.exists) throw new Error(`${file}: unit ${unitId} does not exist`);
  if (!topicSnap.exists) throw new Error(`${file}: topic ${topicId} does not exist`);

  const t = topicSnap.data();
  if (t.unitId !== unitId || t.subjectId !== subjectId) {
    throw new Error(`${file}: topic ${topicId} is not under unit ${unitId} / subject ${subjectId}`);
  }

  // count() bills one read per 1000 index entries rather than one per document.
  // Fetching whole topics just to count them is what drained the read quota.
  const liveTotal = await Q.countWhere(db, 'questions', 'topicId', topicId);
  const storedCountNow = t.questionCount ?? 0;
  // A topic is seeded in one atomic batch, so "already seeded" is simply
  // "holds at least as many questions as the file would add".
  const alreadyAi = liveTotal >= rows.length ? liveTotal : 0;

  return {
    file, rows, subjectId, unitId, topicId,
    subjectName: subjSnap.data().name,
    topicName: t.name,
    storedCount: storedCountNow,
    liveTotal,
    alreadyAi,
  };
}

async function seed(info) {
  const { rows, topicId } = info;
  let written = 0;

  for (let i = 0; i < rows.length; i += BATCH) {
    const chunk = rows.slice(i, i + BATCH);
    const batch = db.batch();
    for (const r of chunk) {
      // auto-ID: drillQuestionsProvider rotates with a random cursor over
      // FieldPath.documentId, so IDs must be randomly distributed
      const ref = db.collection('questions').doc();
      batch.set(ref, {
        text: r.text,
        options: r.options,
        correctIndex: r.correctIndex,
        explanation: r.explanation,
        subjectId: r.subjectId,
        unitId: r.unitId,
        topicId: r.topicId,
        source: r.source,
        origin: r.origin,
        hasAnswer: r.hasAnswer,
        year: r.year ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    written += chunk.length;
    process.stdout.write(`\r    writing... ${written}/${rows.length}`);
  }
  process.stdout.write('\r');

  // recount from live data rather than trusting arithmetic, via count()
  const after = await Q.countWhere(db, 'questions', 'topicId', topicId);
  await db.collection('topics').doc(topicId).update({ questionCount: after });
  return { written, newTotal: after };
}

(async () => {
  console.log(COMMIT ? '=== COMMIT MODE - writing to Firestore ===' : '=== DRY RUN - no writes (pass --commit) ===');
  console.log(`files: ${files.length}\n`);

  const plans = [];
  let inspectBudget = Q.remaining();
  let notInspected = 0;
  for (const f of files) {
    // Inspecting costs reads, and there is no point inspecting more topics
    // than today's write budget could ever seed. The run that blew the quota
    // did so partly by inspecting all 127 files before writing anything.
    if (COMMIT && inspectBudget <= 0) { notInspected++; continue; }
    try {
      const p = await inspect(f);
      plans.push(p);
      if (p.alreadyAi === 0) inspectBudget -= p.rows.length + 1;
    } catch (e) {
      // A quota error will hit every remaining file too, and each one costs a
      // slow gRPC retry, so stop rather than grinding through all of them.
      if (Q.isQuota(e)) throw e;
      console.error(`  SKIP  ${f}\n        ${e.message}`);
    }
  }
  if (notInspected) {
    console.log(`  (${notInspected} file(s) not inspected - today's write budget is already committed)\n`);
  }

  let totalToWrite = 0, skipped = 0;
  for (const p of plans) {
    const dup = p.alreadyAi > 0 && !FORCE;
    if (dup) skipped++;
    else totalToWrite += p.rows.length;
    console.log(
      `${dup ? 'SKIP ' : 'SEED '} ${p.subjectName} / ${p.topicName}\n` +
      `        +${p.rows.length} questions | live now: ${p.liveTotal}` +
      ` (${p.alreadyAi} already ai_generated) | topic.questionCount: ${p.storedCount}` +
      (dup ? '\n        already seeded - pass --force to add another batch' : '')
    );
  }

  console.log(`\nplanned: ${totalToWrite} new questions across ${plans.length - skipped} topics` +
              (skipped ? `, ${skipped} skipped` : ''));

  if (!COMMIT) {
    console.log('\nDry run only. Re-run with --commit to write.');
    return;
  }

  let grand = 0, budget = Q.remaining(), stopped = false, pending = 0;
  for (const p of plans) {
    if (p.alreadyAi > 0 && !FORCE) continue;
    const cost = p.rows.length + 1;        // questions plus the questionCount update
    if (cost > budget) { pending++; stopped = true; continue; }
    console.log(`\n-> ${p.subjectName} / ${p.topicName}`);
    const res = await seed(p);
    grand += res.written;
    budget -= cost;
    Q.spend(cost);
    console.log(`   wrote ${res.written}, topic.questionCount now ${res.newTotal} (${budget} writes left today)`);
  }

  console.log(`\n${grand} questions written. ${Q.summary()}`);
  console.log(stopped
    ? `STOPPED on budget with ${pending}+ topic(s) still pending. Re-run after the Pacific midnight reset — it resumes automatically.`
    : 'DONE — nothing left pending in this run.');
})().catch((e) => { console.error('\n' + Q.explain(e)); process.exit(1); });
