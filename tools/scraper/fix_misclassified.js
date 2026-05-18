require("dotenv").config();
const fs = require("fs");
const path = require("path");
const Groq = require("groq-sdk");

const FILE = path.join(__dirname, "data", "classified.json");
const PROGRESS_FILE = path.join(__dirname, "data", "fix_progress.json");
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// Topics to re-classify — all confirmed mostly or entirely wrong
const SUSPECT_TOPICS = [
  "Construction",
  "Angles",
  "Rational Numbers",
  "Logical Reasoning",
  "Angles on Parallel Lines",
  "Loci",
  "Linear Inequalities",
  "Algebraic Fractions",
  "Lengths and Perimeters",
  "Transformation",
  "Vectors in a Plane",
  "Statistics",
];

const TOPIC_MAP = {
  "Number and Numeration": [
    "Number Bases", "Modular Arithmetic", "Fractions/Decimals/Approximations",
    "Indices", "Logarithms", "Sequence and Series", "Sets", "Logical Reasoning",
    "Rational Numbers", "Surds", "Matrices and Determinants", "Ratio/Proportions/Rates",
    "Percentages", "Financial Arithmetic", "Variation",
  ],
  "Algebraic Processes": [
    "Algebraic Expressions", "Expansion and Factorisation", "Linear Equations",
    "Change of Subject of Formula", "Quadratic Equations",
    "Graphs of Linear and Quadratic Functions", "Linear Inequalities",
    "Algebraic Fractions", "Functions and Relations",
  ],
  "Mensuration": ["Lengths and Perimeters", "Areas", "Volumes"],
  "Plane Geometry": [
    "Angles", "Angles on Parallel Lines", "Triangles and Polygons",
    "Circle Theorems", "Construction", "Loci",
  ],
  "Coordinate Geometry": ["Coordinate Geometry of Straight Lines"],
  "Trigonometry": ["Sine/Cosine/Tangent", "Angles of Elevation and Depression", "Bearings"],
  "Calculus": ["Differentiation", "Integration"],
  "Statistics and Probability": ["Statistics", "Probability"],
  "Vectors and Transformation": ["Vectors in a Plane", "Transformation"],
};

const FLAT_TOPICS = [];
let idx = 0;
for (const [unit, topics] of Object.entries(TOPIC_MAP)) {
  for (const topic of topics) {
    FLAT_TOPICS.push({ index: idx++, unit, topic });
  }
}

const TOPIC_LIST_TEXT = FLAT_TOPICS.map(t => `${t.index}: ${t.unit} > ${t.topic}`).join("\n");

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function parseResponse(text) {
  const cleaned = text.replace(/```json|```/g, "").trim();
  try { return JSON.parse(cleaned); } catch (_) {}
  const match = cleaned.match(/\[[\d,\s]+\]/);
  if (match) return JSON.parse(match[0]);
  const nums = cleaned.match(/\d+/g);
  if (nums && nums.length > 0) return nums.map(Number);
  throw new Error("Could not parse: " + cleaned.slice(0, 200));
}

function buildPrompt(questions) {
  const qList = questions.map(({ q }, j) => `Q${j}: ${q.text.slice(0, 300)}`).join("\n");

  return `You are classifying Nigerian WAEC Mathematics exam questions into the correct topic.

TOPIC LIST (index: Unit > Topic):
${TOPIC_LIST_TEXT}

CLASSIFICATION RULES — read carefully:
- "Construction" (index 38): ONLY use if the question explicitly asks to construct a figure with compass/ruler. Circle, triangle, and polygon diagram questions are NOT construction.
- "Angles on Parallel Lines" (index 33): ONLY use if the question involves two or more parallel lines cut by a transversal.
- "Angles" (index 32): ONLY use for basic angle facts (vertically opposite, angles on a straight line, angles at a point). NOT for statistics, probability, or circles.
- "Rational Numbers" (index 22): ONLY for questions specifically about rational vs irrational number classification.
- "Logical Reasoning" (index 21): ONLY for questions involving logical statements, truth tables, or implication/negation.
- "Loci" (index 39): ONLY for questions asking about the locus/path of a moving point.
- "Statistics" (index 42): mean, median, mode, frequency tables, histograms, cumulative frequency, range, quartiles.
- "Probability" (index 43): chance, likelihood, P(event), outcomes.
- "Vectors in a Plane" (index 44): ONLY for vector addition, scalar multiplication, position vectors, column vectors.
- "Transformation" (index 45): ONLY for reflection, rotation, translation, enlargement of shapes.

QUESTIONS TO CLASSIFY:
${qList}

Return ONLY a JSON array of integers — one topic index per question, in order.
No explanation, no markdown, just the raw JSON array.`;
}

async function main() {
  if (!process.env.GROQ_API_KEY) {
    console.error("ERROR: GROQ_API_KEY not set in .env");
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(FILE, "utf8"));

  // Find all questions from suspect topics with their original indices
  const targets = data
    .map((q, i) => ({ q, i }))
    .filter(({ q }) => SUSPECT_TOPICS.includes(q.topicName));

  console.log(`Found ${targets.length} questions to re-classify across ${SUSPECT_TOPICS.length} suspect topics`);

  // Resume support
  let startBatch = 0;
  const fixes = {}; // originalIndex -> {unitName, topicName}

  if (fs.existsSync(PROGRESS_FILE)) {
    const prog = JSON.parse(fs.readFileSync(PROGRESS_FILE, "utf8"));
    startBatch = prog.startBatch;
    Object.assign(fixes, prog.fixes);
    console.log(`Resuming from batch ${startBatch} (${Object.keys(fixes).length} already fixed)`);
  }

  const BATCH = 5;
  const totalBatches = Math.ceil(targets.length / BATCH);

  for (let b = startBatch; b < totalBatches; b++) {
    const batch = targets.slice(b * BATCH, (b + 1) * BATCH);

    process.stdout.write(`Batch ${b + 1}/${totalBatches}... `);

    try {
      const prompt = buildPrompt(batch);
      const completion = await groq.chat.completions.create({
        model: "llama-3.1-8b-instant",
        messages: [{ role: "user", content: prompt }],
        temperature: 0,
      });
      let indices = parseResponse(completion.choices[0].message.content);
      indices = indices.slice(0, batch.length);
      while (indices.length < batch.length) indices.push(0);

      for (let j = 0; j < batch.length; j++) {
        const topicEntry = FLAT_TOPICS[indices[j]] || FLAT_TOPICS[0];
        fixes[batch[j].i] = { unitName: topicEntry.unit, topicName: topicEntry.topic };
      }

      console.log(`done`);
    } catch (err) {
      console.error(`ERROR: ${err.message}`);
      console.log("Saving progress. Re-run to resume.");
      fs.writeFileSync(PROGRESS_FILE, JSON.stringify({ startBatch: b, fixes }, null, 2));
      process.exit(1);
    }

    fs.writeFileSync(PROGRESS_FILE, JSON.stringify({ startBatch: b + 1, fixes }, null, 2));

    if (b + 1 < totalBatches) await sleep(2500);
  }

  // Apply all fixes
  let changed = 0;
  for (const [idxStr, { unitName, topicName }] of Object.entries(fixes)) {
    const i = Number(idxStr);
    if (data[i].topicName !== topicName) changed++;
    data[i].unitName = unitName;
    data[i].topicName = topicName;
  }

  fs.writeFileSync(FILE, JSON.stringify(data, null, 2));
  console.log(`\nApplied ${changed} topic changes. classified.json updated.`);

  if (fs.existsSync(PROGRESS_FILE)) fs.unlinkSync(PROGRESS_FILE);

  // Print new distribution
  console.log("\n=== Updated distribution ===");
  const topics = {};
  data.forEach(q => {
    const key = q.unitName + " > " + q.topicName;
    topics[key] = (topics[key] || 0) + 1;
  });
  Object.entries(topics).sort((a, b) => b[1] - a[1])
    .forEach(([k, v]) => console.log(v, k));
}

main();