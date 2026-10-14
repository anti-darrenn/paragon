/**
 * firestore.rules against the Firestore emulator, as clients would meet
 * them. Runs in CI (`npm test`, which wraps it in `firebase emulators:exec`);
 * this machine has no Java, so locally the live check stays
 * `tools/admin/verify_rules.js`. The two overlap on purpose: this one
 * runs on every pull request against seeded fixtures, that one against
 * the deployed project after a rules deploy.
 *
 * As there: the denials are the content. An allowed write only proves
 * something allowed it; every allow here sits next to the denial that
 * gives it meaning.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  getDocs,
  query,
  where,
  serverTimestamp,
} = require("firebase/firestore");

let passed = 0;
const failures = [];
async function check(label, promise) {
  try {
    await promise;
    passed++;
    console.log(`  ok  ${label}`);
  } catch (e) {
    failures.push(`${label}: ${e.message}`);
    console.log(`  FAIL ${label}\n       ${e.message}`);
  }
}

async function main() {
  const env = await initializeTestEnvironment({
    projectId: "demo-paragon",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8"),
    },
  });

  // ── Fixtures, written past the rules ──────────────────────────────
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "topics/t1"), { subjectId: "s1", name: "Indices", lessonCount: 1 });
    await setDoc(doc(db, "topics/t1/resources/live"), {
      subjectId: "s1", topicId: "t1", status: "published", title: "Laws of indices", type: "article", order: 1,
    });
    await setDoc(doc(db, "topics/t1/resources/draft"), {
      subjectId: "s1", topicId: "t1", status: "draft", title: "test2", type: "article", order: 2,
    });
    await setDoc(doc(db, "questions/q1"), {
      subjectId: "s1", topicId: "t1", text: "2+2?", options: ["3", "4"], correctIndex: 1, hasAnswer: true,
    });
    await setDoc(doc(db, "waitlist/bob"), { userId: "bob", subjects: ["biology"] });
  });

  const student = (uid = "ann") =>
    env.authenticatedContext(uid, { firebase: { sign_in_provider: "google.com" } }).firestore();
  const guest = (uid = "guest1") =>
    env.authenticatedContext(uid, { firebase: { sign_in_provider: "anonymous" } }).firestore();
  const reviewer = () =>
    env.authenticatedContext("rev", { reviewer: true, firebase: { sign_in_provider: "google.com" } }).firestore();
  const nobody = env.unauthenticatedContext().firestore();

  console.log("\nLearn content: drafts never reach students (P1.1)");
  await check("a student reads a published item", assertSucceeds(getDoc(doc(student(), "topics/t1/resources/live"))));
  await check("a student cannot read a draft by id", assertFails(getDoc(doc(student(), "topics/t1/resources/draft"))));
  await check("a guest cannot read a draft by id", assertFails(getDoc(doc(guest(), "topics/t1/resources/draft"))));
  await check(
    "a student lists resources filtered to published",
    assertSucceeds(getDocs(query(collection(student(), "topics/t1/resources"), where("status", "==", "published")))),
  );
  await check(
    "an unfiltered list is refused (rules are not filters)",
    assertFails(getDocs(collection(student(), "topics/t1/resources"))),
  );
  await check("a reviewer reads a draft", assertSucceeds(getDoc(doc(reviewer(), "topics/t1/resources/draft"))));
  await check("signed out, nothing is readable", assertFails(getDoc(doc(nobody, "topics/t1/resources/live"))));
  await check(
    "a student cannot publish",
    assertFails(updateDoc(doc(student(), "topics/t1/resources/draft"), { status: "published" })),
  );

  console.log("\nQuestions and topics: server-written");
  await check("a student reads a question", assertSucceeds(getDoc(doc(student(), "questions/q1"))));
  await check(
    "a student cannot change an answer",
    assertFails(updateDoc(doc(student(), "questions/q1"), { correctIndex: 0 })),
  );
  await check(
    "a student cannot change a topic's counts",
    assertFails(updateDoc(doc(student(), "topics/t1"), { pastQuestionCount: 999 })),
  );

  console.log("\nprogress/{uid}: owner only, server time");
  const progress = (uid) => ({ userId: uid, updatedAt: serverTimestamp(), topics: {} });
  await check("a student writes their own progress", assertSucceeds(setDoc(doc(student("ann"), "progress/ann"), progress("ann"))));
  await check("a guest writes their own progress", assertSucceeds(setDoc(doc(guest("g2"), "progress/g2"), progress("g2"))));
  await check(
    "nobody writes another's progress",
    assertFails(setDoc(doc(student("ann"), "progress/bob"), progress("bob"))),
  );
  await check(
    "a client-chosen time is refused",
    assertFails(setDoc(doc(student("ann"), "progress/ann"), { userId: "ann", updatedAt: new Date(0), topics: {} })),
  );
  await check(
    "a field outside the allow-list is refused (leaderboards stay server-fed)",
    assertFails(setDoc(doc(student("ann"), "progress/ann"), { ...progress("ann"), xp: 9999 })),
  );
  await check("another's progress is not readable", assertFails(getDoc(doc(student("ann"), "progress/bob"))));

  console.log("\nattempts: your own only");
  await check(
    "a student records their own attempt",
    assertSucceeds(setDoc(doc(student("ann"), "attempts/a1"), { userId: "ann", questionId: "q1", isCorrect: true })),
  );
  await check(
    "an attempt in someone else's name is refused",
    assertFails(setDoc(doc(student("ann"), "attempts/a2"), { userId: "bob", questionId: "q1", isCorrect: true })),
  );

  console.log("\nwaitlist/{uid}: accounts only (P1.5)");
  const list = (uid) => ({ userId: uid, subjects: ["biology"], updatedAt: serverTimestamp() });
  await check("an account joins a waitlist", assertSucceeds(setDoc(doc(student("ann"), "waitlist/ann"), list("ann"))));
  await check("a guest cannot", assertFails(setDoc(doc(guest("g3"), "waitlist/g3"), list("g3"))));
  await check("not on another's uid", assertFails(setDoc(doc(student("ann"), "waitlist/bob"), list("bob"))));
  await check(
    "no extra fields",
    assertFails(setDoc(doc(student("ann"), "waitlist/ann"), { ...list("ann"), email: "x@y.z" })),
  );
  await check("another's sign-up is private", assertFails(getDoc(doc(student("ann"), "waitlist/bob"))));
  await check("a student cannot list sign-ups", assertFails(getDocs(collection(student(), "waitlist"))));
  await check(
    "a reviewer can count them",
    assertSucceeds(getDocs(query(collection(reviewer(), "waitlist"), where("subjects", "array-contains", "biology")))),
  );

  console.log("\nplan/{uid}: accounts only");
  const planDoc = (uid, goal = 100) => ({ userId: uid, weeklyGoal: goal, examDate: null, updatedAt: serverTimestamp() });
  await check("an account saves its plan", assertSucceeds(setDoc(doc(student("ann"), "plan/ann"), planDoc("ann"))));
  await check("a guest cannot", assertFails(setDoc(doc(guest("g4"), "plan/g4"), planDoc("g4"))));
  await check("not on another's uid", assertFails(setDoc(doc(student("ann"), "plan/bob"), planDoc("bob"))));
  await check("a goal off the list is refused", assertFails(setDoc(doc(student("ann"), "plan/ann"), planDoc("ann", 7))));
  await check("another's plan is private", assertFails(getDoc(doc(student("bob"), "plan/ann"))));

  console.log("\nusers/{uid}");
  await check("another student's account is not readable", assertFails(getDoc(doc(student("ann"), "users/bob"))));

  await env.cleanup();
  console.log(`\n${passed} passed, ${failures.length} failed`);
  process.exit(failures.length ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
