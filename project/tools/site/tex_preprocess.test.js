// node tex_preprocess.test.js — the JS mirror gives the app's output for
// every shared case (test/fixtures/tex_preprocess_cases.json), is
// idempotent, and its maths renders in KaTeX.
const assert = require("assert");
const path = require("path");
const katex = require("katex");
const { normalizeTex, dollarMathToParens } = require("./tex_preprocess");

const cases = require(path.join(__dirname, "../../test/fixtures/tex_preprocess_cases.json"));
const SPAN = /\\\(([\s\S]*?)\\\)|\\\[([\s\S]*?)\\\]|\$\$([\s\S]*?)\$\$/g;

assert.ok(cases.length >= 40, "the shared fixture is present");
for (const c of cases) {
  const out = normalizeTex(c.in);
  assert.strictEqual(out, c.out, `mirror differs for: ${c.in}`);
  assert.strictEqual(normalizeTex(out), out, `not idempotent: ${c.in}`);
  for (const m of out.matchAll(SPAN)) {
    const tex = m[1] ?? m[2] ?? m[3];
    assert.doesNotThrow(
      () => katex.renderToString(tex, { throwOnError: true, strict: "ignore" }),
      `KaTeX cannot render: ${tex}`,
    );
  }
}

// Control: a string with no backslash is returned as it is.
assert.strictEqual(normalizeTex("A blank ------ costs $5"), "A blank ------ costs $5");

assert.strictEqual(dollarMathToParens("Let $x^2$ be"), String.raw`Let \(x^2\) be`);
assert.strictEqual(dollarMathToParens("costs $5"), String.raw`costs \$5`);

console.log(`tex_preprocess: ${cases.length} shared cases match the app`);
