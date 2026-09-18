// scrapes correct answers + worked explanations from myschool.ng
// writes data/answers_<subject>.json — never touches firestore
//
// site is a nuxt app now, so the old .question-item selectors in 1_scrape.js
// are dead. real data lives in the __NUXT_DATA__ payload instead.
//
// two passes:
//   1. listing pages — cheap, 5 questions each, gives ids + options + is_correct
//   2. detail pages  — 1 per question, adds the worked explanation
// listing answers are kept as a cross-check against the detail answers

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');

// edit per run, or override: node 4_scrape_answers.js physics
const SUBJECT = process.argv[2] || 'mathematics';

// firestore already holds maths questions back to 1990, so this starts earlier
// than 1_scrape.js's 2006. empty years cost one request and are skipped
const YEAR_START = 1990;
const YEAR_END = 2025;
const DELAY_MS = 800;
const MAX_RETRIES = 4;
const BASE = 'https://myschool.ng/classroom';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36';

const DATA_DIR = path.join(__dirname, 'data');
const OUT_FILE = path.join(DATA_DIR, `answers_${SUBJECT}.json`);
const PROGRESS_FILE = path.join(DATA_DIR, `answers_progress_${SUBJECT}.json`);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// retries with backoff, then throws — an error must never look like "no more pages"
async function fetchHtml(url) {
  let lastErr;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const res = await axios.get(url, {
        headers: { 'User-Agent': UA },
        timeout: 30000,
        validateStatus: (s) => s === 200,
      });
      return res.data;
    } catch (err) {
      lastErr = err;
      const wait = DELAY_MS * Math.pow(2, attempt - 1);
      console.warn(`  retry ${attempt}/${MAX_RETRIES} after ${wait}ms — ${err.message}`);
      await sleep(wait);
    }
  }
  throw new Error(`failed after ${MAX_RETRIES} retries: ${url} — ${lastErr.message}`);
}

function parseNuxt(html) {
  const raw = cheerio.load(html)('#__NUXT_DATA__').html();
  if (!raw) return null;
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : null;
  } catch {
    return null;
  }
}

// nuxt devalue format — object fields hold indices into the flat array,
// leaf entries hold the real primitives
function makeResolver(arr) {
  return function resolve(ref, depth = 0) {
    if (depth > 8) return null;
    if (!Number.isInteger(ref) || ref < 0 || ref >= arr.length) return null;
    const v = arr[ref];
    if (v === null || typeof v !== 'object') return v;
    if (Array.isArray(v)) return v.map((x) => resolve(x, depth + 1));
    const out = {};
    for (const k of Object.keys(v)) out[k] = resolve(v[k], depth + 1);
    return out;
  };
}

// type-check everything — a malformed record is skipped and reported, never guessed at
function extractQuestions(arr) {
  const resolve = makeResolver(arr);
  const found = [];

  arr.forEach((v) => {
    if (!v || typeof v !== 'object' || Array.isArray(v)) return;
    if (!('question' in v) || !('options' in v)) return;

    const sourceId = resolve(v.id);
    const questionHtml = resolve(v.question);
    const rawOptions = resolve(v.options);
    if (!Number.isInteger(sourceId)) return;
    if (typeof questionHtml !== 'string') return;
    if (!Array.isArray(rawOptions) || rawOptions.length === 0) return;

    const options = [];
    for (const o of rawOptions) {
      if (!o || typeof o !== 'object') return;
      if (typeof o.description !== 'string') return;
      if (o.is_correct !== 0 && o.is_correct !== 1) return;
      options.push({
        tag: typeof o.tag === 'string' ? o.tag : null,
        description: o.description,
        isCorrect: o.is_correct === 1,
      });
    }

    const explanationHtml =
      'explanation' in v && typeof resolve(v.explanation) === 'string'
        ? resolve(v.explanation)
        : null;

    // authoritative year — the url's exam_year is NOT trustworthy. asking for a
    // year the site doesn't stock silently returns questions from another year
    const collection = resolve(v.collection);
    const examYear =
      collection && Number.isInteger(collection.exam_year) ? collection.exam_year : null;

    found.push({
      sourceId,
      examYear,
      questionHtml,
      options,
      explanationHtml,
      hasImage: Boolean(resolve(v.image)) || Boolean(resolve(v.answer_image)),
    });
  });

  return found;
}

function loadProgress() {
  if (!fs.existsSync(PROGRESS_FILE)) return { listing: {}, details: {} };
  try {
    const p = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf8'));
    return { listing: p.listing || {}, details: p.details || {} };
  } catch {
    return { listing: {}, details: {} };
  }
}

function saveProgress(progress) {
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress));
}

// pass 1 — enumerate every question id for a year off the listing pages
async function scrapeListingYear(year) {
  const collected = [];
  let page = 1;

  while (true) {
    const url = `${BASE}/${SUBJECT}?exam_type=waec&exam_year=${year}&type=obj&page=${page}`;
    const html = await fetchHtml(url);
    const arr = parseNuxt(html);

    if (!arr) throw new Error(`no __NUXT_DATA__ payload at ${url}`);

    const questions = extractQuestions(arr);
    if (questions.length === 0) break; // genuine end of pages

    // keep only questions the payload itself says belong to this year. a year
    // the site doesn't stock returns another year's questions forever, so an
    // all-foreign page means "no such year" and must stop the loop
    const forYear = questions.filter((q) => q.examYear === year);
    if (forYear.length === 0) {
      if (page === 1) {
        const got = questions[0].examYear;
        console.log(`  ${year}: not stocked (site served ${got}) — skipping`);
      }
      break;
    }

    for (const q of forYear) collected.push({ ...q, year });
    process.stdout.write(`\r  ${year}: page ${page}, ${collected.length} questions`);
    page++;
    await sleep(DELAY_MS);
  }

  if (collected.length) process.stdout.write('\n');
  return collected;
}

async function main() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  const progress = loadProgress();

  console.log(`\n=== pass 1: listing pages (${SUBJECT}) ===`);
  for (let year = YEAR_START; year <= YEAR_END; year++) {
    if (progress.listing[year]) {
      console.log(`  ${year}: cached (${progress.listing[year].length})`);
      continue;
    }
    const questions = await scrapeListingYear(year);
    progress.listing[year] = questions;
    saveProgress(progress);
    await sleep(DELAY_MS);
  }

  const all = Object.values(progress.listing).flat();
  console.log(`\npass 1 done — ${all.length} questions enumerated`);

  console.log(`\n=== pass 2: detail pages (explanations) ===`);
  let done = 0;
  for (const q of all) {
    done++;
    if (progress.details[q.sourceId]) continue;

    const url = `${BASE}/${SUBJECT}/${q.sourceId}?exam_type=waec&exam_year=${q.year}&type=obj`;
    const html = await fetchHtml(url);
    const arr = parseNuxt(html);
    const detail = arr ? extractQuestions(arr).find((d) => d.sourceId === q.sourceId) : null;

    if (detail) {
      progress.details[q.sourceId] = {
        explanationHtml: detail.explanationHtml,
        options: detail.options,
        hasImage: detail.hasImage,
      };
    } else {
      // keep going — listing already gave us the answer, only the explanation is lost
      progress.details[q.sourceId] = { explanationHtml: null, options: null, missing: true };
      console.warn(`\n  no detail payload for ${q.sourceId}`);
    }

    if (done % 25 === 0) saveProgress(progress);
    process.stdout.write(`\r  ${done}/${all.length}`);
    await sleep(DELAY_MS);
  }
  saveProgress(progress);
  process.stdout.write('\n');

  // merge, preferring detail answers but flagging any disagreement with the listing
  const out = all.map((q) => {
    const d = progress.details[q.sourceId] || {};
    const options = d.options || q.options;
    const listingCorrect = q.options.find((o) => o.isCorrect);
    const detailCorrect = (d.options || []).find((o) => o.isCorrect);
    return {
      sourceId: q.sourceId,
      year: q.year,
      subject: SUBJECT,
      questionHtml: q.questionHtml,
      options,
      explanationHtml: d.explanationHtml || null,
      hasImage: Boolean(q.hasImage || d.hasImage),
      // cross-check: listing and detail should name the same correct option
      answerAgrees:
        !detailCorrect || !listingCorrect
          ? null
          : detailCorrect.description === listingCorrect.description,
    };
  });

  fs.writeFileSync(OUT_FILE, JSON.stringify(out, null, 1));

  const withExpl = out.filter((q) => q.explanationHtml).length;
  const disagree = out.filter((q) => q.answerAgrees === false).length;
  const noCorrect = out.filter((q) => !q.options.some((o) => o.isCorrect)).length;

  console.log(`\nwrote ${OUT_FILE}`);
  console.log(`  questions:        ${out.length}`);
  console.log(`  with explanation: ${withExpl}`);
  console.log(`  with image:       ${out.filter((q) => q.hasImage).length}`);
  console.log(`  no correct opt:   ${noCorrect}`);
  console.log(`  answer mismatch:  ${disagree}`);
}

main().catch((err) => {
  console.error(`\nFAILED: ${err.message}`);
  console.error('progress saved — rerun to resume');
  process.exit(1);
});
