#!/usr/bin/env node
/**
 * Applies a hand-written corrections file to questions (see
 * `corrections/`): each entry names one field of one question and either a
 * `find`/`replace` (every occurrence), a `regex`/`replace`, or a whole `set`.
 *
 *   node apply_corrections.js --file=corrections/2026-10-15-latex.js            # dry run
 *   node apply_corrections.js --file=corrections/2026-10-15-latex.js --commit
 *   node apply_corrections.js --file=… --commit --vet   # also vet each corrected question (owner-approved files)
 *   node apply_corrections.js --revert=.backups/<file>.json
 *
 * Reads only the questions named (one read each, dry run included, since
 * the `find` strings are written against what is live). A question with
 * any `find` that no longer matches is skipped whole and reported: half a
 * correction is worse than none. Maths is checked after: a correction that
 * leaves a field with more unrenderable maths than before is refused.
 * Backups and `--revert` work as in fix_questions.js.
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
const BACKUPS = path.join(__dirname, ".backups");

const read = (q, field) => (field.startsWith("options.") ? q.options[Number(field.split(".")[1])] : q[field]);

/** {fields: {field: after}, problems: [..]} for one question's entries. */
function correct(q, entries) {
  const fields = {};
  const problems = [];
  for (const e of entries) {
    if (e.retire) {
      // Out of drill, WAEC Prep, tests and the static site; flipping
      // hasAnswer back restores it (the convention admin flag review uses).
      if (q.hasAnswer === false) problems.push("already retired");
      fields.hasAnswer = false;
      fields.reviewNote = e.retire;
      if (e.duplicateOf) fields.duplicateOf = e.duplicateOf;
      if (e.needsDiagram) fields.needsDiagram = true;
      continue;
    }
    if (e.field === "all") {
      // A regex over the stem, every option and the explanation.
      const all = ["text", "explanation", ...(q.options || []).map((_, i) => `options.${i}`)];
      for (const f of all) {
        const before = String(fields[f] ?? read(q, f) ?? "").replace(/ /g, " ");
        const after = before.replace(new RegExp(e.regex, "g"), e.replace);
        if (after !== before) fields[f] = after;
      }
      continue;
    }
    if (e.field === "topicId") {
      fields.topicId = e.set;
      fields.previousTopicId = q.topicId; // as reclassification records it
      continue;
    }
    if (e.field === "correctIndex") {
      // A corrected answer key, recorded as the studio's report review does.
      const n = (q.options || []).length;
      if (!Number.isInteger(e.set) || e.set < 0 || e.set >= n) problems.push(`correctIndex ${e.set} is not one of the ${n} options`);
      else if (e.set === q.correctIndex) problems.push(`correctIndex is already ${e.set}`);
      else {
        fields.correctIndex = e.set;
        fields.previousCorrectIndex = q.correctIndex;
      }
      continue;
    }
    const raw = fields[e.field] ?? read(q, e.field);
    if (e.set != null && raw == null) {
      fields[e.field] = e.set; // a field the question did not have, such as a missing explanation
      continue;
    }
    if (typeof raw !== "string") {
      problems.push(`${e.field} is missing`);
      continue;
    }
    // The scraped HTML left non-breaking spaces that look like spaces; a
    // corrected field gets plain ones, so `find` strings match as written.
    const before = raw.replace(/ /g, " ");
    let after;
    if (e.set != null) after = e.set;
    else if (e.regex) after = before.replace(new RegExp(e.regex, "g"), e.replace);
    else {
      if (!before.includes(e.find)) {
        problems.push(`${e.field}: no longer contains ${JSON.stringify(e.find)}`);
        continue;
      }
      after = before.split(e.find).join(e.replace);
    }
    fields[e.field] = after;
  }
  for (const [field, after] of Object.entries(fields)) {
    if (typeof after !== "string" || !(field === "text" || field === "explanation" || field.startsWith("options."))) continue;
    const was = R.brokenLatex(read(q, field)).length;
    const now = R.brokenLatex(after).length;
    if (now > was) problems.push(`${field}: maths worse after (${was} → ${now}): ${R.brokenLatex(after).join("; ")}`);
  }
  return { fields, problems };
}

async function main() {
  const { initAdmin } = require("./credential");
  const admin = initAdmin();
  const db = admin.firestore();

  if (args.revert) {
    const backup = JSON.parse(fs.readFileSync(path.resolve(__dirname, String(args.revert)), "utf8"));
    const { FieldValue } = admin.firestore;
    const entries = Object.entries(backup.questions);
    for (let i = 0; i < entries.length; i += 400) {
      const batch = db.batch();
      for (const [id, before] of entries.slice(i, i + 400)) {
        const restore = Object.fromEntries(Object.entries(before).map(([k, v]) => [k, v === null ? FieldValue.delete() : v]));
        batch.update(db.collection("questions").doc(id), restore);
      }
      await batch.commit();
    }
    console.log(`Restored ${Object.keys(backup.questions).length} questions.`);
    return;
  }

  const entries = require(path.resolve(__dirname, String(args.file)));
  const byId = new Map();
  for (const e of entries) byId.set(e.id, [...(byId.get(e.id) || []), e]);
  const snaps = await db.getAll(...[...byId.keys()].map((id) => db.collection("questions").doc(id)));

  const ready = [];
  let skipped = 0;
  for (const snap of snaps) {
    if (!snap.exists) {
      console.log(`SKIP ${snap.id}: no such question`);
      skipped++;
      continue;
    }
    const q = { id: snap.id, ...snap.data() };
    const { fields, problems } = correct(q, byId.get(snap.id));
    if (problems.length) {
      console.log(`SKIP ${q.id}:\n  ${problems.join("\n  ")}`);
      skipped++;
      continue;
    }
    ready.push({ q, fields });
    if (args.verbose) {
      for (const [f, after] of Object.entries(fields)) console.log(`${q.id} ${f}\n  - ${JSON.stringify(read(q, f))}\n  + ${JSON.stringify(after)}`);
    }
  }
  const textual = (f, v) => typeof v === "string" && (f === "text" || f === "explanation" || f.startsWith("options."));
  const stillBroken = ready.filter(({ fields }) => Object.entries(fields).some(([f, v]) => textual(f, v) && R.brokenLatex(v).length));
  console.log(`${ready.length} questions ready, ${skipped} skipped; ${stillBroken.length} still have maths that won't render:`);
  for (const { q, fields } of stillBroken) {
    for (const [f, v] of Object.entries(fields)) if (textual(f, v)) for (const p of R.brokenLatex(v)) console.log(`  ${q.id} ${f}: ${p}`);
  }
  if (!args.commit) {
    console.log("Dry run. Pass --commit to write.");
    return;
  }

  // --vet: the owner approved this file as the check, so each corrected
  // question is vetted in the same write, tagged like vet_bank.js's pass,
  // and the note saying why it was held goes.
  const VET = args.vet === true;
  const VET_FIELDS = ["vetted", "vettedAt", "vettedBy", "vetNote"];
  const backup = { takenAt: new Date().toISOString(), file: String(args.file), questions: {} };
  for (const { q, fields } of ready) {
    const before = {};
    for (const f of [...Object.keys(fields), ...(VET ? VET_FIELDS : [])]) {
      if (f.startsWith("options.")) before.options = q.options;
      // A field that did not exist is restored as deleted.
      else before[f] = q[f] === undefined ? null : q[f];
    }
    backup.questions[q.id] = before;
  }
  fs.mkdirSync(BACKUPS, { recursive: true });
  const file = path.join(BACKUPS, `corrections-${backup.takenAt.replace(/[:.]/g, "-")}.json`);
  fs.writeFileSync(file, JSON.stringify(backup));
  const { FieldValue } = admin.firestore;
  // A batch takes at most 500 writes.
  for (let i = 0; i < ready.length; i += 400) {
    const batch = db.batch();
    for (const { q, fields } of ready.slice(i, i + 400)) {
      const update = { contentCorrectedAt: FieldValue.serverTimestamp() };
      for (const [f, v] of Object.entries(fields)) {
        if (f.startsWith("options.")) {
          update.options ??= [...q.options];
          update.options[Number(f.split(".")[1])] = v;
        } else update[f] = v;
      }
      if (VET) {
        Object.assign(update, { vetted: true, vettedAt: FieldValue.serverTimestamp(), vettedBy: "claude-check", vetNote: FieldValue.delete() });
      }
      batch.update(db.collection("questions").doc(q.id), update);
    }
    await batch.commit();
  }
  console.log(`Wrote ${ready.length}${VET ? ", vetted" : ""}. Backup: ${path.relative(__dirname, file)}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
