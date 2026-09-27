// shared myschool.ng plumbing: polite fetching and the __NUXT_DATA__ payload.
// used by 4_scrape_answers.js and 10_fetch_question_images.js

const axios = require('axios');
const cheerio = require('cheerio');

const BASE = 'https://myschool.ng/classroom';
// question and answer images are stored as bare filenames in the payload,
// served from these folders (seen in the page's own <img src>)
const IMAGE_BASE = 'https://myschool.ng/storage/classroom/';
const ANSWER_IMAGE_BASE = 'https://myschool.ng/storage/classroom_answers/';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36';
const DELAY_MS = 800;
const MAX_RETRIES = 4;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// retries with backoff, then throws — an error must never look like "no more pages"
async function fetchWithRetry(url, responseType) {
  let lastErr;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const res = await axios.get(url, {
        headers: { 'User-Agent': UA },
        timeout: 30000,
        responseType,
        validateStatus: (s) => s === 200,
      });
      return res.data;
    } catch (err) {
      lastErr = err;
      // a 404 will not get better by asking again
      if (err.response && err.response.status === 404) break;
      const wait = DELAY_MS * Math.pow(2, attempt - 1);
      console.warn(`  retry ${attempt}/${MAX_RETRIES} after ${wait}ms — ${err.message}`);
      await sleep(wait);
    }
  }
  throw new Error(`failed: ${url} — ${lastErr.message}`);
}

const fetchHtml = (url) => fetchWithRetry(url, 'text');
const fetchBytes = async (url) => Buffer.from(await fetchWithRetry(url, 'arraybuffer'));

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

// every raw question record in a payload, with a resolver for its fields
function questionRecords(arr) {
  const resolve = makeResolver(arr);
  return arr
    .filter((v) => v && typeof v === 'object' && !Array.isArray(v) && 'question' in v && 'options' in v)
    .map((v) => ({ raw: v, resolve }));
}

module.exports = {
  BASE,
  IMAGE_BASE,
  ANSWER_IMAGE_BASE,
  DELAY_MS,
  sleep,
  fetchHtml,
  fetchBytes,
  parseNuxt,
  makeResolver,
  questionRecords,
};
