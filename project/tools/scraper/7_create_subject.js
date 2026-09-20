// Creates a brand-new subject tree (subject -> units -> topics) and seeds its
// generated questions in one run, so the subject never appears empty in the app.
//
// Unlike 3_seed.js this is driven by the gen/ modules, whose unit and topic
// names come from lib/core/content/subject_catalog.dart - so the Firestore tree
// matches the outline the app's course page already renders. It refuses to run
// if a subject of the same name already exists.
//
// Dry run by default. Pass --commit to write.
//
//   node 7_create_subject.js --subject=chemistry
//   node 7_create_subject.js --subject=chemistry --commit

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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

const sa = require('./data/serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// must match lib.slugify so generated filenames resolve
const slugify = (s) => s.toLowerCase()
  .replace(/['’]/g, '')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-+|-+$/g, '');

// Build the ordered unit/topic tree from the generator modules, which are
// declared in catalog order.
function buildTree() {
  const units = [];      // [{ name, topics: [{ name, file, rows }] }]
  const byUnit = new Map();
  for (const m of cfg.modules) {
    const topics = require(path.join(__dirname, 'gen', `${m}.js`));
    for (const t of topics) {
      if (!byUnit.has(t.unitName)) {
        const u = { name: t.unitName, topics: [] };
        byUnit.set(t.unitName, u);
        units.push(u);
      }
      const file = path.join(DATA, `generated_${cfg.slug}_${slugify(t.topicName)}.json`);
      if (!fs.existsSync(file)) throw new Error(`missing generated file for "${t.topicName}": ${path.basename(file)}`);
      const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (!Array.isArray(rows) || rows.length === 0) throw new Error(`empty: ${path.basename(file)}`);
      for (const r of rows) {
        if (r.topicName !== t.topicName || r.unitName !== t.unitName) {
          throw new Error(`${path.basename(file)}: name mismatch (${r.unitName} / ${r.topicName})`);
        }
        if (r.hasAnswer !== true) throw new Error(`${path.basename(file)}: hasAnswer must be true`);
        if (!Array.isArray(r.options) || r.options.length !== 4) throw new Error(`${path.basename(file)}: bad options`);
        if (typeof r.correctIndex !== 'number' || r.correctIndex < 0 || r.correctIndex > 3) {
          throw new Error(`${path.basename(file)}: bad correctIndex`);
        }
      }
      byUnit.get(t.unitName).topics.push({ name: t.topicName, file, rows });
    }
  }
  return units;
}

(async () => {
  console.log(COMMIT ? `=== COMMIT MODE - creating ${cfg.name} in Firestore ===` : `=== DRY RUN for ${cfg.name} - no writes (pass --commit) ===`);

  const existing = await db.collection('subjects').where('name', '==', cfg.name).get();
  if (!existing.empty) {
    console.error(`\n${cfg.name} already exists in Firestore (id=${existing.docs[0].id}).`);
    console.error('Refusing to create a duplicate subject. Use 6_seed_generated.js to add questions to it.');
    process.exit(1);
  }

  const units = buildTree();
  const topicCount = units.reduce((a, u) => a + u.topics.length, 0);
  const qCount = units.reduce((a, u) => a + u.topics.reduce((b, t) => b + t.rows.length, 0), 0);

  console.log(`\n${cfg.name}: ${units.length} units, ${topicCount} topics, ${qCount} questions`);
  units.forEach((u, i) => {
    console.log(`  ${String(i).padStart(2)}. ${u.name}  (${u.topics.length} topics, ${u.topics.reduce((a, t) => a + t.rows.length, 0)} questions)`);
  });

  if (!COMMIT) {
    console.log('\nDry run only. Re-run with --commit to create.');
    return;
  }

  // 1. subject
  const subjectRef = db.collection('subjects').doc();
  await subjectRef.set({ name: cfg.name, unitCount: units.length });
  console.log(`\ncreated subject ${cfg.name} (${subjectRef.id})`);

  // 2. units and topics
  let written = 0;
  for (let ui = 0; ui < units.length; ui++) {
    const u = units[ui];
    const unitRef = db.collection('units').doc();
    await unitRef.set({ subjectId: subjectRef.id, name: u.name, order: ui });

    for (let ti = 0; ti < u.topics.length; ti++) {
      const t = u.topics[ti];
      const topicRef = db.collection('topics').doc();
      await topicRef.set({
        subjectId: subjectRef.id,
        unitId: unitRef.id,
        name: t.name,
        order: ti,
        questionCount: t.rows.length,
      });

      // 3. questions - auto-ids, required by the drill provider's random
      // document-id rotation cursor
      for (let i = 0; i < t.rows.length; i += BATCH) {
        const chunk = t.rows.slice(i, i + BATCH);
        const batch = db.batch();
        for (const r of chunk) {
          batch.set(db.collection('questions').doc(), {
            text: r.text,
            options: r.options,
            correctIndex: r.correctIndex,
            explanation: r.explanation,
            subjectId: subjectRef.id,
            unitId: unitRef.id,
            topicId: topicRef.id,
            source: r.source,
            origin: r.origin,
            hasAnswer: r.hasAnswer,
            year: r.year ?? null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        written += chunk.length;
      }
      process.stdout.write(`\r  ${u.name} / ${t.name}  (${written}/${qCount})`.padEnd(100));
    }
  }
  process.stdout.write('\r'.padEnd(100) + '\r');

  console.log(`\nDONE. ${cfg.name}: ${units.length} units, ${topicCount} topics, ${written} questions.`);
  console.log(`subjectId = ${subjectRef.id}`);
})().catch((e) => { console.error('\n' + e.message); process.exit(1); });
