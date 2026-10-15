// node check_counts.test.js — checks the pure comparison in check_counts.js.
const assert = require("assert");
const { mismatches } = require("./check_counts");

const topics = [
  { name: "Indices", questionCount: 348, pastQuestionCount: 48, practiceQuestionCount: 300 },
  { name: "Surds", questionCount: 300, pastQuestionCount: 0, practiceQuestionCount: 300 },
];
// Control: a subject that is the sum of its topics passes.
assert.deepStrictEqual(
  mismatches({ name: "Maths", questionCount: 648, pastQuestionCount: 48, practiceQuestionCount: 600 }, topics),
  [],
);
// The live bug: the ticker and the course page disagreed.
assert.strictEqual(
  mismatches({ name: "Maths", questionCount: 634, pastQuestionCount: 48, practiceQuestionCount: 600 }, topics).length,
  1,
);
// A topic whose total is below its own split.
assert.strictEqual(
  mismatches({ name: "Maths", questionCount: 10, pastQuestionCount: 5, practiceQuestionCount: 6 }, [
    { name: "Odd", questionCount: 10, pastQuestionCount: 5, practiceQuestionCount: 6 },
  ]).length,
  1,
);
console.log("check_counts: all checks passed");
