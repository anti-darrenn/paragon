// Shared helpers for AI-generated WAEC-style question generation.
// Every generator computes its answer in code from the SAME variables used to render
// the question text - never mutate a value after rendering (that caused a real bug).

const fs = require('fs');
const path = require('path');

const OUT_DIR = path.join(__dirname, '..', 'data');

function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr) { return arr[randInt(0, arr.length - 1)]; }
function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) { const j = randInt(0, i); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
// k distinct elements
function sample(arr, k) { return shuffle(arr).slice(0, k); }
function nonZero(min, max) { let v = 0; while (v === 0) v = randInt(min, max); return v; }

function gcd(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) { [a, b] = [b, a % b]; } return a; }
function lcm(a, b) { return Math.abs(a * b) / gcd(a, b); }

// exact fraction helpers -------------------------------------------------
function frac(n, d) {
  if (d === 0) throw new Error('zero denominator');
  let s = d < 0 ? -1 : 1;
  n *= s; d *= s;
  const g = gcd(n, d) || 1;
  return { n: n / g, d: d / g };
}
function fracEq(a, b) { return a.n === b.n && a.d === b.d; }
function fracAdd(a, b) { return frac(a.n * b.d + b.n * a.d, a.d * b.d); }
function fracMul(a, b) { return frac(a.n * b.n, a.d * b.d); }
function fracTex(f) {
  if (f.d === 1) return String(f.n);
  if (f.n < 0) return `-\\frac{${-f.n}}{${f.d}}`;
  return `\\frac{${f.n}}{${f.d}}`;
}
// fraction rendered as a standalone inline-math option
function fracOpt(f) { return `\\(${fracTex(f)}\\)`; }

// number formatting ------------------------------------------------------
function round(x, dp) { const m = Math.pow(10, dp); return Math.round((x + Number.EPSILON) * m) / m; }
// trims trailing zeros: 12.50 -> "12.5", 12.00 -> "12"
function fmtNum(x, dp = 2) {
  if (!isFinite(x)) return 'NaN';
  const r = round(x, dp);
  if (Number.isInteger(r)) return String(r);
  return String(parseFloat(r.toFixed(dp)));
}
function fixed(x, dp) { return Number(x).toFixed(dp); }
function money(x, dp = 2) { return `N${Number(x).toFixed(dp)}`; }

// signed term helpers for algebra rendering ------------------------------
function signed(n) { return n < 0 ? `- ${Math.abs(n)}` : `+ ${n}`; }
// coefficient in front of a variable: 1x -> x, -1x -> -x
function coef(n, v) {
  if (n === 1) return v;
  if (n === -1) return `-${v}`;
  return `${n}${v}`;
}
// builds "3x^2 - 4x + 5" from [[coef, power]...] in x
function poly(terms, v = 'x') {
  let out = '';
  let first = true;
  for (const [c, p] of terms) {
    if (c === 0) continue;
    const mag = Math.abs(c);
    let body;
    if (p === 0) body = String(mag);
    else if (p === 1) body = mag === 1 ? v : `${mag}${v}`;
    else body = mag === 1 ? `${v}^{${p}}` : `${mag}${v}^{${p}}`;
    if (first) { out += (c < 0 ? '-' : '') + body; first = false; }
    else out += (c < 0 ? ' - ' : ' + ') + body;
  }
  return out === '' ? '0' : out;
}

// option building --------------------------------------------------------
// Dedups on the FORMATTED string so two distinct values that render the same
// can never both appear. Returns null when 4 unique options can't be built.
function buildOptions(correctValue, distractorValues, fmt) {
  const correctStr = fmt(correctValue);
  if (correctStr == null || correctStr.includes('NaN') || correctStr.includes('undefined')) return null;
  const seen = new Set([correctStr]);
  const wrongs = [];
  for (const v of distractorValues) {
    if (wrongs.length >= 3) break;
    if (v === null || v === undefined) continue;
    if (typeof v === 'number' && !isFinite(v)) continue;
    let s;
    try { s = fmt(v); } catch (e) { continue; }
    if (s == null || s.includes('NaN') || s.includes('undefined')) continue;
    if (seen.has(s)) continue;
    seen.add(s);
    wrongs.push(s);
  }
  if (wrongs.length < 3) return null;
  const all = shuffle([correctStr, ...wrongs.slice(0, 3)]);
  return { options: all, correctIndex: all.indexOf(correctStr) };
}

// numeric distractor spread around a correct number
function numericDistractors(correct, opts = {}) {
  const { scale = null, allowNegative = false } = opts;
  const s = scale != null ? scale : Math.max(1, Math.abs(correct) * 0.15);
  const cands = [
    correct + s, correct - s, correct + 2 * s, correct - 2 * s,
    correct * 2, correct / 2, correct + 1, correct - 1, correct + 3, correct - 3,
  ];
  return cands.filter(c => isFinite(c) && (allowNegative || c > 0));
}

// multiple-choice over a fixed set of text answers
function textOptions(correct, others) {
  const all = shuffle([correct, ...others.slice(0, 3)]);
  if (new Set(all).size !== 4) return null;
  return { options: all, correctIndex: all.indexOf(correct) };
}

// question assembly ------------------------------------------------------
function slugify(s) {
  return s.toLowerCase()
    .replace(/['’]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// Builds and runs a topic's generators until `count` unique questions exist.
function buildTopic({ subjectId, unitId, topicId, subjectSlug, topicName, generators, count = 300 }) {
  const questions = [];
  const seen = new Set();
  let attempts = 0;
  const maxAttempts = count * 200;

  while (questions.length < count && attempts < maxAttempts) {
    attempts++;
    const gen = pick(generators);
    let q;
    try { q = gen(); } catch (e) { continue; }
    if (!q) continue;
    if (!q.text || !q.options || !q.explanation) continue;
    if (q.options.length !== 4) continue;
    if (new Set(q.options).size !== 4) continue;
    if (q.correctIndex < 0 || q.correctIndex > 3) continue;
    if (seen.has(q.text)) continue;
    // hard content guards
    const blob = q.text + ' ' + q.explanation + ' ' + q.options.join(' ');
    if (blob.includes('NaN') || blob.includes('undefined') || blob.includes('Infinity')) continue;
    if (blob.includes('\\(\\(')) continue;
    if (blob.includes('$')) continue;
    seen.add(q.text);
    questions.push({
      text: q.text,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
      subjectId, unitId, topicId,
      source: 'drill',
      origin: 'ai_generated',
      hasAnswer: true,
      year: null,
    });
  }

  const file = path.join(OUT_DIR, `generated_${subjectSlug}_${slugify(topicName)}.json`);
  fs.writeFileSync(file, JSON.stringify(questions, null, 2));
  return { topicName, count: questions.length, file, attempts };
}

module.exports = {
  OUT_DIR, randInt, pick, shuffle, sample, nonZero, gcd, lcm,
  frac, fracEq, fracAdd, fracMul, fracTex, fracOpt,
  round, fmtNum, fixed, money, signed, coef, poly,
  buildOptions, numericDistractors, textOptions, slugify, buildTopic,
};
