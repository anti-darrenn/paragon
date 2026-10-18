#!/usr/bin/env node
/**
 * Asserts that every surface showing a question count will agree:
 * each subject's `questionCount`, `pastQuestionCount` and
 * `practiceQuestionCount` (the welcome ticker) must equal the sum over its
 * topics (the course page), and each topic's total must be at least its
 * past + practice split.
 *
 *   node check_counts.js
 *
 * Read-only: one read per subject and per topic, no aggregates. Exits 1 on
 * any mismatch — the fix is `node jobs.js --job=counts --apply`.
 */
const { initAdmin } = require("./credential");

const FIELDS = ["questionCount", "pastQuestionCount", "practiceQuestionCount", "pendingCount"];

/** Pure: the mismatches for one subject and its topics. */
function mismatches(subject, topics) {
  const out = [];
  for (const f of FIELDS) {
    const sum = topics.reduce((n, t) => n + (t[f] || 0), 0);
    if ((subject[f] || 0) !== sum) {
      out.push(`${subject.name}: ${f} is ${subject[f] || 0}, its topics sum to ${sum}`);
    }
  }
  for (const t of topics) {
    const split = (t.pastQuestionCount || 0) + (t.practiceQuestionCount || 0);
    if ((t.questionCount || 0) < split) {
      out.push(`${subject.name} / ${t.name}: questionCount ${t.questionCount || 0} < past + practice ${split}`);
    }
  }
  return out;
}

async function main() {
  const db = initAdmin().firestore();
  const [subjects, topics] = await Promise.all([
    db.collection("subjects").get(),
    db.collection("topics").get(),
  ]);
  const bySubject = new Map();
  for (const t of topics.docs) {
    const d = t.data();
    if (!bySubject.has(d.subjectId)) bySubject.set(d.subjectId, []);
    bySubject.get(d.subjectId).push(d);
  }
  const problems = subjects.docs.flatMap((s) =>
    mismatches(s.data(), bySubject.get(s.id) || []),
  );
  for (const p of problems) console.log(`  ${p}`);
  console.log(
    problems.length
      ? `${problems.length} mismatches. Run: node jobs.js --job=counts --apply`
      : `All ${subjects.size} subjects agree with their ${topics.size} topics.`,
  );
  process.exit(problems.length ? 1 : 0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(2);
  });
}

module.exports = { mismatches };
