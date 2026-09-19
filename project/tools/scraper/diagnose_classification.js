/**
 * Diagnostic — how lopsided is the live topic distribution?
 *
 * `2_classify.js` has two failure modes that both dump questions into the
 * wrong topic rather than erroring:
 *
 *   1. If the model returns fewer indices than the batch size, the missing
 *      ones are padded with `0` — i.e. silently assigned to whichever
 *      topic happens to be first in FLAT_TOPICS.
 *   2. If the response will not parse as JSON, the last-ditch fallback
 *      scrapes every integer out of the text and uses those as indices.
 *
 * If (1) fired often, the first topic of the first unit of each subject
 * will be conspicuously overrepresented. This script prints the per-topic
 * counts so that is visible rather than assumed.
 *
 * Read-only. Writes nothing.
 */
const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(
  __dirname,
  "data",
  "serviceAccountKey.json"
));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function main() {
  const subjects = await db.collection("subjects").orderBy("name").get();

  for (const subjectDoc of subjects.docs) {
    const subjectId = subjectDoc.id;
    const subjectName = subjectDoc.data().name;

    const units = await db
      .collection("units")
      .where("subjectId", "==", subjectId)
      .orderBy("order")
      .get();
    if (units.empty) continue;

    const topics = await db
      .collection("topics")
      .where("subjectId", "==", subjectId)
      .get();
    if (topics.empty) continue;

    const unitNameById = {};
    for (const u of units.docs) unitNameById[u.id] = u.data().name;

    // Count questions per topic with a single aggregate per topic.
    const rows = [];
    let total = 0;
    for (const t of topics.docs) {
      const agg = await db
        .collection("questions")
        .where("topicId", "==", t.id)
        .count()
        .get();
      const count = agg.data().count;
      total += count;
      rows.push({
        topic: t.data().name,
        unit: unitNameById[t.data().unitId] || "?",
        order: t.data().order,
        count,
      });
    }

    rows.sort((a, b) => b.count - a.count);

    console.log(`\n${"=".repeat(68)}`);
    console.log(`${subjectName} — ${total} questions across ${rows.length} topics`);
    console.log(`mean ${(total / rows.length).toFixed(1)} per topic`);
    console.log("=".repeat(68));

    for (const r of rows.slice(0, 8)) {
      const share = ((r.count / total) * 100).toFixed(1);
      const ratio = (r.count / (total / rows.length)).toFixed(1);
      console.log(
        `  ${String(r.count).padStart(5)}  ${share.padStart(5)}%  ` +
          `${ratio.padStart(5)}x mean   ${r.unit} > ${r.topic}`
      );
    }
    console.log("   ...");
    const tail = rows.slice(-3);
    for (const r of tail) {
      console.log(
        `  ${String(r.count).padStart(5)}  ` +
          `${((r.count / total) * 100).toFixed(1).padStart(5)}%          ` +
          `${r.unit} > ${r.topic}`
      );
    }
  }

  console.log("\nDone.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
