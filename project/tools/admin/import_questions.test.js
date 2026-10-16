// node import_questions.test.js — checks the importer's validation.
const assert = require("assert");
const { problemsWith, duplicateStems } = require("./import_questions");

const good = {
  subjectId: "s1", topicId: "t1", text: String.raw`Simplify \(2^3 \times 2^2\)`,
  options: ["32", "64", "16", "10"], correctIndex: 0, source: "waec", year: 2018,
};
// Control: a sound question passes.
assert.deepStrictEqual(problemsWith(good), []);
assert.deepStrictEqual(problemsWith({ ...good, source: "drill", year: undefined }), []);

const has = (q, text) => assert.ok(problemsWith(q).some((p) => p.includes(text)), `${text}: ${problemsWith(q)}`);
has({ ...good, options: ["1", "2", "3"] }, "options");
has({ ...good, options: ["1", "2", "2 ", "4"] }, "twice");
has({ ...good, correctIndex: 4 }, "correctIndex");
has({ ...good, correctIndex: -1 }, "correctIndex");
has({ ...good, year: undefined }, "year");
has({ ...good, source: "jamb" }, "source");
has({ ...good, text: String.raw`Bad \(\frac{1}\)` }, "stem");
// The audit's meaning-changing rules (question_rules.js).
has({ ...good, text: "A charge of 4 x 10-3 C" }, "lost-negative-power");
has({ ...good, text: "In the diagram, find x" }, "diagram-missing");
assert.deepStrictEqual(problemsWith({ ...good, text: "In the diagram, find x", imageId: "a1" }), []);
has({ ...good, options: [String.raw`\(\sqrt{\)`, "2", "3", "4"] }, "option 1");
has({ ...good, topicId: "" }, "topicId");

assert.deepStrictEqual(duplicateStems([good, { ...good, text: good.text.toUpperCase() + "  " }, { ...good, topicId: "t2" }]), [1]);
assert.deepStrictEqual(duplicateStems([good], new Set([`t1|${good.text.toLowerCase()}`])), [0]);
console.log("import_questions: all checks passed");
