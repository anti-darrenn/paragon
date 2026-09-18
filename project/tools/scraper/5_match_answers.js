// matches scraped answers (data/answers_<subject>.json) onto existing firestore
// question docs, then optionally backfills correctIndex / explanation / sourceId
//
//   node 5_match_answers.js <subject>              dry run — reports, writes nothing
//   node 5_match_answers.js <subject> --apply      backfill answers
//   node 5_match_answers.js <subject> --apply --fix-years   also correct stored year
//
// the seeder never stored a myschool id, so the join is on normalized question
// text. a wrong match means a wrong answer taught as correct, so the gate is
// deliberately strict: every option must line up, and correctIndex is derived
// from the STORED option order, never the source's.
//
// year is NOT part of the match key. 1_scrape.js trusted the url's exam_year,
// but the site silently serves another year when it doesn't stock the one asked
// for — so some stored years are wrong, and matching on year would hide that as
// a text miss. year is reported (and optionally corrected) instead.

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

const SUBJECT =
  process.argv.slice(2).find((a) => Object.keys(SUBJECT_NAMES).includes(a)) || 'mathematics';
const APPLY = process.argv.includes('--apply');
const FIX_YEARS = process.argv.includes('--fix-years');
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
    .replace(/[ \t]+/g, ' ')
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
  const subjSnap = await db.collection('subjects').where('name', '==', subjectName).get();
  if (subjSnap.empty) throw new Error(`no subjects doc named ${subjectName}`);
  const subjectId = subjSnap.docs[0].id;

  const answers = loadAnswers();
  const qSnap = await db
    .collection('questions')
    .where('subjectId', '==', subjectId)
    .where('source', '==', 'waec')
    .get();

  console.log(`\n=== ${subjectName} ===`);
  console.log(`scraped records:      ${answers.length}`);
  console.log(`firestore questions:  ${qSnap.size}`);

  // text-only index. waec reuses questions across years, so one text can map
  // to several records — kept as a list rather than collapsed
  const byText = new Map();
  for (const a of answers) {
    const key = normalizeHtml(a.questionHtml);
    if (!byText.has(key)) byText.set(key, []);
    byText.get(key).push(a);
  }

  const reasons = {};
  const updates = [];
  const yearShifts = new Map();
  const misses = [];
  let strictMatched = 0;
  let yearMismatch = 0;
  let yearUnknowable = 0;
  const bump = (r) => (reasons[r] = (reasons[r] || 0) + 1);

  for (const doc of qSnap.docs) {
    const stored = doc.data();
    const candidates = byText.get(normalizeText(stored.text)) || [];

    if (candidates.length === 0) {
      bump('no_text_match');
      misses.push({ year: stored.year, text: normalizeText(stored.text) });
      continue;
    }

    // keep only candidates whose options fully line up with this doc
    const passing = [];
    let firstReason = null;
    for (const c of candidates) {
      const r = evaluate(stored, c);
      if (r.reason) firstReason = firstReason || r.reason;
      else passing.push({ record: c, correctIndex: r.correctIndex });
    }
    if (passing.length === 0) {
      bump(firstReason || 'option_text_mismatch');
      continue;
    }

    // duplicates must agree on the answer, or we refuse to guess
    const distinct = new Set(passing.map((p) => p.correctIndex));
    if (distinct.size > 1) {
      bump('conflicting_answers');
      continue;
    }

    bump('matched');
    const correctIndex = passing[0].correctIndex;

    // would the old year-strict match have found this?
    if (passing.some((p) => p.record.examYear === stored.year)) strictMatched++;

    const years = new Set(passing.map((p) => p.record.examYear).filter(Number.isInteger));
    const trueYear = years.size === 1 ? [...years][0] : null;
    if (trueYear === null) {
      yearUnknowable++;
    } else if (trueYear !== stored.year) {
      yearMismatch++;
      const k = `${stored.year} -> ${trueYear}`;
      yearShifts.set(k, (yearShifts.get(k) || 0) + 1);
    }

    // prefer a candidate that carries an explanation
    const best = passing.find((p) => p.record.explanationHtml) || passing[0];
    updates.push({
      id: doc.id,
      correctIndex,
      explanation: htmlToText(best.record.explanationHtml || ''),
      sourceId: best.record.sourceId,
      trueYear,
      storedYear: stored.year,
      hasImage: Boolean(best.record.hasImage),
    });
  }

  const total = qSnap.size;
  const pct = (n) => `${((n / total) * 100).toFixed(1)}%`;
  const matched = updates.length;

  console.log(`\n-- coverage --`);
  console.log(`matched:              ${matched}  (${pct(matched)})`);
  console.log(`  with explanation:   ${updates.filter((u) => u.explanation).length}`);
  console.log(`  with image:         ${updates.filter((u) => u.hasImage).length}`);
  console.log(`  recovered by ignoring year: ${matched - strictMatched}`);

  console.log(`\n-- rejections --`);
  for (const [r, n] of Object.entries(reasons).filter(([r]) => r !== 'matched').sort((a, b) => b[1] - a[1])) {
    console.log(`${r.padEnd(22)}${String(n).padStart(5)}  (${pct(n)})`);
  }

  console.log(`\n-- stored year integrity (matched questions only) --`);
  console.log(`year correct:         ${matched - yearMismatch - yearUnknowable}`);
  console.log(`year WRONG:           ${yearMismatch}  (${pct(yearMismatch)} of all questions)`);
  console.log(`year unknowable:      ${yearUnknowable}  (same text in multiple years)`);
  if (yearShifts.size) {
    console.log(`\nwrong-year distribution (stored -> actual):`);
    [...yearShifts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 25)
      .forEach(([k, n]) => console.log(`  ${k.padEnd(18)} ${n}`));
  }

  // a text miss is either "we never scraped it" or "our stored text is wrong".
  // trigram similarity against the scrape separates the two, which decides
  // whether stored text also needs re-scraping
  if (misses.length) {
    const tri = (s) => {
      const set = new Set();
      for (let i = 0; i < s.length - 2; i++) set.add(s.slice(i, i + 3));
      return set;
    };
    const scrapedTexts = [...byText.keys()];
    const scrapedTri = scrapedTexts.map(tri);
    const inverted = new Map();
    scrapedTri.forEach((set, idx) => {
      for (const g of set) {
        if (!inverted.has(g)) inverted.set(g, []);
        inverted.get(g).push(idx);
      }
    });

    let nearMiss = 0;
    const nearExamples = [];
    for (const m of misses) {
      const mt = tri(m.text);
      const counts = new Map();
      for (const g of mt) for (const idx of inverted.get(g) || []) {
        counts.set(idx, (counts.get(idx) || 0) + 1);
      }
      let best = null;
      for (const [idx, shared] of counts) {
        const sim = shared / (mt.size + scrapedTri[idx].size - shared);
        if (!best || sim > best.sim) best = { idx, sim };
      }
      if (best && best.sim >= 0.85) {
        nearMiss++;
        if (nearExamples.length < 6) {
          nearExamples.push({ stored: m.text, source: scrapedTexts[best.idx], sim: best.sim });
        }
      }
    }

    console.log(`\n-- text-miss analysis (${misses.length} misses) --`);
    console.log(`near-identical match in scrape (>=0.85): ${nearMiss}  (${pct(nearMiss)})`);
    console.log(`  -> stored text likely corrupt/edited, question IS on the site`);
    console.log(`no close match at all:                   ${misses.length - nearMiss}`);
    console.log(`  -> genuinely not scraped (site lacks it, or year not stocked)`);

    if (nearExamples.length) {
      console.log(`\nnear-miss examples (stored vs source):`);
      nearExamples.forEach((e, i) => {
        console.log(`  ${i + 1}. sim=${e.sim.toFixed(3)}`);
        console.log(`     stored: ${e.stored.slice(0, 130)}`);
        console.log(`     source: ${e.source.slice(0, 130)}`);
      });
    }
    console.log(`\nno_text_match examples:`);
    misses.slice(0, 6).forEach((s) => console.log(`  [${s.year}] ${s.text.slice(0, 110)}`));
  }

  if (!APPLY) {
    console.log(`\ndry run — nothing written.`);
    console.log(`  --apply             backfill correctIndex / explanation / sourceId / hasAnswer`);
    console.log(`  --apply --fix-years also correct the ${yearMismatch} wrong stored years`);
    return;
  }

  console.log(`\napplying ${matched} updates${FIX_YEARS ? ' (including year fixes)' : ''}...`);
  for (let i = 0; i < updates.length; i += BATCH_SIZE) {
    const chunk = updates.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const u of chunk) {
      const data = {
        correctIndex: u.correctIndex,
        explanation: u.explanation,
        sourceId: u.sourceId,
        hasAnswer: true,
      };
      if (FIX_YEARS && u.trueYear !== null && u.trueYear !== u.storedYear) {
        data.year = u.trueYear;
      }
      batch.update(db.collection('questions').doc(u.id), data);
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
