const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.cert(require("./data/serviceAccountKey.json")) });
const db = admin.firestore();
db.collection("subjects").get().then(s => {
  console.log("Subjects in Firestore:");
  s.docs.forEach(d => console.log(d.id, JSON.stringify(d.data())));
  process.exit(0);
});