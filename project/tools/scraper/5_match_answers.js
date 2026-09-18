// matches scraped answers (data/answers_<subject>.json) onto existing firestore
// question docs, then optionally backfills correctIndex / explanation / sourceId
//
//   node 5_match_answers.js            dry run — reports coverage, writes nothing
//   node 5_match_answers.js --apply    performs the backfill
//
// the seeder never stored a myschool id, so the join is on normalized question
// text. a wrong match means a wrong answer taught as correct, so the gate is
// deliberately strict: text + year + every option must line up, and correctIndex
// is derived from the STORED option order, never the source's.

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const admin = require('firebase-admin');

// maps the url slug to the subjects/{id}.name stored in firestore
const SUBJECT_NAMES = {
  mathematics: 'Mathematics',
  physics: 'Physics',
  'further-mathematics': 'Further Mathematics',
};

// edit per run, or override: node 5_match_answers.js physics --apply
const SUBJECT =
  process.argv.slice(2).find((a) => Object.keys(SUBJECT_NAMES).includes(a)) || 'mathematics';

const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 450;
const DATA_DIR = path.join(__dirname, 'data');

// cheerio strips tags and decodes every named entity (&ordm; &ang; &deg; ...).
// a hand-rolled entity map missed those and cost real matches
function stripHtml(s) {
  return cheerio.load(`<div>${s}</div>`)('div').text();
}

// decodes one entity at a time so surrounding text is never html-parsed
const entityCache = new Map();
function decodeEntities(s) {
  return s.replace(/&[a-zA-Z][a-zA-Z0-9]*;|&#\d+;/g, (m) => {
    if (!entityCache.has(m)) entityCache.set(m, stripHtml(m));
    return entityCache.get(m);
  });
}

const collapse = (s) => s.replace(/\s+/g, ' ').trim();

// scraped side — real html, so tags must go
function normalizeHtml(s) {
  if (typeof s !== 'string') return '';
  return collapse(stripHtml(s));
}

// stored side — already plain text, and maths text legitimately contains bare
// '<' (angles like <QST, inequalities). running a html parser over it would
// silently eat everything from the '<' onward, so only entities are decoded
function normalizeText(s) {
  if (typeof s !== 'string') return '';
  return collapse(decodeEntities(s));
}

// html -> plain text for storage. FullLatexView renders latex but not html,
// so paragraph breaks are converted before the tags are stripped
function htmlToText(s) {
  if (typeof s !== 'string') return '';
  const withBreaks = s
    .replace(/<\s*br\s*\/?\s*>/gi, '\n')
    .replace(/<\s*\/\s*p\s*>/gi, '\n\n');
  return stripHtml(withBreaks)
    .replace(/\r/g, '')
    .replace(/[ \t ]+/g, ' ')
    .split('\n')
    .map((l) => l.trim())
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function loadAnswers() {
  const file = path.join(DATA_DIR, `answers_${SUBJECT}.json`);
  if (!fs.existsSync(file)) {
    throw new Error(`missing ${file} — run 4_scrape_answers.js first`);
  }
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// one scraped record vs one firestore doc — returns correctIndex or a reason
function evaluate(stored, scraped) {
  const correctOpts = scraped.options.filter((o) => o.isCorrect);
  if (correctOpts.length === 0) return { reason: 'no_correct_option' };
  if (correctOpts.length > 1) return { reason: 'multiple_correct' };

  if (!Array.isArray(stored.options)) return { reason: 'option_text_mismatch' };
  if (stored.options.length !== scraped.options.length) {
    return { reason: 'option_count_mismatch' };
  }

  const storedNorm = stored.options.map(normalizeText);
  const scrapedNorm = scraped.options.map((o) => normalizeHtml(o.description));

  // every stored option must exist in the scrape — guards against a text
  // collision pulling in a different question's answer
  const pool = [...scrapedNorm];
  for (const s of storedNorm) {
    const at = pool.indexOf(s);
    if (at === -1) return { reason: 'option_text_mismatch' };
    pool.splice(at, 1);
  }

  const correctNorm = normalizeHtml(correctOpts[0].description);
  const hits = storedNorm.reduce((acc, s, i) => (s === correctNorm ? [...acc, i] : acc), []);
  if (hits.length === 0) return { reason: 'option_text_mismatch' };
  // duplicate option text — real in this data, and unresolvable
  if (hits.length > 1) return { reason: 'ambiguous_correct' };

  return { correctIndex: hits[0] };
}

async function main() {
  const serviceAccount = require('./data/serviceAccountKey.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  const subjectName = SUBJECT_NAMES[SUBJECT];
  if (!subjectName) throw new Error(`unknown SUBJECT slug: ${SUBJECT}`);

  const subjSnap = await db.collection('subjects').where('name', '==', subjectName).get();
  if (subjSnap.empty) throw new Error(`no subjects doc named ${subjectName}`);
  const subjectId = subjSnap.docs[0].id;

  const answers = loadAnswers();
  console.log(`scraped records: ${answers.length}`);

  const qSnap = await db
    .collection('questions')
    .where('subjectId', '==', subjectId)
    .where('source', '==', 'waec')
    .get();
  console.log(`firestore questions for ${subjectName}: ${qSnap.size}\n`);

  // index the scrape by year + normalized text
  const byKey = new Map();
  const dupKeys = new Set();
  for (const a of answers) {
    const key = `${a.year}||${normalizeHtml(a.questionHtml)}`;
    if (byKey.has(key)) dupKeys.add(key);
    byKey.set(key, a);
  }

  const stats = {};
  const updates = [];
  const bump = (year, reason) => {
    stats[year] = stats[year] || { total: 0 };
    stats[year][reason] = (stats[year][reason] || 0) + 1;
  };

  for (const doc of qSnap.docs) {
    const stored = doc.data();
    const year = stored.year ?? 'unknown';
    stats[year] = stats[year] || { total: 0 };
    stats[year].total++;

    const key = `${stored.year}||${normalizeText(stored.text)}`;
    if (dupKeys.has(key)) {
      bump(year, 'ambiguous_text');
      continue;
    }
    const scraped = byKey.get(key);
    if (!scraped) {
      bump(year, 'no_text_match');
      continue;
    }

    const res = evaluate(stored, scraped);
    if (res.reason) {
      bump(year, res.reason);
      continue;
    }

    bump(year, 'matched');
    if (scraped.hasImage) bump(year, 'matched_with_image');
    updates.push({
      id: doc.id,
      correctIndex: res.correctIndex,
      explanation: htmlToText(scraped.explanationHtml || ''),
      sourceId: scraped.sourceId,
    });
  }

  const years = Object.keys(stats).sort();
  console.log('year   total  matched  noText  optCnt  optTxt  ambig  noCorr  multi  (img)');
  for (const y of years) {
    const s = stats[y];
    const cell = (n) => String(n || 0).padStart(6);
    console.log(
      `${String(y).padEnd(6)}${cell(s.total)}${cell(s.matched)}${cell(s.no_text_match)}` +
        `${cell(s.option_count_mismatch)}${cell(s.option_text_mismatch)}` +
        `${cell((s.ambiguous_correct || 0) + (s.ambiguous_text || 0))}` +
        `${cell(s.no_correct_option)}${cell(s.multiple_correct)}${cell(s.matched_with_image)}`
    );
  }

  const totalDocs = qSnap.size;
  const matched = updates.length;
  const withExpl = updates.filter((u) => u.explanation).length;
  console.log(
    `\nmatched ${matched}/${totalDocs} (${((matched / totalDocs) * 100).toFixed(1)}%)` +
      ` — ${withExpl} with an explanation`
  );

  if (!APPLY) {
    console.log('\ndry run — nothing written. rerun with --apply to backfill.');
    return;
  }

  console.log(`\napplying ${matched} updates...`);
  for (let i = 0; i < updates.length; i += BATCH_SIZE) {
    const chunk = updates.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const u of chunk) {
      batch.update(db.collection('questions').doc(u.id), {
        correctIndex: u.correctIndex,
        explanation: u.explanation,
        sourceId: u.sourceId,
        hasAnswer: true,
      });
    }
    await batch.commit();
    console.log(`  committed ${Math.min(i + BATCH_SIZE, updates.length)}/${updates.length}`);
  }
  console.log('done.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(`FAILED: ${err.message}`);
    process.exit(1);
  });
