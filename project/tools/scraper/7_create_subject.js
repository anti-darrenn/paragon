// Creates a new subject tree (subject -> units -> topics) and seeds its
// generated questions, resumably and within the daily Spark write budget.
//
// Unit and topic names come from the gen/ modules, which take them from
// lib/core/content/subject_catalog.dart, so Firestore matches the outline the
// app's course page already renders.
//
// Everything is find-or-create and keyed by name, so this can be run over and
// over: it completes a half-built tree rather than refusing to touch it, and
// only seeds questions into topics that have none yet. A topic's questions are
// always written in a single atomic batch, so a topic is never left partly
// filled.
//
// Dry run by default. Pass --commit to write.
//
//   node 7_create_subject.js --subject=chemistry
//   node 7_create_subject.js --subject=chemistry --commit

const fs = require('fs');
const path = require('path');
const Q = require('./seed_quota');
const admin = Q.admin;

const DATA = path.join(__dirname, 'data');
const BATCH = 400;

const SUBJECTS = {
  chemistry: { name: 'Chemistry', slug: 'chemistry', modules: ['chem_a', 'chem_b', 'chem_c'] },
  government: { name: 'Government', slug: 'government', modules: ['gov_a', 'gov_b'] },
};

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const subjArg = args.find((a) => a.startsWith('--subject='));
if (!subjArg) {
  console.error('usage: node 7_create_subject.js --subject=<chemistry|government> [--commit]');
  process.exit(1);
}
const key = subjArg.split('=')[1];
const cfg = SUBJECTS[key];
if (!cfg) { console.error(`unknown subject: ${key}`); process.exit(1); }

admin.initializeApp({ credential: Q.loadCredential() });
const db = admin.firestore();

const slugify = (s) => s.toLowerCase()
  .replace(/['’]/g, '')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-+|-+$/g, '');

function buildTree() {
  const units = [];
  const byUnit = new Map();
  for (const m of cfg.modules) {
    for (const t of require(path.join(__dirname, 'gen', `${m}.js`))) {
      if (!byUnit.has(t.unitName)) {
        const u = { name: t.unitName, topics: [] };
        byUnit.set(t.unitName, u);
        units.push(u);
      }
      const file = path.join(DATA, `generated_${cfg.slug}_${slugify(t.topicName)}.json`);
      if (!fs.existsSync(file)) throw new Error(`missing generated file for "${t.topicName}"`);
      const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (!Array.isArray(rows) || rows.length === 0) throw new Error(`empty: ${path.basename(file)}`);
      for (const r of rows) {
        if (r.unitName !== t.unitName || r.topicName !== t.topicName) {
          throw new Error(`${path.basename(file)}: name mismatch`);
        }
        if (r.hasAnswer !== true) throw new Error(`${path.basename(file)}: hasAnswer must be true`);
        if (!Array.isArray(r.options) || r.options.length !== 4) throw new Error(`${path.basename(file)}: bad options`);
        if (typeof r.correctIndex !== 'number' || r.correctIndex < 0 || r.correctIndex > 3) {
          throw new Error(`${path.basename(file)}: bad correctIndex`);
        }
      }
      byUnit.get(t.unitName).topics.push({ name: t.topicName, rows });
    }
  }
  return units;
}

(async () => {
  console.log(COMMIT ? `=== ${cfg.name}: COMMIT ===` : `=== ${cfg.name}: DRY RUN (pass --commit) ===`);
  console.log(Q.summary());

  const units = buildTree();
  const topicTotal = units.reduce((a, u) => a + u.topics.length, 0);
  const qTotal = units.reduce((a, u) => a + u.topics.reduce((b, t) => b + t.rows.length, 0), 0);
  console.log(`outline: ${units.length} units, ${topicTotal} topics, ${qTotal} questions\n`);

  let budget = Q.remaining();

  // A subject or unit document with nothing under it is visible in the app as
  // an empty shell, so never create one unless the budget covers at least one
  // complete topic beneath it: subject + unit + topic doc + questions + count.
  const firstTopicRows = units[0].topics[0].rows.length;
  const minViable = 1 + 1 + 1 + firstTopicRows + 1;
  if (COMMIT && budget < minViable) {
    console.log(`Budget ${budget} cannot cover a first full topic (needs ${minViable}).`);
    console.log('Stopping before creating anything - an empty subject would show in the app.');
    console.log(Q.summary());
    return;
  }

  // ---- subject (find or create) ----
  const existing = await db.collection('subjects').where('name', '==', cfg.name).limit(1).get();
  let subjectId;
  let created = { subject: 0, units: 0, topics: 0, questions: 0 };

  if (!existing.empty) {
    subjectId = existing.docs[0].id;
    console.log(`subject exists: ${cfg.name} (${subjectId}) - resuming`);
  } else if (!COMMIT) {
    subjectId = '<new>';
    console.log(`would create subject ${cfg.name}`);
  } else {
    const ref = db.collection('subjects').doc();
    await ref.set({ name: cfg.name, unitCount: units.length });
    subjectId = ref.id;
    created.subject = 1; budget -= 1; Q.spend(1);
    console.log(`created subject ${cfg.name} (${subjectId})`);
  }

  // existing units/topics for this subject, read once
  const unitSnap = subjectId === '<new>' ? { docs: [] }
    : await db.collection('units').where('subjectId', '==', subjectId).get();
  const unitByName = new Map(unitSnap.docs.map((d) => [d.data().name, d.id]));
  const topicSnap = subjectId === '<new>' ? { docs: [] }
    : await db.collection('topics').where('subjectId', '==', subjectId).get();
  const topicByKey = new Map(topicSnap.docs.map((d) => [`${d.data().unitId}::${d.data().name}`, { id: d.id, count: d.data().questionCount ?? 0 }]));

  let stopped = false;
  let pendingTopics = 0;

  for (let ui = 0; ui < units.length && !stopped; ui++) {
    const u = units[ui];
    // Resolved here, but created lazily below - only once a topic is actually
    // going to be written under it, so a unit is never left childless.
    let unitId = unitByName.get(u.name);
    const ensureUnit = async () => {
      if (unitId) return unitId;
      if (!COMMIT) { unitId = `<unit ${ui}>`; return unitId; }
      const ref = db.collection('units').doc();
      await ref.set({ subjectId, name: u.name, order: ui });
      unitId = ref.id; created.units++; budget -= 1; Q.spend(1);
      return unitId;
    };

    for (let ti = 0; ti < u.topics.length && !stopped; ti++) {
      const t = u.topics[ti];
      const existingTopic = topicByKey.get(`${unitId}::${t.name}`);

      // already seeded? count() bills 1 read per 1000 docs, not 1 per doc
      if (existingTopic) {
        const n = await Q.countWhere(db, 'questions', 'topicId', existingTopic.id);
        if (n >= t.rows.length) continue;         // done already
      }

      pendingTopics++;
      // unit doc (if it does not exist yet) + topic doc + questions + count update
      const cost = (unitId ? 0 : 1) + (existingTopic ? 0 : 1) + t.rows.length + 1;
      if (!COMMIT) continue;

      if (cost > budget) {
        console.log(`\nbudget reached before "${u.name} / ${t.name}" (needs ${cost}, ${budget} left).`);
        stopped = true;
        break;
      }

      // only now is the unit guaranteed to get a child
      await ensureUnit();

      let topicId = existingTopic && existingTopic.id;
      if (!topicId) {
        const ref = db.collection('topics').doc();
        await ref.set({ subjectId, unitId, name: t.name, order: ti, questionCount: 0 });
        topicId = ref.id; created.topics++; budget -= 1; Q.spend(1);
      }

      // one atomic batch per topic - a topic is never partly filled
      const batch = db.batch();
      for (const r of t.rows) {
        batch.set(db.collection('questions').doc(), {
          text: r.text, options: r.options, correctIndex: r.correctIndex,
          explanation: r.explanation,
          subjectId, unitId, topicId,
          source: r.source, origin: r.origin, hasAnswer: r.hasAnswer,
          year: r.year ?? null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await db.collection('topics').doc(topicId).update({ questionCount: t.rows.length });
      created.questions += t.rows.length;
      budget -= t.rows.length + 1; Q.spend(t.rows.length + 1);
      process.stdout.write(`\r  seeded ${created.questions} questions (${budget} writes left)`.padEnd(70));
    }
  }
  process.stdout.write('\r'.padEnd(70) + '\r');

  if (!COMMIT) {
    console.log(`${pendingTopics} topic(s) still need seeding. Re-run with --commit.`);
    return;
  }

  // keep unitCount honest even on a partial run
  await db.collection('subjects').doc(subjectId).update({ unitCount: units.length });
  Q.spend(1);

  console.log(`created: ${created.subject} subject, ${created.units} units, ${created.topics} topics, ${created.questions} questions`);
  console.log(Q.summary());
  console.log(stopped
    ? `\nSTOPPED on budget. Re-run tomorrow to continue - it resumes where it left off.`
    : `\n${cfg.name} is fully seeded.`);
})().catch((e) => { console.error('\n' + (e.message || e)); process.exit(1); });
