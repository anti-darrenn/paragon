// node apply_roles.test.js — checks the pure claim logic of apply_roles.js.
const assert = require("assert");
const { nextClaims, isLowered } = require("./apply_roles");

// Granting.
assert.deepStrictEqual(nextClaims({}, "writer", []), { writer: true });
assert.deepStrictEqual(nextClaims({}, "reviewer", ["m1", "p1"]), { reviewer: true, subjects: ["m1", "p1"] });

// Changing role replaces the old one and its subject limit.
assert.deepStrictEqual(nextClaims({ writer: true, subjects: ["m1"] }, "reviewer", []), { reviewer: true });

// Removing clears role and limit.
assert.deepStrictEqual(nextClaims({ reviewer: true, subjects: ["m1"] }, "none", ["m1"]), {});

// Control: admin and unrelated claims are never touched.
assert.deepStrictEqual(nextClaims({ admin: true, other: 1 }, "none", []), { admin: true, other: 1 });
assert.deepStrictEqual(nextClaims({ admin: true }, "writer", []), { admin: true, writer: true });

// Lowering.
assert.strictEqual(isLowered({ reviewer: true }, { writer: true }), true);
assert.strictEqual(isLowered({ writer: true }, {}), true);
assert.strictEqual(isLowered({ writer: true }, { writer: true, subjects: ["m1"] }), true);
assert.strictEqual(isLowered({ writer: true, subjects: ["m1", "p1"] }, { writer: true, subjects: ["m1"] }), true);
// Control: raising or widening is not lowering.
assert.strictEqual(isLowered({ writer: true }, { reviewer: true }), false);
assert.strictEqual(isLowered({ writer: true, subjects: ["m1"] }, { writer: true }), false);
assert.strictEqual(isLowered({ writer: true, subjects: ["m1"] }, { writer: true, subjects: ["m1", "p1"] }), false);

console.log("apply_roles: all checks passed");
