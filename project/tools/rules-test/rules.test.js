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
    await setDoc(doc(db, "theoryQuestions/tpub"), { subjectId: "s1", status: "published", parts: [] });
    await setDoc(doc(db, "theoryQuestions/tdraft"), { subjectId: "s1", status: "draft", parts: [] });
    await setDoc(doc(db, "insights/qpub"), { kind: "question", subjectId: "s1", status: "published", summary: "x" });
    await setDoc(doc(db, "insights/qdraft"), { kind: "question", subjectId: "s1", status: "draft", summary: "y" });
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

  console.log("\nchallenges: create once, get by id");
  const ch = (uid, over = {}) => ({
    userId: uid, name: "Ada", subjectId: "s1", topicId: "t1", topicName: "Indices",
    questionIds: ["q1", "q2"], score: 1, total: 2, createdAt: serverTimestamp(), ...over,
  });
  await check("an account makes a challenge", assertSucceeds(setDoc(doc(student("ann"), "challenges/c1"), ch("ann"))));
  await check("a guest makes one too", assertSucceeds(setDoc(doc(guest("g5"), "challenges/c2"), ch("g5"))));
  await check("a friend arriving as a guest can open it", assertSucceeds(getDoc(doc(guest("g6"), "challenges/c1"))));
  await check("signed out, it cannot be read", assertFails(getDoc(doc(nobody, "challenges/c1"))));
  await check("it cannot be edited", assertFails(updateDoc(doc(student("ann"), "challenges/c1"), { score: 2 })));
  await check("not in someone else's name", assertFails(setDoc(doc(student("ann"), "challenges/c3"), ch("bob"))));
  await check("score above total refused", assertFails(setDoc(doc(student("ann"), "challenges/c4"), ch("ann", { score: 3 }))));
  await check("more than ten questions refused", assertFails(setDoc(doc(student("ann"), "challenges/c5"), ch("ann", {
    questionIds: Array.from({ length: 11 }, (_, i) => `q${i}`), total: 11,
  }))));
  await check("no extra fields", assertFails(setDoc(doc(student("ann"), "challenges/c6"), ch("ann", { email: "x@y.z" }))));
  await check("a stranger cannot list challenges", assertFails(getDocs(collection(student("bob"), "challenges"))));
  await check(
    "the creator lists their own (the export)",
    assertSucceeds(getDocs(query(collection(student("ann"), "challenges"), where("userId", "==", "ann")))),
  );

  console.log("\nrooms: host writes, one live answer per player per question");
  const roomDoc = (host, over = {}) => ({
    hostUid: host, subjectId: "s1", topicId: "t1", topicName: "Indices",
    questionIds: ["q1", "q2"], state: "lobby", index: 0, createdAt: serverTimestamp(),
    results: {}, ...over,
  });
  await check("an account opens a room", assertSucceeds(setDoc(doc(student("ann"), "rooms/ABC234"), roomDoc("ann"))));
  await check("a guest cannot host", assertFails(setDoc(doc(guest("g7"), "rooms/ABC235"), roomDoc("g7"))));
  await check("not in someone else's name", assertFails(setDoc(doc(student("ann"), "rooms/ABC236"), roomDoc("bob"))));
  await check("a code outside the alphabet is refused", assertFails(setDoc(doc(student("ann"), "rooms/ABC0I1"), roomDoc("ann"))));
  await check("rooms cannot be listed", assertFails(getDocs(collection(student("bob"), "rooms"))));
  const nick = { nickname: "Tunde", joinedAt: serverTimestamp() };
  await check("a guest joins with a nickname", assertSucceeds(setDoc(doc(guest("g8"), "rooms/ABC234/players/g8"), nick)));
  await check("not as someone else", assertFails(setDoc(doc(guest("g8"), "rooms/ABC234/players/g9"), nick)));
  const ans = (uid, index, selectedIndex = 1) => ({ uid, index, selectedIndex, at: serverTimestamp() });
  await check(
    "no answering in the lobby",
    assertFails(setDoc(doc(guest("g8"), "rooms/ABC234/answers/g8_0"), ans("g8", 0))),
  );
  await check("a player cannot run the room", assertFails(updateDoc(doc(guest("g8"), "rooms/ABC234"), { state: "question" })));
  await check("the host starts question 1", assertSucceeds(updateDoc(doc(student("ann"), "rooms/ABC234"), { state: "question", index: 0 })));
  await check("the host cannot rewrite the questions", assertFails(updateDoc(doc(student("ann"), "rooms/ABC234"), { questionIds: ["x"] })));
  await check("a player answers the live question", assertSucceeds(setDoc(doc(guest("g8"), "rooms/ABC234/answers/g8_0"), ans("g8", 0))));
  await check("not twice", assertFails(setDoc(doc(guest("g8"), "rooms/ABC234/answers/g8_0"), ans("g8", 0, 2))));
  await check("not ahead of the host", assertFails(setDoc(doc(guest("g8"), "rooms/ABC234/answers/g8_1"), ans("g8", 1))));
  await check("not under a mismatched id", assertFails(setDoc(doc(guest("g8"), "rooms/ABC234/answers/g8_5"), ans("g8", 0))));
  await check(
    "not without joining",
    assertFails(setDoc(doc(guest("g10"), "rooms/ABC234/answers/g10_0"), ans("g10", 0))),
  );
  await check("a player cannot read the room's answers", assertFails(getDocs(collection(guest("g8"), "rooms/ABC234/answers"))));
  await check("the host can", assertSucceeds(getDocs(collection(student("ann"), "rooms/ABC234/answers"))));
  await check("the host moves on to the reveal", assertSucceeds(updateDoc(doc(student("ann"), "rooms/ABC234"), { state: "reveal" })));
  await check(
    "and a late answer is refused",
    assertFails(setDoc(doc(guest("g11"), "rooms/ABC234/answers/g11_0"), ans("g11", 0))),
  );

  console.log("\ninsights: students read published ones by id; staff write");
  const writer = () =>
    env.authenticatedContext("wri", { writer: true, firebase: { sign_in_provider: "google.com" } }).firestore();
  const ins = (status, by) => ({
    kind: "question", subjectId: "s1", questionId: "q1", topicId: "t1", summary: "Many confused base and index.",
    commonWrongOption: 2, tip: "", reportYear: 2018, reportRef: "WASSCE 2018 Q12", years: [], status,
    updatedAt: serverTimestamp(), updatedBy: by,
  });
  await check("a student reads a published insight", assertSucceeds(getDoc(doc(student(), "insights/qpub"))));
  await check("not a draft", assertFails(getDoc(doc(student(), "insights/qdraft"))));
  await check("students cannot list insights", assertFails(getDocs(collection(student(), "insights"))));
  await check("a student cannot write one", assertFails(setDoc(doc(student(), "insights/q9"), ins("draft", "ann"))));
  await check("a writer saves a draft", assertSucceeds(setDoc(doc(writer(), "insights/q1"), ins("draft", "wri"))));
  await check("a writer cannot publish", assertFails(setDoc(doc(writer(), "insights/q1"), ins("published", "wri"))));
  await check("a reviewer publishes", assertSucceeds(setDoc(doc(reviewer(), "insights/q1"), ins("published", "rev"))));
  await check(
    "a writer cannot edit a published one",
    assertFails(setDoc(doc(writer(), "insights/q1"), ins("draft", "wri"))),
  );

  console.log("\ncontributors: public bylines, Admin SDK only");
  await check("a student reads a byline", assertSucceeds(getDoc(doc(student(), "contributors/wri"))));
  await check("nobody writes one from the app, not even a reviewer", assertFails(setDoc(doc(reviewer(), "contributors/rev"), { displayName: "Rev" })));
  await check("not even about themselves", assertFails(setDoc(doc(student("ann"), "contributors/ann"), { displayName: "Ann" })));
  await check("bylines cannot be listed", assertFails(getDocs(collection(student(), "contributors"))));

  console.log("\ntheory: published only, written by the Admin SDK");
  await check(
    "a student lists published theory",
    assertSucceeds(getDocs(query(collection(student(), "theoryQuestions"), where("subjectId", "==", "s1"), where("status", "==", "published")))),
  );
  await check("not a draft", assertFails(getDoc(doc(student(), "theoryQuestions/tdraft"))));
  await check("no client writes", assertFails(setDoc(doc(reviewer(), "theoryQuestions/t9"), { subjectId: "s1", status: "draft" })));

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
