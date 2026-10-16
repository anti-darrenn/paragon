#!/usr/bin/env node
/**
 * Bulk-imports questions from a JSON file, after checking every one
 * (PLAN.md P7.6.3). Questions are Admin-SDK-only (the rules keep stems,
 * options and topics server-written), so this is the import path, not
 * the studio.
 *
 *   node import_questions.js --file=new.json                 # check only
 *   node import_questions.js --file=new.json --check-existing # + duplicates already in Firestore
 *   node import_questions.js --file=new.json --commit         # write
 *
 * The file is an array of:
 *   { subjectId, topicId, text, options: [..], correctIndex,
 *     explanation?, source: "waec" | "drill", year?, origin? }
 *
 * Checks (all must pass before anything is written):
 *   - 4 or 5 options, none empty, no two the same (ignoring case/space);
 *   - exactly one right answer: correctIndex inside the options;
 *   - maths that parses (KaTeX, throwOnError), in stem, options and
 *     explanation;
 *   - a past question (`source: "waec"`) has a plausible year;
 *   - no duplicate stems in the file (normalised text), and with
 *     --check-existing none already in the same topic (reads that topic's
 *     questions once: ~300 reads a topic).
 *
 * Writes use Firestore auto-ids (drill rotation depends on it) and set
 * `hasAnswer: true` (or drill filters them out) and `origin` (default
 * "authored"). It counts against Spark's 20,000 writes a day: import in
 * chunks and run `jobs.js --job=counts` afterwards.
 */
const fs = require("fs");
const { initAdmin } = require("./credential");
const { mathProblems } = require("./content_lint");
const { checkQuestion } = require("./question_rules");

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, "").split("=");
    return [k, v.length ? v.join("=") : true];
  }),
);

const norm = (s) => String(s || "").toLowerCase().replace(/\s+/g, " ").trim();

/** Pure: every problem with one question, as strings. */
function problemsWith(q, { thisYear = new Date().getFullYear() } = {}) {
  const out = [];
  for (const f of ["subjectId", "topicId", "text"]) {
    if (typeof q[f] !== "string" || !q[f].trim()) out.push(`${f} is missing`);
  }
  const opts = Array.isArray(q.options) ? q.options : [];
  if (opts.length < 4 || opts.length > 5) out.push(`${opts.length} options (need 4 or 5)`);
  if (opts.some((o) => typeof o !== "string" || !o.trim())) out.push("an option is empty");
  const seen = new Set();
  for (const o of opts) {
    if (seen.has(norm(o))) out.push(`option "${o}" appears twice`);
    seen.add(norm(o));
  }
  if (!Number.isInteger(q.correctIndex) || q.correctIndex < 0 || q.correctIndex >= opts.length) {
    out.push("correctIndex is not one of the options");
  }
  if (!["waec", "drill"].includes(q.source)) out.push('source must be "waec" or "drill"');
  if (q.source === "waec" && !(Number.isInteger(q.year) && q.year >= 1988 && q.year <= thisYear)) {
    out.push("a past question needs its exam year");
  }
  for (const [where, text] of [["stem", q.text], ["explanation", q.explanation], ...opts.map((o, i) => [`option ${i + 1}`, o])]) {
    for (const p of mathProblems(text || "")) out.push(`${where}: ${p}`);
  }
  // The audit's meaning-changing rules (question_rules.js), so an import
  // cannot bring back what the 15 Oct 2026 clean-up removed. Run
  // fix_questions' rules over a file first to clear the mechanical ones.
  for (const f of checkQuestion(q)) {
    if (["lost-negative-power", "diagram-missing", "raw-latex-question", "raw-latex-options"].includes(f.rule)) {
      out.push(`${f.rule}${f.detail ? `: ${f.detail}` : ""}`);
    }
  }
  return out;
}

/** Pure: indexes of questions whose stem repeats an earlier one in the list. */
function duplicateStems(list, existing = new Set()) {
  const seen = new Set(existing);
  const dups = [];
  list.forEach((q, i) => {
    const key = `${q.topicId}|${norm(q.text)}`;
    if (seen.has(key)) dups.push(i);
    seen.add(key);
  });
  return dups;
}

async function main() {
  if (!args.file) throw new Error("--file is required");
  const list = JSON.parse(fs.readFileSync(args.file, "utf8"));
  if (!Array.isArray(list)) throw new Error("the file must hold an array");

  let bad = 0;
  list.forEach((q, i) => {
    const p = problemsWith(q);
    if (p.length) {
      bad++;
      console.log(`#${i}: ${p.join("; ")}`);
    }
  });

  let existing = new Set();
  let db;
  if (args["check-existing"] || args.commit) {
    db = initAdmin().firestore();
  }
  if (args["check-existing"]) {
    for (const topicId of new Set(list.map((q) => q.topicId))) {
      const snap = await db.collection("questions").where("topicId", "==", topicId).select("text").get();
      for (const d of snap.docs) existing.add(`${topicId}|${norm(d.data().text)}`);
    }
  }
  const dups = duplicateStems(list, existing);
  for (const i of dups) console.log(`#${i}: the same question is already ${existing.size ? "in Firestore or " : ""}earlier in the file`);
  bad += dups.length;

  console.log(`${list.length} questions, ${bad} with problems.`);
  if (bad) process.exit(1);
  if (!args.commit) {
    console.log("All clean. Re-run with --commit to write them.");
    process.exit(0);
  }

  for (let i = 0; i < list.length; i += 400) {
    const batch = db.batch();
    for (const q of list.slice(i, i + 400)) {
      batch.set(db.collection("questions").doc(), {
        subjectId: q.subjectId,
        topicId: q.topicId,
        text: q.text,
        options: q.options,
        correctIndex: q.correctIndex,
        explanation: q.explanation || "",
        source: q.source,
        year: q.source === "waec" ? q.year : null,
        origin: q.origin || "authored",
        hasAnswer: true,
      });
    }
    await batch.commit();
    console.log(`  wrote ${Math.min(i + 400, list.length)}/${list.length}`);
  }
  console.log("Done. Run `node jobs.js --job=counts --apply` to update the counts.");
  process.exit(0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(2);
  });
}

module.exports = { problemsWith, duplicateStems };
