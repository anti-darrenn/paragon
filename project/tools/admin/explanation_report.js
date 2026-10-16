#!/usr/bin/env node
/**
 * Where each past question's worked answer came from, and which are
 * missing: the content team's to-do list (Plan v2 §2.2). No Firestore
 * reads: it joins the static site's cache (tools/site/.cache/data.json,
 * what is live) with the scraped source kept in the repo
 * (tools/scraper/data/answers_<subject>.json, myschool.ng).
 *
 *   node explanation_report.js            # summary per subject and year
 *   node explanation_report.js --csv      # …and reports/explanations.csv
 *
 * `explanationOrigin` per question:
 *   none      no explanation
 *   imported  the source's explanation, perhaps with the mechanical fixes
 *   rewritten no longer reads like the source: rewritten here, or heavily
 *             corrected. Not proof of original wording; check before
 *             counting it as Paragon's own (Plan v2 §2.1).
 *   unknown   the question could not be matched to a source record
 * Read-only.
 */
const fs = require("fs");
const path = require("path");
const R = require("./question_rules");

const args = new Set(process.argv.slice(2));
const CACHE = path.join(__dirname, "..", "site", ".cache", "data.json");
const SOURCE = path.join(__dirname, "..", "scraper", "data");
const REPORTS = path.join(__dirname, "reports");

/** HTML from the scrape as the plain text the importer stored. */
const fromHtml = (html) =>
  String(html ?? "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;|&rsquo;/g, "'");

/** A comparison key: letters and digits only, maths commands dropped. */
const key = (s) =>
  String(s ?? "")
    .toLowerCase()
    .replace(/\\[a-z]+/g, " ")
    .replace(/[^a-z0-9]+/g, "");

function trigrams(s) {
  const out = new Set();
  for (let i = 0; i + 3 <= s.length; i++) out.add(s.slice(i, i + 3));
  return out;
}
function similarity(a, b) {
  const x = trigrams(a);
  const y = trigrams(b);
  let inter = 0;
  for (const t of x) if (y.has(t)) inter++;
  return inter / (x.size + y.size - inter || 1);
}

/** One row per past question. `source` is {subjectSlug: [records]}. */
function classify(questions, subjectName, topicName, source) {
  const index = new Map();
  const byPaper = new Map();
  for (const [slug, records] of Object.entries(source)) {
    for (const r of records) {
      const stem = key(fromHtml(r.questionHtml));
      index.set(`${slug}|${r.year}|${stem}`, r);
      const paper = `${slug}|${r.year}`;
      if (!byPaper.has(paper)) byPaper.set(paper, []);
      byPaper.get(paper).push([stem, r]);
    }
  }
  const slug = (name) => String(name ?? "").toLowerCase().replace(/\s+/g, "-");
  /** The source record for a question: the same stem, or failing that
   *  (a fix changed a few characters) the closest stem in the same paper. */
  const recordFor = (subject, q) => {
    const stem = key(q.text);
    const exact = index.get(`${slug(subject)}|${q.year}|${stem}`);
    if (exact) return exact;
    let best = null;
    let score = 0.8;
    for (const [theirs, r] of byPaper.get(`${slug(subject)}|${q.year}`) || []) {
      const s = similarity(stem, theirs);
      if (s >= score) [best, score] = [r, s];
    }
    return best;
  };
  return questions.map((q) => {
    const explanation = String(q.explanation ?? "").trim();
    const subject = subjectName[q.subjectId] ?? "";
    const record = recordFor(subject, q);
    let origin;
    if (!explanation) origin = "none";
    else if (!record) origin = "unknown";
    else {
      const theirs = key(fromHtml(record.explanationHtml));
      // The mechanical fixes (units, powers of ten, LaTeX) change a few
      // characters, not the wording, so a copy stays well above 0.6.
      origin = theirs && similarity(key(explanation), theirs) >= 0.6 ? "imported" : "rewritten";
    }
    const mismatch = R.explanationMismatch(q);
    return {
      id: q.id,
      subject,
      year: q.year,
      topic: topicName[q.topicId] ?? "",
      hasExplanation: Boolean(explanation),
      explanationOrigin: origin,
      explanationLength: explanation.length,
      explanationHasLatex: R.splitMath(explanation).some((p) => p.math),
      explanationLooksTemplated: Boolean(mismatch),
      detail: mismatch ?? "",
    };
  });
}

/** {subject → {year → {total, none, imported, rewritten, unknown}}}. */
function summarise(rows) {
  const out = {};
  for (const r of rows) {
    const y = ((out[r.subject] ??= {})[r.year] ??= { total: 0, none: 0, imported: 0, rewritten: 0, unknown: 0 });
    y.total++;
    y[r.explanationOrigin]++;
  }
  return out;
}

function loadSource() {
  const out = {};
  for (const f of fs.readdirSync(SOURCE)) {
    const m = /^answers_([a-z-]+)\.json$/.exec(f);
    if (m) out[m[1]] = JSON.parse(fs.readFileSync(path.join(SOURCE, f), "utf8"));
  }
  return out;
}

function main() {
  const data = JSON.parse(fs.readFileSync(CACHE, "utf8"));
  const subjectName = Object.fromEntries(data.subjects.map((s) => [s.id, s.name]));
  const topicName = Object.fromEntries((data.topics || []).map((t) => [t.id, t.name]));
  const rows = classify(data.questions, subjectName, topicName, loadSource());
  const summary = summarise(rows);

  const pct = (n, d) => `${Math.round((100 * n) / (d || 1))}%`.padStart(4);
  console.log(`${rows.length} past questions (cache read ${data.readAt ?? "?"})\n`);
  console.log("subject               year  total  none  imported  rewritten  unknown");
  for (const [subject, years] of Object.entries(summary).sort()) {
    const all = { total: 0, none: 0, imported: 0, rewritten: 0, unknown: 0 };
    for (const [year, c] of Object.entries(years).sort()) {
      for (const k of Object.keys(all)) all[k] += c[k];
      console.log(
        `${subject.padEnd(20)}  ${year}  ${String(c.total).padStart(5)}  ${pct(c.none, c.total)}  ${pct(c.imported, c.total)}      ${pct(c.rewritten, c.total)}      ${pct(c.unknown, c.total)}`,
      );
    }
    console.log(
      `${(subject + ", all").padEnd(20)}  ----  ${String(all.total).padStart(5)}  ${pct(all.none, all.total)}  ${pct(all.imported, all.total)}      ${pct(all.rewritten, all.total)}      ${pct(all.unknown, all.total)}\n`,
    );
  }
  const flagged = rows.filter((r) => r.explanationLooksTemplated);
  console.log(`Explanations that round to a different count than the stem asks: ${flagged.length}`);
  for (const r of flagged) console.log(`  ${r.subject} ${r.year} ${r.id}  ${r.detail}`);

  if (args.has("--csv")) {
    fs.mkdirSync(REPORTS, { recursive: true });
    const cols = ["id", "subject", "year", "topic", "hasExplanation", "explanationOrigin", "explanationLength", "explanationHasLatex", "explanationLooksTemplated"];
    const cell = (v) => (/[",\n]/.test(String(v)) ? `"${String(v).replace(/"/g, '""')}"` : String(v));
    const csv = [cols.join(","), ...rows.map((r) => cols.map((c) => cell(r[c])).join(","))].join("\n") + "\n";
    fs.writeFileSync(path.join(REPORTS, "explanations.csv"), csv);
    console.log(`\nWrote reports/explanations.csv (${rows.length} rows).`);
  }
}

if (require.main === module) main();

module.exports = { classify, summarise, fromHtml };
