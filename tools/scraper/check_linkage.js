const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.cert(require("./data/serviceAccountKey.json")) });
const db = admin.firestore();

async function main() {
  // Get first topic
  const topicsSnap = await db.collection("topics").limit(3).get();
  console.log("Sample topics:");
  for (const doc of topicsSnap.docs) {
    console.log(" ", doc.id, JSON.stringify(doc.data()));
    // Check questions for this topic
    const qSnap = await db.collection("questions").where("topicId", "==", doc.id).limit(2).get();
    console.log(`  → ${qSnap.size} questions found for this topicId`);
    if (!qSnap.empty) {
      console.log("  Sample question:", JSON.stringify(qSnap.docs[0].data()).slice(0, 120));
    }
  }
  process.exit(0);
}

main().catch(err => { console.error(err); process.exit(1); });