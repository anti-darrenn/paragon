// Generates AI-authored drill questions into ../data/generated_<subject>_<topic>.json
// WARNING: generators use unseeded Math.random(), so re-running OVERWRITES the
// existing files with a different set of questions. The committed output is the
// canonical content; only re-run when you intend to replace it.
//   node run.js math_num_a math_num_b ...   (COUNT=300 by default)

const L = require('./lib');

const SUBJECTS = {
  math: { subjectId: 'gdv7zeXkoASauMlcmMnV', subjectSlug: 'math' },
  physics: { subjectId: '3DenliOp1ceDhiVDvNTX', subjectSlug: 'physics' },
  fmaths: { subjectId: 'iXlgqvDtHn3rTWykgqoA', subjectSlug: 'further-maths' },
};

// module file -> subject key
const MODULE_SUBJECT = {
  math_num_a: 'math', math_num_b: 'math', math_algebra: 'math',
  math_geometry: 'math', math_trig: 'math', math_calc_stats: 'math', math_trig_calc: 'math',
  fmaths_a: 'fmaths', fmaths_b: 'fmaths',
  physics_a: 'physics', physics_b: 'physics', physics_c: 'physics',
  physics_d: 'physics', physics_e: 'physics',
};

const COUNT = Number(process.env.COUNT || 300);
const mods = process.argv.slice(2);
if (mods.length === 0) { console.error('usage: node run.js <module> [module...]'); process.exit(1); }

let grand = 0;
const short = [];

for (const m of mods) {
  const subjKey = MODULE_SUBJECT[m];
  if (!subjKey) { console.error(`no subject mapping for module ${m}`); process.exit(1); }
  const subj = SUBJECTS[subjKey];
  const topics = require(`./${m}`);
  console.log(`\n### ${m} (${subjKey}) — ${topics.length} topics`);
  for (const t of topics) {
    const res = L.buildTopic({
      subjectId: subj.subjectId,
      subjectSlug: subj.subjectSlug,
      unitId: t.unitId,
      topicId: t.topicId,
      topicName: t.topicName,
      generators: t.generators,
      count: COUNT,
    });
    grand += res.count;
    const flag = res.count < COUNT ? '  <-- SHORT' : '';
    if (res.count < COUNT) short.push(`${t.topicName}: ${res.count}/${COUNT}`);
    console.log(`  ${String(res.count).padStart(4)}  ${t.topicName}${flag}`);
  }
}

console.log(`\nTOTAL GENERATED: ${grand}`);
if (short.length) {
  console.log(`\nSHORT TOPICS (${short.length}):`);
  short.forEach(s => console.log('  ' + s));
}
