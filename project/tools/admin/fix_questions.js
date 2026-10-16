#!/usr/bin/env node
/**
 * Applies the mechanical content fixes from `question_rules.js` to past
 * questions: powers of ten written "10-3", flat units ("cm3", "ms-1"),
 * degrees written "30o", naira written "N140" (maths subjects only), known
 * typos, OCR's "lf"/"ln the", and a lower-case first letter.
 *
 *   node fix_questions.js                       # dry run over the static-site cache: no reads
 *   node fix_questions.js --report=fixes.txt    # …and write every before/after to a file
 *   node fix_questions.js --commit              # re-read the affected questions, then write
 *   node fix_questions.js --revert=.backups/<file>.json
 *
 * On commit, each affected question is read fresh (one read each) and the
 * fixes are recomputed on what is live, so nothing edited since the cache
 * was taken is overwritten with stale text. Before anything is written, the
 * old values go to `.backups/` (gitignored), which `--revert` restores.
 * Each question also gets `contentFixRules` and `contentFixedAt`.
 *
 * Only text outside maths changes, and only into maths that says the same
 * thing (see question_rules.js). Anything needing judgement is reported by
 * content_audit.js, never changed here.
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
const BACKUPS = path.join(__dirname, ".backups");

function plan(questions, names) {
  const out = [];
  for (const q of questions) {
    const r = R.fixQuestion(q, names[q.subjectId]);
    if (r.changes.length) out.push({ q, ...r });
  }
  return out;
}

function describe(fixes) {
  const counts = {};
  const lines = [];
  for (const f of fixes) {
    for (const c of f.changes) {
      for (const rule of c.rules) counts[rule] = (counts[rule] || 0) + 1;
      const where = c.field + (c.index != null ? `[${c.index}]` : "");
      lines.push(`${f.q.id} ${where} [${c.rules.join(", ")}]\n  - ${JSON.stringify(c.before)}\n  + ${JSON.stringify(c.after)}`);
    }
  }
  return { counts, lines };
}

async function revert(file) {
  const { initAdmin } = require("./credential");
  const admin = initAdmin();
  const db = admin.firestore();
  const backup = JSON.parse(fs.readFileSync(path.resolve(__dirname, file), "utf8"));
  const entries = Object.entries(backup.questions);
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    for (const [id, before] of entries.slice(i, i + 400)) {
      batch.update(db.collection("questions").doc(id), {
        ...before,
        contentFixRules: admin.firestore.FieldValue.delete(),
        contentFixedAt: admin.firestore.FieldValue.delete(),
      });
    }
    await batch.commit();
  }
  console.log(`Restored ${entries.length} questions from ${file}.`);
}

async function main() {
  if (args.revert) return revert(String(args.revert));

  const data = JSON.parse(fs.readFileSync(CACHE, "utf8"));
  const names = Object.fromEntries(data.subjects.map((s) => [s.id, s.name]));
  const cached = plan(data.questions, names);
  const { counts, lines } = describe(cached);
  console.log(`From the cache (${data.readAt}): ${cached.length} questions to fix.`);
  console.log(counts);
  if (args.report) {
    fs.writeFileSync(path.resolve(String(args.report)), lines.join("\n") + "\n");
    console.log(`Every change: ${args.report}`);
  }
  if (!args.commit) {
    console.log("Dry run. Pass --commit to write.");
    return;
  }

  const { initAdmin } = require("./credential");
  const admin = initAdmin();
  const db = admin.firestore();
  const fresh = [];
  for (let i = 0; i < cached.length; i += 100) {
    const refs = cached.slice(i, i + 100).map((f) => db.collection("questions").doc(f.q.id));
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) fresh.push({ id: snap.id, ...snap.data() });
    }
  }
  const live = plan(fresh, names);
  console.log(`Read ${fresh.length}; ${live.length} still need fixing.`);

  const backup = { takenAt: new Date().toISOString(), questions: {} };
  for (const f of live) {
    const before = {};
    for (const c of f.changes) {
      if (c.field === "options") before.options = f.q.options;
      else before[c.field] = f.q[c.field];
    }
    backup.questions[f.q.id] = before;
  }
  fs.mkdirSync(BACKUPS, { recursive: true });
  const file = path.join(BACKUPS, `fix_questions-${backup.takenAt.replace(/[:.]/g, "-")}.json`);
  fs.writeFileSync(file, JSON.stringify(backup));
  console.log(`Backup: ${path.relative(__dirname, file)}`);

  const { FieldValue } = admin.firestore;
  for (let i = 0; i < live.length; i += 400) {
    const batch = db.batch();
    for (const f of live.slice(i, i + 400)) {
      const update = {};
      const rules = new Set();
      for (const c of f.changes) {
        if (c.field === "options") update.options = f.options;
        else update[c.field] = f[c.field];
        c.rules.forEach((r) => rules.add(r));
      }
      update.contentFixRules = FieldValue.arrayUnion(...rules);
      update.contentFixedAt = FieldValue.serverTimestamp();
      batch.update(db.collection("questions").doc(f.q.id), update);
    }
    await batch.commit();
    console.log(`Wrote ${Math.min(i + 400, live.length)} of ${live.length}.`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
