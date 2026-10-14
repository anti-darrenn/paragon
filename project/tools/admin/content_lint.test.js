// node content_lint.test.js — checks the pure rules of content_lint.js.
const assert = require("assert");
const { problemsFor } = require("./content_lint");

const article = (title, body = "Some text.") => ({ type: "article", title, body });

// Control: real titles pass, including ones with "test" or "sample" in them.
for (const t of ["Laws of indices", "Tests for divisibility", "Sample space and events", "Testing a hypothesis"]) {
  assert.deepStrictEqual(problemsFor(article(t)), [], t);
}
// The placeholders that reached students.
for (const t of ["test2", "test_article", "Sample", "Lorem ipsum", "untitled", "new_video_1"]) {
  assert.strictEqual(problemsFor(article(t)).length, 1, t);
}
// Body and link rules.
assert.strictEqual(problemsFor(article("Indices", "")).length, 1);
assert.strictEqual(problemsFor({ type: "video", title: "Indices" }).length, 1);
assert.deepStrictEqual(problemsFor({ type: "video", title: "Indices", youtubeId: "abc" }), []);
// Maths.
assert.deepStrictEqual(problemsFor(article("Indices", String.raw`Inline \(x^2\) and $$\frac{a}{b}$$ and \$5.`)), []);
assert.strictEqual(problemsFor(article("Indices", String.raw`Bad \(\frac{1}\) maths`)).length, 1);
assert.strictEqual(problemsFor(article("Indices", String.raw`Open \( never closed`)).length, 1);

console.log("content_lint: all checks passed");
