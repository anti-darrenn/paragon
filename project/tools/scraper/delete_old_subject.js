const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.cert(require("./data/serviceAccountKey.json")) });
const db = admin.firestore();

const OLD_SUBJECT_ID = "uphLoWlc7wXLny7aMMnL";

async function deleteCollection(query) {
  const snap = await query.get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
  return snap.size;
}

async function main() {
  console.log("Deleting old test data for subject:", OLD_SUBJECT_ID);

  const q = await deleteCollection(
    db.collection("questions").where("subjectId", "==", OLD_SUBJECT_ID).limit(500)
  );
  console.log(`Deleted ${q} questions`);

  const t = await deleteCollection(
    db.collection("topics").where("subjectId", "==", OLD_SUBJECT_ID)
  );
  console.log(`Deleted ${t} topics`);

  const u = await deleteCollection(
    db.collection("units").where("subjectId", "==", OLD_SUBJECT_ID)
  );
  console.log(`Deleted ${u} units`);

  await db.collection("subjects").doc(OLD_SUBJECT_ID).delete();
  console.log("Deleted subject doc");

  console.log("Done.");
  process.exit(0);
}

main().catch(err => { console.error(err); process.exit(1); });