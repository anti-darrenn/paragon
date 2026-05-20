require("dotenv").config();
const fs = require("fs");
const path = require("path");
const Groq = require("groq-sdk");
const SUBJECT = 'further-mathematics';

// ─── Config ───────────────────────────────────────────────────────────────────

const INPUT_FILE = path.join(__dirname, "data", `raw_${SUBJECT}.json`);
const OUTPUT_FILE = path.join(__dirname, 'data', `classified_${SUBJECT}.json`);
const PROGRESS_FILE = path.join(__dirname, 'data', `classify_progress_${SUBJECT}.json`);

const BATCH_SIZE = 20;
const DELAY_MS = 1000;

// ─── Topic Map ────────────────────────────────────────────────────────────────

const TOPIC_MAP = {
  "Pure Mathematics": [
    "Sets and Venn Diagrams",
    "Surds",
    "Binary Operations",
    "Logical Reasoning",
    "Functions",
    "Polynomial Functions",
    "Rational Functions and Partial Fractions",
    "Indices and Logarithms",
    "Permutations and Combinations",
    "Binomial Theorem",
    "Sequences and Series",
    "Matrices and Linear Transformation",
    "Trigonometry",
    "Coordinate Geometry",
    "Differentiation",
    "Integration",
  ],
  "Statistics and Probability": [
    "Statistics",
    "Probability",
  ],
  "Vectors and Mechanics": [
    "Vectors",
    "Statics",
    "Dynamics and Projectiles",
  ],
};

const FLAT_TOPICS = [];
let topicIndex = 0;
for (const [unit, topics] of Object.entries(TOPIC_MAP)) {
  for (const topic of topics) {
    FLAT_TOPICS.push({ index: topicIndex++, unit, topic });
  }
}

const TOPIC_LIST_TEXT = FLAT_TOPICS.map(
  (t) => `${t.index}: ${t.unit} > ${t.topic}`
).join("\n");

// ─── Groq Setup ───────────────────────────────────────────────────────────────

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ─── Helpers ──────────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildPrompt(questions) {
  const qList = questions
    .map((q, i) => `Q${i}: ${q.text.slice(0, 200)}`)
    .join("\n");

  return `You are classifying Nigerian WAEC Mathematics questions into topics.

TOPIC LIST (index: Unit > Topic):
${TOPIC_LIST_TEXT}

QUESTIONS TO CLASSIFY:
${qList}

Return ONLY a JSON array of integers — one topic index per question, in order.
Example for 3 questions: [4, 12, 31]
No explanation, no markdown, just the raw JSON array.`;
}

function parseResponse(text) {
  const cleaned = text.replace(/```json|```/g, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch (_) {
    // Try extracting a complete [...] array
    const match = cleaned.match(/\[[\d,\s]+\]/);
    if (match) return JSON.parse(match[0]);
    // Fallback: pull out all integers from the string
    const nums = cleaned.match(/\d+/g);
    if (nums && nums.length > 0) return nums.map(Number);
    throw new Error("Could not parse JSON array from response: " + cleaned.slice(0, 200));
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  if (!process.env.GROQ_API_KEY) {
    console.error("ERROR: GROQ_API_KEY not set in .env");
    process.exit(1);
  }

  const rawFile = JSON.parse(fs.readFileSync(INPUT_FILE, "utf8"));
  const raw = rawFile.questions;
  console.log(`Loaded ${raw.length} questions from raw.json`);

  let results = [];
  let startIndex = 0;

  if (fs.existsSync(PROGRESS_FILE)) {
    const progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, "utf8"));
    results = progress.results;
    startIndex = progress.nextIndex;
    console.log(`Resuming from question ${startIndex} (${results.length} already classified)`);
  }

  const totalBatches = Math.ceil((raw.length - startIndex) / BATCH_SIZE);
  let batchNum = 0;

  for (let i = startIndex; i < raw.length; i += BATCH_SIZE) {
    const batch = raw.slice(i, i + BATCH_SIZE);
    batchNum++;

    process.stdout.write(
      `Batch ${batchNum}/${totalBatches} (questions ${i}–${Math.min(i + BATCH_SIZE - 1, raw.length - 1)})... `
    );

    let indices;
    try {
      const prompt = buildPrompt(batch);
      const completion = await groq.chat.completions.create({
        model: "llama-3.1-8b-instant",
        messages: [{ role: "user", content: prompt }],
        temperature: 0,
      });
      const text = completion.choices[0].message.content;
      indices = parseResponse(text);

      if (!Array.isArray(indices)) {
        throw new Error(`Expected array, got: ${typeof indices}`);
      }
      while (indices.length < batch.length) {
  console.warn(`\nWARN: model returned ${indices.length} indices for ${batch.length} questions — padding with 0`);
  indices.push(0);
}
      // Trim any extras the model added
      indices = indices.slice(0, batch.length);

    } catch (err) {
      console.error(`\nERROR on batch ${batchNum}: ${err.message}`);
      console.log("Saving progress and exiting. Re-run to resume.");
      fs.writeFileSync(
        PROGRESS_FILE,
        JSON.stringify({ results, nextIndex: i }, null, 2)
      );
      process.exit(1);
    }

    for (let j = 0; j < batch.length; j++) {
      const topicEntry = FLAT_TOPICS[indices[j]];
      if (!topicEntry) {
        console.warn(`\nWARN: invalid topic index ${indices[j]} for question ${i + j} — defaulting to index 0`);
      }
      results.push({
        ...batch[j],
        unitName: topicEntry ? topicEntry.unit : FLAT_TOPICS[0].unit,
        topicName: topicEntry ? topicEntry.topic : FLAT_TOPICS[0].topic,
      });
    }

    console.log(`done (${results.length}/${raw.length})`);

    fs.writeFileSync(
      PROGRESS_FILE,
      JSON.stringify({ results, nextIndex: i + BATCH_SIZE }, null, 2)
    );

    if (i + BATCH_SIZE < raw.length) {
      await sleep(DELAY_MS);
    }
  }

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  console.log(`\nDone. ${results.length} questions written to data/classified.json`);

  if (fs.existsSync(PROGRESS_FILE)) {
    fs.unlinkSync(PROGRESS_FILE);
  }
}

main();