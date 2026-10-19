/**
 * Bulk vetting for the founder's question bank (owner's decision,
 * 2026-10-19). Every question is pending until it is vetted. This checks the
 * whole bank and marks the questions that pass as vetted, with
 * `vettedBy: "claude-check"`, so they can all be listed and undone together.
 * Anything doubtful stays pending, with a reason.
 *
 *   node vet_bank.js --export [--source=waec|drill] [--max-reads=30000]
 *   node vet_bank.js --check
 *   node vet_bank.js --batches [--size=40]
 *   node vet_bank.js --ingest
 *   node vet_bank.js --status
 *   node vet_bank.js --apply [--subject=Mathematics] [--max-writes=N] [--commit]
 *   node vet_bank.js --report
 *   node vet_bank.js --revert [--commit]
 *
 * **Passing a question.** Every question must pass the mechanical checks:
 * - the content rules' level-A and level-S findings (`question_rules.js`);
 * - an explanation that disagrees with the marked option;
 * - maths that KaTeX cannot render once `normalizeTex` has run.
 *
 * Then it needs a review:
 * - **Past questions**, and generated ones changed since they were
 *   generated, are solved one by one. Batches go to `.vetting/batches/` and
 *   verdicts come back in `.vetting/verdicts/`.
 * - **Generated questions still exactly as generated** follow their
 *   generator's review in `.vetting/generators.json`. Their answers are
 *   computed in code, so a reviewed generator vouches for its output. A
 *   template the reviewer held keeps its questions pending.
 *
 * **Only pending questions are touched.** A missing `vetted` field means
 * pending. A question with `vetted: false` was sent back by the team, and
 * stays as it is. Authored questions are the founder's own.
 *
 * **The quota.** Reads are budgeted per Pacific day (`--max-reads`, default
 * 30,000). Writes share the seeders' daily budget
 * (`../scraper/seed_quota.js`). Each update has a `lastUpdateTime`
 * precondition, so a question edited since the export is skipped, not
 * vetted blind.
 *
 * Everything lives in `tools/admin/.vetting/`, which is gitignored. The
 * export is resumable: run it again and it carries on.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const katex = require("../site/node_modules/katex");
const R = require("./question_rules");
const { normalizeTex } = require("../site/tex_preprocess");
const budget = require("../scraper/seed_quota");

const TAG = "claude-check";
const DIR = path.join(__dirname, ".vetting");
const GEN_DIR = path.join(__dirname, "..", "scraper", "data");
const SOURCES = ["waec", "drill"];
const SUBJECT_ORDER = ["Mathematics", "Physics", "Further Mathematics", "Chemistry", "Government"];
const FIELDS = [
  "text", "options", "correctIndex", "explanation", "subjectId", "topicId",
  "source", "origin", "year", "hasAnswer", "vetted", "imageId",
  "explanationImageId", "auditDismissed",
];

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v ?? true];
  })
);
const COMMIT = args.commit === true;

fs.mkdirSync(DIR, { recursive: true });
const file = (name) => path.join(DIR, name);
const readJson = (name, fallback) => {
  try {
    return JSON.parse(fs.readFileSync(file(name), "utf8"));
  } catch {
    return fallback;
  }
};
const writeJson = (name, value) => {
  fs.mkdirSync(path.dirname(file(name)), { recursive: true });
  fs.writeFileSync(file(name), JSON.stringify(value, null, 1));
};

/** Same as `templateKey` in lib/core/content/session_mix.dart. */
const templateKey = (text) => String(text).replace(/\d+(?:\.\d+)?/g, "#").replace(/\s+/g, " ");

let _db;
function db() {
  if (!_db) _db = require("./credential").initAdmin().firestore();
  return _db;
}

// ── Reads, budgeted per Pacific day ──────────────────────────────────────

const MAX_READS = Number(args["max-reads"] || 30000);
function readsToday() {
  const s = readJson("reads.json", {});
  return s.day === budget.quotaDay() ? s.reads : 0;
}
function spendReads(n) {
  writeJson("reads.json", { day: budget.quotaDay(), reads: readsToday() + n });
}

// ── Export ───────────────────────────────────────────────────────────────

async function exportMeta() {
  if (fs.existsSync(file("meta.json"))) return;
  const [subjects, units, topics] = await Promise.all(
    ["subjects", "units", "topics"].map((c) => db().collection(c).get())
  );
  spendReads(subjects.size + units.size + topics.size);
  writeJson("meta.json", {
    subjects: Object.fromEntries(subjects.docs.map((d) => [d.id, d.data().name])),
    units: Object.fromEntries(units.docs.map((d) => [d.id, d.data().name])),
    topics: Object.fromEntries(
      topics.docs.map((d) => [d.id, { name: d.data().name, unitId: d.data().unitId, subjectId: d.data().subjectId }])
    ),
  });
}

async function exportSource(source) {
  const { FieldPath } = require("firebase-admin").firestore;
  const stateName = `export_${source}.json`;
  const state = readJson(stateName, { cursor: null, done: false, count: 0 });
  if (state.done) return console.log(`${source}: already exported (${state.count})`);
  const out = fs.createWriteStream(file(`q_${source}.jsonl`), { flags: "a" });
  while (readsToday() < MAX_READS) {
    const limit = Math.min(500, MAX_READS - readsToday());
    let q = db()
      .collection("questions")
      .where("source", "==", source)
      .orderBy(FieldPath.documentId())
      .select(...FIELDS)
      .limit(limit);
    if (state.cursor) q = q.startAfter(state.cursor);
    const snap = await q.get();
    spendReads(Math.max(1, snap.size));
    for (const d of snap.docs) {
      const t = d.updateTime;
      out.write(JSON.stringify({ id: d.id, updated: [t.seconds, t.nanoseconds], ...d.data() }) + "\n");
    }
    state.count += snap.size;
    if (snap.size) state.cursor = snap.docs[snap.size - 1].id;
    if (snap.size < limit) state.done = true;
    writeJson(stateName, state);
    process.stdout.write(`\r${source}: ${state.count} exported, ${readsToday()} reads today`);
    if (state.done) break;
  }
  await new Promise((r) => out.end(r));
  console.log(state.done ? `\n${source}: done` : `\n${source}: read budget spent; run again after midnight Pacific`);
}

/** The diagrams of past questions under review, as files a reviewer can open. */
async function exportImages(questions) {
  const ids = [...new Set(questions.flatMap((q) => [q.imageId, q.explanationImageId]).filter(Boolean))];
  const missing = ids.filter((id) => !fs.readdirSync(file("img")).some((f) => f.startsWith(id + ".")));
  for (let i = 0; i < missing.length && readsToday() < MAX_READS; i += 100) {
    const refs = missing.slice(i, i + 100).map((id) => db().collection("lessonAssets").doc(id));
    const snaps = await db().getAll(...refs);
    spendReads(snaps.length);
    for (const s of snaps) {
      if (!s.exists) continue;
      const a = s.data();
      const ext = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif", "image/svg+xml": "svg" }[a.mime] || "bin";
      fs.writeFileSync(file(`img/${s.id}.${ext}`), a.mime === "image/svg+xml" ? a.data : Buffer.from(a.data, "base64"));
    }
  }
}

function loadQuestions() {
  const all = [];
  for (const s of SOURCES) {
    const p = file(`q_${s}.jsonl`);
    if (!fs.existsSync(p)) continue;
    const seen = new Set();
    for (const line of fs.readFileSync(p, "utf8").split("\n")) {
      if (!line.trim()) continue;
      const q = JSON.parse(line);
      if (!seen.has(q.id)) all.push(q), seen.add(q.id);
    }
  }
  return all;
}

// ── Mechanical checks ────────────────────────────────────────────────────

const SPAN = /\\\(([\s\S]*?)\\\)|\\\[([\s\S]*?)\\\]|\$\$([\s\S]*?)\$\$/g;
function mathsProblem(value) {
  const out = normalizeTex(String(value ?? ""));
  for (const m of out.matchAll(SPAN)) {
    const tex = m[1] ?? m[2] ?? m[3];
    try {
      katex.renderToString(tex, { throwOnError: true, strict: "ignore" });
    } catch (e) {
      return `${e.message.replace(/^KaTeX parse error: /, "").slice(0, 80)} in ${tex.slice(0, 60)}`;
    }
  }
  return null;
}

/** text → [{file, options, correctIndex}] over the committed generator output. */
function generatedIndex() {
  const index = new Map();
  for (const f of fs.readdirSync(GEN_DIR).filter((x) => /^generated_.*\.json$/.test(x))) {
    const stem = f.replace(/\.json$/, "");
    for (const q of JSON.parse(fs.readFileSync(path.join(GEN_DIR, f), "utf8"))) {
      index.set(q.text, { file: stem, options: q.options, correctIndex: q.correctIndex });
    }
  }
  return index;
}

const sameOptions = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => x === b[i]);

function check() {
  const questions = loadQuestions();
  const gen = generatedIndex();
  const checks = {};
  for (const q of questions) {
    const c = { problems: [] };
    if (q.vetted === true) c.state = "already-vetted";
    else if (q.vetted === false) c.state = "sent-back";
    else if (q.hasAnswer !== true) c.state = "no-answer";
    else if (q.origin === "authored") c.state = "authored";
    else c.state = "pending";

    const options = q.options || [];
    if (!(Number.isInteger(q.correctIndex) && q.correctIndex >= 0 && q.correctIndex < options.length)) {
      c.problems.push(`no marked answer (correctIndex ${q.correctIndex})`);
    }
    for (const f of R.checkQuestion(q)) {
      if ((q.auditDismissed || []).includes(f.rule)) continue;
      if (f.level === "A" || f.level === "S" || f.rule === "explanation-mismatch") {
        c.problems.push(`${f.rule}${f.detail ? `: ${String(f.detail).slice(0, 100)}` : ""}`);
      }
    }
    for (const [field, value] of [["question", q.text], ["explanation", q.explanation], ...options.map((o, i) => [`option ${"ABCDE"[i]}`, o])]) {
      const p = mathsProblem(value);
      if (p) c.problems.push(`maths in ${field}: ${p}`);
    }

    const g = q.origin === "ai_generated" ? gen.get(q.text) : null;
    if (g && sameOptions(g.options, options) && g.correctIndex === q.correctIndex) {
      c.kind = "generated";
      c.generator = g.file;
      c.template = templateKey(q.text);
    } else {
      c.kind = q.source === "waec" ? "past" : "changed";
    }
    checks[q.id] = c;
  }
  writeJson("checks.json", checks);
  status();
}

// ── Review batches ───────────────────────────────────────────────────────

async function batches() {
  const meta = readJson("meta.json", null);
  const checks = readJson("checks.json", null);
  if (!meta || !checks) throw new Error("Run --export and --check first.");
  const size = Number(args.size || 40);
  const todo = loadQuestions().filter((q) => {
    const c = checks[q.id];
    return c && c.state === "pending" && !c.problems.length && c.kind !== "generated";
  });
  fs.mkdirSync(file("img"), { recursive: true });
  await exportImages(todo);
  const images = new Set(fs.readdirSync(file("img")));
  const imagePath = (id) => {
    const f = id && [...images].find((x) => x.startsWith(id + "."));
    return f ? path.join(DIR, "img", f) : id ? "(image could not be read)" : undefined;
  };
  const bySubject = {};
  for (const q of todo) (bySubject[meta.subjects[q.subjectId] || q.subjectId] ??= []).push(q);
  const done = new Set(fs.existsSync(file("batches")) ? fs.readdirSync(file("batches")) : []);
  let made = 0;
  for (const [subject, list] of Object.entries(bySubject)) {
    const topicName = (q) => meta.topics[q.topicId]?.name || q.topicId;
    list.sort((a, b) => topicName(a).localeCompare(topicName(b)) || a.id.localeCompare(b.id));
    const slug = subject.toLowerCase().replace(/[^a-z]+/g, "-");
    for (let i = 0; i < list.length; i += size) {
      const name = `${slug}_${String(i / size + 1).padStart(3, "0")}.json`;
      if (done.has(name)) continue;
      writeJson(`batches/${name}`, list.slice(i, i + size).map((q) => ({
        id: q.id,
        subject,
        topic: topicName(q),
        unit: meta.units[meta.topics[q.topicId]?.unitId] || undefined,
        kind: checks[q.id].kind,
        year: q.year ?? undefined,
        question: q.text,
        options: Object.fromEntries((q.options || []).map((o, j) => ["ABCDE"[j], o])),
        marked: "ABCDE"[q.correctIndex],
        explanation: q.explanation || undefined,
        diagram: imagePath(q.imageId),
        workedAnswerImage: imagePath(q.explanationImageId),
      })));
      made++;
    }
  }
  console.log(`${made} new batches of up to ${size} in ${file("batches")} (${todo.length} questions to review)`);
}

function verdicts() {
  const out = {};
  const dir = file("verdicts");
  if (!fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith(".json"))) {
    for (const [id, v] of Object.entries(JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))) out[id] = v;
  }
  return out;
}

/**
 * Reads the reviews back in.
 *
 * - **`solved/*.json`**: blind answers to the past questions. A question
 *   passes when the reviewer reached the marked answer with high confidence
 *   and found nothing blocking. A blocking problem holds it. Anything else
 *   (a different answer, "none", medium or low confidence) goes to
 *   `adjudicate/`, for a second reviewer who sees the marked answer and the
 *   worked one.
 * - **`adjudicated/*.json`**: that second look. "marked-correct" passes;
 *   anything else holds, with the reason.
 * - **`genreview/*.json`**: the generator reviews, which become
 *   `generators.json`.
 */
function ingest() {
  const batchQs = {};
  for (const f of fs.readdirSync(file("batches"))) {
    for (const q of JSON.parse(fs.readFileSync(file(`batches/${f}`), "utf8"))) batchQs[q.id] = q;
  }
  const solved = {};
  for (const f of fs.existsSync(file("solved")) ? fs.readdirSync(file("solved")) : []) {
    for (const r of JSON.parse(fs.readFileSync(file(`solved/${f}`), "utf8"))) solved[r.id] = r;
  }
  const second = {};
  for (const f of fs.existsSync(file("adjudicated")) ? fs.readdirSync(file("adjudicated")) : []) {
    for (const r of JSON.parse(fs.readFileSync(file(`adjudicated/${f}`), "utf8"))) second[r.id] = r;
  }
  const out = {};
  const toAdjudicate = [];
  const cosmetic = [];
  for (const [id, r] of Object.entries(solved)) {
    const q = batchQs[id];
    if (!q) continue;
    if (r.problem === "cosmetic") cosmetic.push({ id, note: r.note });
    if (r.problem === "blocking") {
      out[id] = { verdict: "hold", note: `blocking: ${r.note}` };
    } else if (r.answer === q.marked && r.confidence === "high") {
      out[id] = { verdict: "vet", note: r.note || "" };
    } else if (second[id]) {
      const s = second[id];
      out[id] =
        s.verdict === "marked-correct"
          ? { verdict: "vet", note: s.note || "" }
          : { verdict: "hold", note: `${s.verdict}${s.correct ? ` (correct: ${s.correct})` : ""}: ${s.note}`, correct: s.correct };
    } else {
      toAdjudicate.push({ ...q, solverAnswer: r.answer, solverConfidence: r.confidence, solverNote: r.note });
    }
  }
  writeJson("verdicts/review.json", out);
  writeJson("cosmetic.json", cosmetic);
  fs.rmSync(file("adjudicate"), { recursive: true, force: true });
  for (let i = 0; i < toAdjudicate.length; i += 25) {
    writeJson(`adjudicate/${String(i / 25 + 1).padStart(3, "0")}.json`, toAdjudicate.slice(i, i + 25));
  }

  const gens = {};
  for (const f of fs.existsSync(file("genreview")) ? fs.readdirSync(file("genreview")) : []) {
    if (!f.endsWith(".json") || f.endsWith(".inputs.json")) continue;
    for (const r of JSON.parse(fs.readFileSync(file(`genreview/${f}`), "utf8"))) {
      gens[r.file.replace(/\.json$/, "")] = {
        hold: r.verdict === "hold-all",
        note: r.note,
        holdTemplates: (r.holdQuestionTexts || []).map(templateKey),
        holdSubstrings: r.holdSubstrings || [],
      };
    }
  }
  writeJson("generators.json", gens);
  const n = Object.values(out).reduce((t, v) => ((t[v.verdict] = (t[v.verdict] || 0) + 1), t), {});
  console.log(
    `past questions: ${Object.keys(solved).length} solved`, n,
    `${toAdjudicate.length} to adjudicate, ${cosmetic.length} cosmetic notes; generators reviewed: ${Object.keys(gens).length} files`
  );
}

/** What --apply would do with each question: `vet`, or the reason it waits. */
function decide() {
  const checks = readJson("checks.json", {});
  const gens = readJson("generators.json", {});
  const v = verdicts();
  const qs = new Map(loadQuestions().map((q) => [q.id, q]));
  const out = {};
  for (const [id, c] of Object.entries(checks)) {
    if (c.state !== "pending") out[id] = c.state;
    else if (c.problems.length) out[id] = "check-failed";
    else if (c.kind === "generated") {
      const g = gens[c.generator];
      const q = qs.get(id);
      const shown = [q?.text, ...(q?.options || [])].join("\n");
      if (!g) out[id] = "generator-not-reviewed";
      else if (g.hold) out[id] = "generator-held";
      else if ((g.holdTemplates || []).includes(c.template)) out[id] = "template-held";
      else if ((g.holdSubstrings || []).some((s) => s && shown.includes(s))) out[id] = "statement-held";
      else out[id] = "vet";
    } else {
      const r = v[id];
      if (!r) out[id] = "not-reviewed";
      else out[id] = r.verdict === "vet" ? "vet" : "review-held";
    }
  }
  return out;
}

function status() {
  const meta = readJson("meta.json", { subjects: {} });
  const qs = new Map(loadQuestions().map((q) => [q.id, q]));
  const d = decide();
  const table = {};
  for (const [id, what] of Object.entries(d)) {
    const s = meta.subjects[qs.get(id)?.subjectId] || "?";
    (table[s] ??= {})[what] = (table[s][what] || 0) + 1;
  }
  const exp = SOURCES.map((s) => `${s} ${readJson(`export_${s}.json`, { count: 0 }).count}${readJson(`export_${s}.json`, {}).done ? " (done)" : ""}`);
  console.log(`exported: ${exp.join(", ")}; reads today ${readsToday()}/${MAX_READS}; ${budget.summary()}`);
  console.table(table);
}

// ── Writes ───────────────────────────────────────────────────────────────

async function apply() {
  const { FieldValue, Timestamp } = require("firebase-admin").firestore;
  const meta = readJson("meta.json", { subjects: {} });
  const d = decide();
  const applied = new Set(
    fs.existsSync(file("applied.jsonl")) ? fs.readFileSync(file("applied.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l).id) : []
  );
  const order = (q) => {
    const i = SUBJECT_ORDER.indexOf(meta.subjects[q.subjectId]);
    return i < 0 ? 99 : i;
  };
  let todo = loadQuestions().filter((q) => d[q.id] === "vet" && !applied.has(q.id));
  if (args.subject) todo = todo.filter((q) => meta.subjects[q.subjectId] === args.subject);
  todo.sort((a, b) => order(a) - order(b) || String(a.topicId).localeCompare(String(b.topicId)));
  const cap = Math.min(budget.remaining(), Number(args["max-writes"] || Infinity));
  const batch = todo.slice(0, cap);
  const by = {};
  for (const q of batch) by[meta.subjects[q.subjectId]] = (by[meta.subjects[q.subjectId]] || 0) + 1;
  console.log(`${todo.length} ready to vet; this run: ${batch.length} (${budget.summary()})`, by);
  if (!COMMIT) return console.log("Dry run. Add --commit to write.");

  const backups = path.join(__dirname, ".backups");
  fs.mkdirSync(backups, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  fs.writeFileSync(path.join(backups, `vet_bank_${stamp}.json`), JSON.stringify(batch.map((q) => q.id)));

  const log = fs.createWriteStream(file("applied.jsonl"), { flags: "a" });
  const writer = db().bulkWriter();
  let ok = 0;
  const skipped = [];
  writer.onWriteError((e) => {
    skipped.push({ id: e.documentRef.id, why: e.code === 9 ? "changed since the export" : e.message });
    return false;
  });
  for (const q of batch) {
    writer
      .update(
        db().collection("questions").doc(q.id),
        { vetted: true, vettedAt: FieldValue.serverTimestamp(), vettedBy: TAG },
        { lastUpdateTime: new Timestamp(q.updated[0], q.updated[1]) }
      )
      .then(() => {
        ok++;
        log.write(JSON.stringify({ id: q.id, at: new Date().toISOString() }) + "\n");
      })
      .catch(() => {});
  }
  await writer.close();
  await new Promise((r) => log.end(r));
  budget.spend(batch.length);
  if (skipped.length) writeJson(`skipped_${stamp}.json`, skipped);
  console.log(`vetted ${ok}; skipped ${skipped.length}${skipped.length ? ` (see .vetting/skipped_${stamp}.json)` : ""}`);
}

async function revert() {
  const { FieldValue } = require("firebase-admin").firestore;
  const snap = await db().collection("questions").where("vettedBy", "==", TAG).select().get();
  console.log(`${snap.size} questions carry vettedBy "${TAG}" (${budget.summary()})`);
  if (!COMMIT) return console.log("Dry run. Add --commit to put them back to pending.");
  const docs = snap.docs.slice(0, budget.remaining());
  const writer = db().bulkWriter();
  for (const d of docs) {
    writer.update(d.ref, { vetted: FieldValue.delete(), vettedAt: FieldValue.delete(), vettedBy: FieldValue.delete() });
  }
  await writer.close();
  budget.spend(docs.length);
  fs.rmSync(file("applied.jsonl"), { force: true });
  console.log(`${docs.length} back to pending${docs.length < snap.size ? "; run again tomorrow for the rest" : ""}`);
}

// ── The owner's report ───────────────────────────────────────────────────

function report() {
  const meta = readJson("meta.json", { subjects: {}, topics: {} });
  const checks = readJson("checks.json", {});
  const v = verdicts();
  const gens = readJson("generators.json", {});
  const d = decide();
  const qs = loadQuestions();
  const csv = [["id", "subject", "topic", "status", "reason", "link"]];
  for (const q of qs) {
    const what = d[q.id];
    if (!what || what === "vet" || what === "already-vetted") continue;
    const c = checks[q.id];
    const reason =
      what === "check-failed" ? c.problems.join("; ")
      : what === "review-held" ? v[q.id]?.note || ""
      : what === "generator-held" ? gens[c.generator]?.note || ""
      : what === "template-held" || what === "statement-held" ? gens[c.generator]?.note || what
      : "";
    csv.push([q.id, meta.subjects[q.subjectId] || "", meta.topics[q.topicId]?.name || "", what, reason, `https://paragon-hq.web.app/admin/question/${q.id}`]);
  }
  const esc = (x) => `"${String(x).replace(/"/g, '""')}"`;
  fs.writeFileSync(file("held.csv"), csv.map((r) => r.map(esc).join(",")).join("\n"));
  // A fixed random sample of what was vetted, for the owner to spot-check.
  const vetted = qs.filter((q) => d[q.id] === "vet").map((q) => q.id);
  const sample = vetted
    .map((id) => [crypto.createHash("sha1").update(id).digest("hex"), id])
    .sort()
    .slice(0, 100)
    .map(([, id]) => `https://paragon-hq.web.app/admin/question/${id}`);
  fs.writeFileSync(file("spot_check.txt"), sample.join("\n"));
  console.log(`${csv.length - 1} held → .vetting/held.csv; 100 spot-check links → .vetting/spot_check.txt`);
}

(async () => {
  try {
    if (args.export) {
      await exportMeta();
      for (const s of args.source ? [args.source] : SOURCES) await exportSource(s);
    } else if (args.check) check();
    else if (args.ingest) ingest();
    else if (args.batches) await batches();
    else if (args.apply) await apply();
    else if (args.report) report();
    else if (args.revert) await revert();
    else status();
  } catch (e) {
    console.error(budget.isQuota(e) ? budget.explain(e) : e.stack || e.message);
    process.exit(1);
  }
})();
