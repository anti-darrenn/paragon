/**
 * Re-classify every seeded question against its subject's real topic list.
 *
 * Why this exists rather than re-running `2_classify.js`:
 *
 *   1. **No padding.** The old classifier, when the model returned fewer
 *      indices than the batch size, padded the remainder with `0` — every
 *      missing question silently assigned to the first topic in the list.
 *      Physics's first topic ("Fundamental and Derived Quantities") sits
 *      at 2.2x the mean count, which is that bug's fingerprint, and is
 *      exactly the topic `fix_misclassified.js` was written to repair.
 *      Here, a short or malformed response is retried question by
 *      question and then skipped — never guessed.
 *
 *   2. **No integer scraping.** The old parser's last resort pulled every
 *      integer out of the response text and used them as topic indices,
 *      so a model that replied in prose produced confident nonsense. Here
 *      the response must parse as a JSON array of in-range integers of
 *      exactly the expected length, or it is not used.
 *
 *   3. **Live topic map.** Topics are read from Firestore rather than a
 *      hardcoded TOPIC_MAP that has to be edited per subject and had
 *      already drifted between scripts.
 *
 *   4. **The old model is gone.** `llama-3.1-8b-instant` is no longer in
 *      Groq's catalogue, so the original pipeline cannot run at all today.
 *
 * Safe by default: reports what it would change and writes nothing.
 * Pass --apply to write `topicId` updates, and --subject=<slug> to scope.
 *
 *   node reclassify.js                     # dry run, all subjects
 *   node reclassify.js --limit=100         # dry run, first 100 per subject
 *   node reclassify.js --apply             # write the changes
 *
 * Resumable: progress is written per subject after every batch.
 */
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const Groq = require("groq-sdk");
const admin = require("firebase-admin");

// Same precedence as tools/admin/jobs.js, so this runs unchanged locally
// (via the checked-in-but-gitignored serviceAccountKey.json) and in CI
// (via a repository secret) — see .github/workflows/reclassify.yml.
function loadCredential() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return admin.credential.cert(
      JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
    );
  }
  const local = path.join(__dirname, "data", "serviceAccountKey.json");
  if (fs.existsSync(local)) {
    return admin.credential.cert(require(local));
  }
  throw new Error(
    "No credentials. Set FIREBASE_SERVICE_ACCOUNT or place " +
      "serviceAccountKey.json in tools/scraper/data/."
  );
}

admin.initializeApp({ credential: loadCredential() });
const db = admin.firestore();
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Config ──────────────────────────────────────────────────────────────

const MODEL = "openai/gpt-oss-120b";
const BATCH_SIZE = 15;
const DELAY_MS = 600;
const MAX_TEXT = 200;

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const SUBJECT_FILTER = (args.find((a) => a.startsWith("--subject=")) || "")
  .split("=")[1];
const LIMIT = Number(
  (args.find((a) => a.startsWith("--limit=")) || "").split("=")[1] || 0
);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Groq's free tier allows 200,000 tokens per day. Hitting it is not a
 * classification failure and must not be recorded as one: the old
 * behaviour turned every remaining question into "unresolved", and
 * because `nextIndex` had already advanced, resuming tomorrow would skip
 * them forever. Now the run stops where it is and the next run continues
 * from exactly the same place.
 */
function isRateLimit(err) {
  const m = (err && err.message) || "";
  return (
    m.includes("rate_limit") ||
    m.includes("Rate limit") ||
    (err && err.status === 429)
  );
}

class RateLimited extends Error {}

// ─── Strict parsing ──────────────────────────────────────────────────────

/**
 * Returns an array of `expected` in-range integers, or null.
 *
 * Null means "unusable" and the caller must fall back to per-question
 * classification. It must never mean "assume something".
 */
function parseIndices(text, expected, topicCount) {
  const cleaned = text.replace(/```json|```/g, "").trim();
  const match = cleaned.match(/\[[\s\S]*?\]/);
  if (!match) return null;

  let parsed;
  try {
    parsed = JSON.parse(match[0]);
  } catch (_) {
    return null;
  }

  if (!Array.isArray(parsed)) return null;
  if (parsed.length !== expected) return null;
  for (const v of parsed) {
    if (!Number.isInteger(v) || v < 0 || v >= topicCount) return null;
  }
  return parsed;
}

function buildPrompt(subjectName, topicListText, questions) {
  const qList = questions
    .map((q, i) => `Q${i}: ${q.text.slice(0, MAX_TEXT).replace(/\s+/g, " ")}`)
    .join("\n");

  return `You are classifying Nigerian WAEC ${subjectName} exam questions by topic.

TOPIC LIST (index: Unit > Topic):
${topicListText}

QUESTIONS:
${qList}

Classify each question into exactly one topic index.
Return ONLY a JSON array of ${questions.length} integers, in the same order as the questions.
Do not explain. Do not wrap in markdown. Example: [4, 12, 31]`;
}

async function classifyBatch(subjectName, topicListText, topicCount, batch) {
  const completion = await groq.chat.completions.create({
    model: MODEL,
    messages: [
      {
        role: "user",
        content: buildPrompt(subjectName, topicListText, batch),
      },
    ],
    temperature: 0,
  });
  const text = completion.choices[0].message.content || "";
  return parseIndices(text, batch.length, topicCount);
}

/**
 * Fallback for a batch whose response could not be trusted: ask about each
 * question on its own, where "exactly one integer" is easy to verify.
 * Anything still unusable is returned as null and left untouched.
 */
async function classifyIndividually(
  subjectName,
  topicListText,
  topicCount,
  batch
) {
  const out = [];
  for (const q of batch) {
    try {
      const indices = await classifyBatch(
        subjectName,
        topicListText,
        topicCount,
        [q]
      );
      out.push(indices ? indices[0] : null);
    } catch (e) {
      if (isRateLimit(e)) throw new RateLimited();
      out.push(null);
    }
    await sleep(DELAY_MS);
  }
  return out;
}

// ─── Main ────────────────────────────────────────────────────────────────

async function processSubject(subjectDoc) {
  const subjectId = subjectDoc.id;
  const subjectName = subjectDoc.data().name;

  const units = await db
    .collection("units")
    .where("subjectId", "==", subjectId)
    .orderBy("order")
    .get();
  const unitNameById = {};
  for (const u of units.docs) unitNameById[u.id] = u.data().name;

  const topicsSnap = await db
    .collection("topics")
    .where("subjectId", "==", subjectId)
    .get();
  if (topicsSnap.empty) {
    console.log(`\n${subjectName}: no topics, skipping.`);
    return null;
  }

  // Stable ordering so an index means the same thing across runs.
  const topics = topicsSnap.docs
    .map((d) => ({
      id: d.id,
      name: d.data().name,
      unit: unitNameById[d.data().unitId] || "?",
      order: d.data().order ?? 99,
    }))
    .sort(
      (a, b) =>
        a.unit.localeCompare(b.unit) ||
        a.order - b.order ||
        a.name.localeCompare(b.name)
    );

  const topicListText = topics
    .map((t, i) => `${i}: ${t.unit} > ${t.name}`)
    .join("\n");
  const topicIndexById = {};
  topics.forEach((t, i) => (topicIndexById[t.id] = i));

  let questionsSnap = await db
    .collection("questions")
    .where("subjectId", "==", subjectId)
    .get();
  let questions = questionsSnap.docs.map((d) => ({
    id: d.id,
    text: d.data().text || "",
    topicId: d.data().topicId || null,
  }));
  if (LIMIT) questions = questions.slice(0, LIMIT);

  console.log(
    `\n${"=".repeat(68)}\n${subjectName} — ${questions.length} questions, ` +
      `${topics.length} topics\n${"=".repeat(68)}`
  );

  const progressFile = path.join(
    __dirname,
    "data",
    `reclassify_${subjectId}.json`
  );
  const doneFile = path.join(
    __dirname,
    "data",
    `reclassify_${subjectId}.done.json`
  );
  if (fs.existsSync(doneFile)) {
    console.log(`  already applied — skipping (delete ${path.basename(doneFile)} to redo).`);
    return null;
  }

  let state = { changes: [], unresolved: [], nextIndex: 0, agreed: 0 };
  if (fs.existsSync(progressFile)) {
    state = JSON.parse(fs.readFileSync(progressFile, "utf8"));
    console.log(`Resuming at ${state.nextIndex}.`);
  }

  for (let i = state.nextIndex; i < questions.length; i += BATCH_SIZE) {
    const batch = questions.slice(i, i + BATCH_SIZE);

    let indices = null;
    try {
      indices = await classifyBatch(
        subjectName,
        topicListText,
        topics.length,
        batch
      );
    } catch (e) {
      if (isRateLimit(e)) {
        console.log(
          `\n\n  Daily token limit reached at ${i}/${questions.length}.` +
            `\n  Progress saved. Re-run tomorrow to continue from here.`
        );
        return { subjectId, subjectName, state, halted: true, topicsById: {} };
      }
      console.warn(`\n  batch at ${i} errored: ${e.message}`);
    }

    if (!indices) {
      process.stdout.write(" [retry-singly] ");
      try {
        indices = await classifyIndividually(
          subjectName,
          topicListText,
          topics.length,
          batch
        );
      } catch (e) {
        if (e instanceof RateLimited) {
          console.log(
            `\n\n  Daily token limit reached at ${i}/${questions.length}.` +
              `\n  Progress saved. Re-run tomorrow to continue from here.`
          );
          return { subjectId, subjectName, state, halted: true, topicsById: {} };
        }
        throw e;
      }
    }

    for (let j = 0; j < batch.length; j++) {
      const q = batch[j];
      const idx = indices[j];
      if (idx === null || idx === undefined) {
        state.unresolved.push({ id: q.id, text: q.text.slice(0, 80) });
        continue;
      }
      const proposed = topics[idx];
      if (proposed.id === q.topicId) {
        state.agreed++;
        continue;
      }
      state.changes.push({
        id: q.id,
        text: q.text.slice(0, 90).replace(/\s+/g, " "),
        from: q.topicId,
        to: proposed.id,
        toName: `${proposed.unit} > ${proposed.name}`,
      });
    }

    state.nextIndex = i + BATCH_SIZE;
    fs.writeFileSync(progressFile, JSON.stringify(state, null, 2));

    const done = Math.min(state.nextIndex, questions.length);
    process.stdout.write(
      `\r  ${done}/${questions.length}  ` +
        `agree ${state.agreed}  change ${state.changes.length}  ` +
        `unresolved ${state.unresolved.length}   `
    );
    await sleep(DELAY_MS);
  }

  const considered = state.agreed + state.changes.length;
  const pct = considered
    ? ((state.changes.length / considered) * 100).toFixed(1)
    : "0.0";
  console.log(
    `\n  disagreement: ${state.changes.length}/${considered} (${pct}%)` +
      `, unresolved ${state.unresolved.length}`
  );

  return {
    subjectId,
    subjectName,
    state,
    complete: true,
    topicsById: Object.fromEntries(topics.map((t) => [t.id, t])),
  };
}

async function applyChanges(result) {
  const { changes } = result.state;
  if (!changes.length) return;

  console.log(`  applying ${changes.length} topic reassignments...`);
  for (let i = 0; i < changes.length; i += 400) {
    const batch = db.batch();
    for (const c of changes.slice(i, i + 400)) {
      batch.update(db.collection("questions").doc(c.id), { topicId: c.to });
    }
    await batch.commit();
  }

  // questionCount on every topic of this subject is now stale.
  const topicIds = Object.keys(result.topicsById);
  for (let i = 0; i < topicIds.length; i += 400) {
    const batch = db.batch();
    for (const topicId of topicIds.slice(i, i + 400)) {
      const agg = await db
        .collection("questions")
        .where("topicId", "==", topicId)
        .count()
        .get();
      batch.update(db.collection("topics").doc(topicId), {
        questionCount: agg.data().count,
      });
    }
    await batch.commit();
  }
  console.log("  topic questionCounts recomputed.");
}

async function main() {
  console.log(
    `Model: ${MODEL}   Mode: ${APPLY ? "APPLY (writes)" : "DRY RUN"}` +
      (LIMIT ? `   Limit: ${LIMIT}/subject` : "")
  );

  const subjects = await db.collection("subjects").orderBy("name").get();
  const results = [];

  for (const doc of subjects.docs) {
    const name = doc.data().name.toLowerCase().replace(/\s+/g, "-");
    if (SUBJECT_FILTER && name !== SUBJECT_FILTER) continue;
    const result = await processSubject(doc);
    if (!result) continue;
    results.push(result);

    // Apply as soon as a subject is fully classified, rather than after
    // every subject. A run that stops half way — a daily token limit, a
    // dropped connection — should still land the work it finished.
    if (APPLY && result.complete) {
      console.log(`\n  ${result.subjectName}: applying...`);
      await applyChanges(result);
      fs.writeFileSync(
        path.join(__dirname, "data", `reclassify_${result.subjectId}.done.json`),
        JSON.stringify(
          { appliedAt: new Date().toISOString(), changes: result.state.changes.length },
          null,
          2
        )
      );
      const pf = path.join(__dirname, "data", `reclassify_${result.subjectId}.json`);
      if (fs.existsSync(pf)) fs.unlinkSync(pf);
    }

    if (result.halted) {
      console.log("\n  Stopping: remaining subjects not attempted.");
      break;
    }
  }

  const reportPath = path.join(__dirname, "data", "reclassify_report.json");
  fs.writeFileSync(
    reportPath,
    JSON.stringify(
      results.map((r) => ({
        subject: r.subjectName,
        agreed: r.state.agreed,
        changes: r.state.changes,
        unresolved: r.state.unresolved,
      })),
      null,
      2
    )
  );
  console.log(`\nReport written to ${reportPath}`);

  if (APPLY) {
    console.log("\nApplied per subject above. Re-run check_linkage.js to verify.");
  } else {
    console.log("\nDry run — nothing written. Re-run with --apply to commit.");
  }

  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
