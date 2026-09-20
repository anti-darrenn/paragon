// Shared credentials and daily write budgeting for the seeders.
//
// The project runs on Firestore's free Spark plan: 20,000 document writes and
// 50,000 reads per day. Seeding the generated corpus needs far more than one
// day's allowance, so the seeders spend a budget, stop cleanly, and resume on
// the next run rather than erroring out mid-way with RESOURCE_EXHAUSTED.
//
// Spend is recorded in data/_seed_budget.json so that separate invocations on
// the same day share one allowance. That file is committed, like the
// reclassify progress markers, so CI runs also see it.

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Leave headroom under the 20k/day cap: the app itself writes attempts and
// user docs, and a seeder that spends the very last write starves it.
const DAILY_CAP = Number(process.env.SEED_DAILY_WRITE_CAP || 17000);
const STATE = path.join(__dirname, 'data', '_seed_budget.json');

function loadCredential() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT));
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return admin.credential.applicationDefault();
  }
  const local = path.join(__dirname, 'data', 'serviceAccountKey.json');
  if (fs.existsSync(local)) return admin.credential.cert(require(local));
  throw new Error(
    'No credentials. Set FIREBASE_SERVICE_ACCOUNT or GOOGLE_APPLICATION_CREDENTIALS, ' +
    'or place serviceAccountKey.json in tools/scraper/data/.'
  );
}

// Firestore quota resets at midnight US/Pacific, not local midnight.
function quotaDay() {
  const d = new Date(new Date().toLocaleString('en-US', { timeZone: 'America/Los_Angeles' }));
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function read() {
  try {
    const s = JSON.parse(fs.readFileSync(STATE, 'utf8'));
    if (s.day === quotaDay()) return s;
  } catch (e) { /* missing or unreadable - treat as a fresh day */ }
  return { day: quotaDay(), writes: 0 };
}

function remaining() {
  return Math.max(0, DAILY_CAP - read().writes);
}

function spend(n) {
  const s = read();
  s.writes += n;
  fs.writeFileSync(STATE, JSON.stringify(s, null, 2));
  return s.writes;
}

function summary() {
  const s = read();
  return `budget ${s.writes}/${DAILY_CAP} writes used today (${quotaDay()} Pacific), ${remaining()} remaining`;
}

// Counts matching documents using an aggregation query. This bills one read
// per 1000 index entries instead of one per document, which matters: the run
// that exhausted the quota did so largely by fetching whole topics just to
// count them.
async function countWhere(db, collection, field, value) {
  const snap = await db.collection(collection).where(field, '==', value).count().get();
  return snap.data().count;
}

// RESOURCE_EXHAUSTED on Spark means the daily read or write allowance is gone.
// It is an expected outcome here, not a crash, so say so plainly.
function isQuota(e) {
  return /RESOURCE_EXHAUSTED|Quota exceeded/i.test((e && e.message) || String(e));
}

function explain(e) {
  const msg = (e && e.message) || String(e);
  if (/RESOURCE_EXHAUSTED|Quota exceeded/i.test(msg)) {
    return [
      'Firestore daily quota is exhausted (free Spark plan: 20k writes, 50k reads per day).',
      `Local budget tracker says: ${summary()}`,
      'Note reads are capped too, so even a dry run cannot inspect Firestore right now.',
      'The quota resets at midnight US/Pacific. Re-run then - the seeders resume where they stopped.',
    ].join('\n');
  }
  return msg;
}

module.exports = { admin, loadCredential, DAILY_CAP, remaining, spend, summary, quotaDay, countWhere, explain, isQuota };
