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
const REPORTS = path.join(__dirname, "reports");
const { slugify } = require("../site/render");
// The site address, from the app (kSiteOrigin), for the links in the CSV.
const siteOrigin = () =>
  /kSiteOrigin\s*=\s*'([^']+)'/.exec(fs.readFileSync(path.join(__dirname, "..", "..", "lib", "core", "config", "site_config.dart"), "utf8"))[1];
/** Suspects first, then meaning, then presentation (Plan v2 §2.4.2). */
const LEVEL_RANK = { S: 0, A: 1, B: 2 };
const byLevel = (a, b) => (LEVEL_RANK[a] ?? 3) - (LEVEL_RANK[b] ?? 3);
const csvCell = (v) => (/[",\n]/.test(String(v ?? "")) ? `"${String(v).replace(/"/g, '""')}"` : String(v ?? ""));

async function load() {
  if (args.cache) {
    const d = JSON.parse(fs.readFileSync(CACHE, "utf8"));
    return { subjects: d.subjects, questions: d.questions, dataAt: d.readAt ? new Date(d.readAt) : null };
  }
  const { initAdmin } = require("./credential");
  const db = initAdmin().firestore();
  const [subjects, questions] = await Promise.all([
    db.collection("subjects").get(),
    db
      .collection("questions")
      .where("source", "==", "waec")
      .where("hasAnswer", "==", true)
      .select("text", "options", "correctIndex", "explanation", "year", "subjectId", "topicId", "imageId", "auditDismissed")
      .get(),
  ]);
  return {
    dataAt: new Date(),
    subjects: subjects.docs.map((d) => ({ id: d.id, name: d.data().name })),
    questions: questions.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
}

async function main() {
  const { subjects, questions, dataAt } = await load();
  const name = Object.fromEntries(subjects.map((s) => [s.id, s.name]));
  const findings = [];
  for (const q of questions) {
    // A reviewer's "Mark checked" in the studio: that rule, on that
    // question, was looked at and is not a problem.
    const dismissed = new Set(Array.isArray(q.auditDismissed) ? q.auditDismissed : []);
    for (const f of R.checkQuestion(q)) {
      if (!dismissed.has(f.rule)) findings.push({ id: q.id, subject: name[q.subjectId], year: q.year, ...f });
    }
  }
  const corpus = R.checkCorpus(questions);

  const byRule = {};
  for (const f of findings) {
    byRule[f.rule] ??= { level: f.level, questions: new Set() };
    byRule[f.rule].questions.add(f.id);
  }
  const summary = Object.fromEntries(
    Object.entries(byRule)
      .sort((a, b) => byLevel(a[1].level, b[1].level) || b[1].questions.size - a[1].questions.size)
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
  // The questions a reviewer should open first: suspects, then level A,
  // newest papers first. Capped so the summary stays one small document.
  const suspects = findings
    .filter((f) => f.level === "S" || f.level === "A")
    .sort((a, b) => byLevel(a.level, b.level) || (b.year ?? 0) - (a.year ?? 0))
    .slice(0, 100)
    .map((f) => ({ id: f.id, rule: f.rule, level: f.level, subject: f.subject ?? "", year: f.year ?? null, detail: String(f.detail ?? "").slice(0, 160) }));

  if (args.csv) {
    fs.mkdirSync(REPORTS, { recursive: true });
    const origin = siteOrigin();
    const url = (f) => `${origin}/past-questions/waec/${slugify(f.subject ?? "")}/${f.year}/${f.id.slice(0, 10)}/`;
    const rows = [["id", "url", "subject", "year", "flag", "level", "detail"]];
    for (const f of [...findings].sort((a, b) => byLevel(a.level, b.level) || a.rule.localeCompare(b.rule))) {
      rows.push([f.id, url(f), f.subject, f.year, f.rule, f.level, f.detail]);
    }
    fs.writeFileSync(path.join(REPORTS, "question_flags.csv"), rows.map((r) => r.map(csvCell).join(",")).join("\n") + "\n");
    const byPaper = new Map();
    for (const q of questions) {
      const k = `${q.subjectId}|${q.year}`;
      if (!byPaper.has(k)) byPaper.set(k, []);
      byPaper.get(k).push(q.id);
    }
    const years = [["subject", "year", "count", "ids"]];
    for (const [k, n] of oversized) years.push([name[k.split("|")[0]], k.split("|")[1], n, byPaper.get(k).join(" ")]);
    fs.writeFileSync(path.join(REPORTS, "year_counts.csv"), years.map((r) => r.map(csvCell).join(",")).join("\n") + "\n");
    console.log(`\nWrote reports/question_flags.csv (${findings.length} rows) and reports/year_counts.csv (${oversized.length} papers).`);
  }

  if (args.publish) {
    // One write, read by the studio's Content quality panel (reviewers).
    const { initAdmin } = require("./credential");
    const admin = require("firebase-admin").apps.length ? require("firebase-admin") : initAdmin();
    // Every rule's question ids, so the studio can open the questions
    // behind a count (capped per rule; ~1,000 findings is ~30 KB).
    const byRule = {};
    for (const f of findings) (byRule[f.rule] ??= []).length < 1000 && byRule[f.rule].push(f.id);
    byRule["duplicate-in-paper"] = corpus.exact.flat().slice(0, 1000);
    byRule["near-duplicate-in-paper"] = corpus.near.flat().slice(0, 1000);
    byRule["same-question-two-years"] = corpus.repeats.flat().map((s) => String(s).split(":").pop()).slice(0, 1000);
    for (const k of Object.keys(byRule)) byRule[k] = [...new Set(byRule[k])];
    await admin.firestore().doc("_meta/contentAudit").set({
      at: admin.firestore.FieldValue.serverTimestamp(),
      // When the questions were read: the studio treats a question saved
      // after this as fixed, not still flagged, until the next audit.
      dataAt: dataAt ? admin.firestore.Timestamp.fromDate(dataAt) : null,
      total: questions.length,
      rules: summary,
      suspects,
      byRule,
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
