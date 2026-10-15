// node set_contributor.test.js — checks the byline validation.
const assert = require("assert");
const { contributorDoc } = require("./set_contributor");

assert.deepStrictEqual(
  contributorDoc({ name: " Ada O. ", role: "teacher", credential: "A1 Mathematics, WASSCE 2025" }).doc,
  { displayName: "Ada O.", role: "teacher", credential: "A1 Mathematics, WASSCE 2025" },
);
// Control: a credential is optional.
assert.deepStrictEqual(contributorDoc({ name: "Tunde", role: "student" }).doc, {
  displayName: "Tunde", role: "student", credential: "",
});
assert.ok(contributorDoc({ name: "", role: "teacher" }).error);
assert.ok(contributorDoc({ name: "Ada", role: "principal" }).error);
assert.ok(contributorDoc({ name: "x".repeat(41), role: "team" }).error);
assert.ok(contributorDoc({ name: "Ada", role: "team", credential: "y".repeat(81) }).error);
console.log("set_contributor: all checks passed");
