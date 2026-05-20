require("dotenv").config();
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const SUBJECT = 'further-mathematics';

// ─── Firebase Init ────────────────────────────────────────────────────────────

const SERVICE_ACCOUNT = path.join(__dirname, "data", "serviceAccountKey.json");

if (!fs.existsSync(SERVICE_ACCOUNT)) {
  console.error("ERROR: data/serviceAccountKey.json not found.");
  console.error("Go to Firebase Console → Project Settings → Service Accounts → Generate new private key");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT)),
});

const db = admin.firestore();

// ─── Data ─────────────────────────────────────────────────────────────────────

const INPUT_FILE = path.join(__dirname, "data", `classified_${SUBJECT}.json`);
const questions = JSON.parse(fs.readFileSync(INPUT_FILE, "utf8"));
console.log(`Loaded ${questions.length} questions from classified_${SUBJECT}.json`);

// ─── Unit order map (matches gameplan) ───────────────────────────────────────

const UNIT_ORDER = [
  "Pure Mathematics",
  "Statistics and Probability",
  "Vectors and Mechanics",
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Firestore batch limit is 500 ops. This helper commits in chunks.
async function batchWrite(operations) {
  const CHUNK = 499;
  for (let i = 0; i < operations.length; i += CHUNK) {
    const batch = db.batch();
    const chunk = operations.slice(i, i + CHUNK);
    for (const { ref, data } of chunk) {
      batch.set(ref, data);
    }
    await batch.commit();
    console.log(`  Committed ${Math.min(i + CHUNK, operations.length)}/${operations.length} documents`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  // ── 1. Create subject ──────────────────────────────────────────────────────
  console.log("\n[1/4] Creating subject: Futher Mathematics");
  const subjectRef = db.collection("subjects").doc();
  const subjectId = subjectRef.id;

  // Collect unique units and topics from the data
  const unitMap = {}; // unitName -> { topics: Set, order }
  for (const q of questions) {
    if (!unitMap[q.unitName]) {
      unitMap[q.unitName] = {
        topics: new Set(),
        order: UNIT_ORDER.indexOf(q.unitName),
      };
    }
    unitMap[q.unitName].topics.add(q.topicName);
  }

  // ── 2. Create units ────────────────────────────────────────────────────────
  console.log("\n[2/4] Creating units...");
  const unitIdMap = {}; // unitName -> docId

  const unitOps = [];
  for (const [unitName, { order }] of Object.entries(unitMap)) {
    const ref = db.collection("units").doc();
    unitIdMap[unitName] = ref.id;
    unitOps.push({
      ref,
      data: {
        subjectId,
        name: unitName,
        order: order >= 0 ? order : 99,
      },
    });
  }
  await batchWrite(unitOps);
  console.log(`Created ${unitOps.length} units`);

  // ── 3. Create topics ───────────────────────────────────────────────────────
  console.log("\n[3/4] Creating topics...");
  const topicIdMap = {}; // "unitName|topicName" -> docId
  const topicQuestionCount = {}; // "unitName|topicName" -> count

  // Count questions per topic
  for (const q of questions) {
    const key = `${q.unitName}|${q.topicName}`;
    topicQuestionCount[key] = (topicQuestionCount[key] || 0) + 1;
  }

  // Build topic order within each unit
  const topicOrderMap = {}; // unitName -> [topicName, ...]
  for (const q of questions) {
    if (!topicOrderMap[q.unitName]) topicOrderMap[q.unitName] = [];
    if (!topicOrderMap[q.unitName].includes(q.topicName)) {
      topicOrderMap[q.unitName].push(q.topicName);
    }
  }

  const topicOps = [];
  for (const [unitName, topicNames] of Object.entries(topicOrderMap)) {
    const unitId = unitIdMap[unitName];
    topicNames.forEach((topicName, order) => {
      const key = `${unitName}|${topicName}`;
      const ref = db.collection("topics").doc();
      topicIdMap[key] = ref.id;
      topicOps.push({
        ref,
        data: {
          subjectId,
          unitId,
          name: topicName,
          order,
          questionCount: topicQuestionCount[key] || 0,
        },
      });
    });
  }
  await batchWrite(topicOps);
  console.log(`Created ${topicOps.length} topics`);

  // ── 4. Create questions ────────────────────────────────────────────────────
  console.log("\n[4/4] Creating questions...");
  const questionOps = [];
  for (const q of questions) {
    const key = `${q.unitName}|${q.topicName}`;
    const topicId = topicIdMap[key];
    const ref = db.collection("questions").doc();
    questionOps.push({
      ref,
      data: {
        subjectId,
        topicId,
        text: q.text,
        options: q.options,
        correctIndex: q.correctIndex ?? null,
        explanation: q.explanation || "",
        source: "waec",
        year: q.year ?? null,
      },
    });
  }
  await batchWrite(questionOps);
  console.log(`Created ${questionOps.length} questions`);

  // ── 5. Create subject doc (now we know unitCount) ─────────────────────────
  await subjectRef.set({
    name: "Further Mathematics",
    unitCount: unitOps.length,
  });
  console.log(`\nCreated subject doc (id: ${subjectId})`);

  // ── Summary ────────────────────────────────────────────────────────────────
  console.log("\n✓ Seeding complete");
  console.log(`  Subject ID : ${subjectId}`);
  console.log(`  Units      : ${unitOps.length}`);
  console.log(`  Topics     : ${topicOps.length}`);
  console.log(`  Questions  : ${questionOps.length}`);
  console.log("\nSave the Subject ID above — you may need it to wire up the app.");

  process.exit(0);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});