#!/usr/bin/env node
/**
 * Audits past questions against the rules from the 15 Oct 2026 review
 * (`question_rules.js`): broken or stray LaTeX, duplicate options, lost
 * negative powers, diagrams that are missing, tables flattened into text,
 * missing explanations, duplicates within a paper, and the same question
 * in two years.
 *
 *   node content_audit.js --cache            # from tools/site/.cache/data.json: no reads
 *   node content_audit.js                    # from Firestore: ~4,500 reads
 *   node content_audit.js --cache --json     # machine-readable
 *   node content_audit.js --cache --list=duplicate-options
 *   node content_audit.js --cache --strict   # exit 1 on any level-A finding
 *   node content_audit.js --cache --publish  # …and write the summary to _meta/contentAudit (one write)
 *
 * Read-only. Level A changes what a question means (a student can be
 * marked wrong for the right answer); level B is presentation.
 */
const fs = require("fs");
const path = require("path");
const R = require("./question_rules");

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v ?? true];
  }),
);
const CACHE = path.join(__dirname, "..", "site", ".cache", "data.json");

async function load() {
  if (args.cache) {
    const d = JSON.parse(fs.readFileSync(CACHE, "utf8"));
    return { subjects: d.subjects, questions: d.questions };
  }
  const { initAdmin } = require("./credential");
  const db = initAdmin().firestore();
  const [subjects, questions] = await Promise.all([
    db.collection("subjects").get(),
    db
      .collection("questions")
      .where("source", "==", "waec")
      .where("hasAnswer", "==", true)
      .select("text", "options", "correctIndex", "explanation", "year", "subjectId", "topicId", "imageId")
      .get(),
  ]);
  return {
    subjects: subjects.docs.map((d) => ({ id: d.id, name: d.data().name })),
    questions: questions.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
}

async function main() {
  const { subjects, questions } = await load();
  const name = Object.fromEntries(subjects.map((s) => [s.id, s.name]));
  const findings = [];
  for (const q of questions) {
    for (const f of R.checkQuestion(q)) findings.push({ id: q.id, subject: name[q.subjectId], year: q.year, ...f });
  }
  const corpus = R.checkCorpus(questions);

  const byRule = {};
  for (const f of findings) {
    byRule[f.rule] ??= { level: f.level, questions: new Set() };
    byRule[f.rule].questions.add(f.id);
  }
  const summary = Object.fromEntries(
    Object.entries(byRule)
      .sort((a, b) => a[1].level.localeCompare(b[1].level) || b[1].questions.size - a[1].questions.size)
      .map(([rule, v]) => [rule, { level: v.level, count: v.questions.size }]),
  );
  summary["duplicate-in-paper"] = { level: "A", count: corpus.exact.length };
  summary["near-duplicate-in-paper"] = { level: "B", count: corpus.near.length };
  summary["same-question-two-years"] = { level: "B", count: corpus.repeats.length };
  const oversized = corpus.paperSizes.filter(([, n]) => n > 50 || n < 35);

  if (args.json) {
    console.log(JSON.stringify({ total: questions.length, summary, findings, corpus, oversized }, null, 1));
  } else {
    console.log(`${questions.length} past questions\n`);
    for (const [rule, { level, count }] of Object.entries(summary)) {
      console.log(`  ${level}  ${String(count).padStart(5)}  ${rule}`);
    }
    if (oversized.length) {
      console.log(`\nPapers outside 35-50 questions: ${oversized.map(([k, n]) => `${name[k.split("|")[0]]} ${k.split("|")[1]} (${n})`).join(", ")}`);
    }
    if (args.list) {
      const rule = String(args.list);
      console.log(`\n${rule}:`);
      if (rule === "duplicate-in-paper") corpus.exact.forEach((ids) => console.log("  " + ids.join(" = ")));
      else if (rule === "near-duplicate-in-paper") corpus.near.forEach((ids) => console.log("  " + ids.join(" ~ ")));
      else if (rule === "same-question-two-years") corpus.repeats.forEach((g) => console.log("  " + g.join(" = ")));
      else for (const f of findings.filter((x) => x.rule === rule)) console.log(`  ${f.subject} ${f.year} ${f.id}  ${f.detail}`);
    }
  }
  if (args.publish) {
    // One write, read by the studio's Content quality panel (reviewers).
    const { initAdmin } = require("./credential");
    const admin = require("firebase-admin").apps.length ? require("firebase-admin") : initAdmin();
    await admin.firestore().doc("_meta/contentAudit").set({
      at: admin.firestore.FieldValue.serverTimestamp(),
      total: questions.length,
      rules: summary,
    });
    console.log("\nPublished to _meta/contentAudit.");
  }
  const levelA = Object.values(summary).some((v) => v.level === "A" && v.count > 0);
  process.exit(args.strict && levelA ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
