// node difficulty_votes.test.js — the nightly tally of students' ratings.
const assert = require("assert");
const { tally, takeWithin } = require("./difficulty_votes");

// Two students rate one question; one rates another.
let t = tally([
  { userId: "a", votes: { q1: 4, q2: 2 } },
  { userId: "b", votes: { q1: 5 } },
]);
assert.deepStrictEqual(t.get("q1"), { n: 2, sum: 9 });
assert.deepStrictEqual(t.get("q2"), { n: 1, sum: 2 });

// One student, two sessions: counted once, at their latest rating.
t = tally([
  { userId: "a", votes: { q1: 1 } },
  { userId: "a", votes: { q1: 5 } },
]);
assert.deepStrictEqual(t.get("q1"), { n: 1, sum: 5 });

// Anything a client could write that is not a rating is ignored.
t = tally([
  { userId: "a", votes: { q1: 9, q2: 0, q3: 2.5, q4: "3", q5: 3 } },
  { userId: "b", votes: null },
  null,
]);
assert.deepStrictEqual([...t.keys()], ["q5"]);

// Control: an empty run tallies nothing.
assert.strictEqual(tally([]).size, 0);

// A run stops before it would touch too many questions, taking documents
// whole and oldest first — but always at least one.
const docs = [
  { userId: "a", votes: { q1: 1, q2: 1 } },
  { userId: "b", votes: { q2: 1, q3: 1 } },
  { userId: "c", votes: { q4: 1, q5: 1 } },
];
assert.strictEqual(takeWithin(docs, 3).length, 2);
assert.strictEqual(takeWithin(docs, 1).length, 1);
assert.strictEqual(takeWithin(docs, 100).length, 3);

console.log("difficulty votes: all checks passed");
