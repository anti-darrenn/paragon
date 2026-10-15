// node render.test.js — checks the pure rendering of the static pages.
const assert = require("assert");
const { renderRich, plainText, slugify, truncate, quizJsonLd, escapeHtml } = require("./render");

// Control: plain text passes through, escaped.
assert.strictEqual(renderRich("2 < 3 & 4 > 1"), "2 &lt; 3 &amp; 4 &gt; 1");

// Inline maths becomes KaTeX HTML; the source text around it survives.
const inline = renderRich(String.raw`If F = \(\frac{9}{5}C + 32\), find C.`);
assert.ok(inline.startsWith("If F = "), inline.slice(0, 40));
assert.ok(inline.includes('class="katex"'));
assert.ok(inline.endsWith(", find C."));
// The fraction is in the MathML too, which is what a screen reader reads
// (the reviewer's F9: the app dropped "9/5" from accessible text).
assert.ok(inline.includes("<mfrac>"));

// Display maths in both spellings.
assert.ok(renderRich(String.raw`\[x^2\]`).includes("katex-display"));
assert.ok(renderRich("$$x^2$$").includes("katex-display"));

// A lone $ is money, not maths.
assert.strictEqual(renderRich("It costs $5 and $10."), "It costs $5 and $10.");
assert.strictEqual(renderRich(String.raw`Pay \$5`), "Pay $5");

// Text macros outside maths, as FullLatexView renders them.
assert.strictEqual(renderRich(String.raw`\textbf{Note}: \textit{x}`), "<strong>Note</strong>: <em>x</em>");

// Broken maths shows its source, never throws or vanishes.
assert.ok(renderRich(String.raw`\(\frac{1}\)`).includes("tex-error"));

// An unclosed delimiter is just text.
assert.strictEqual(renderRich(String.raw`a \( b`), String.raw`a \( b`);

// No HTML injection through question text or maths.
assert.ok(!renderRich("<script>alert(1)</script>").includes("<script>"));
assert.ok(!renderRich(String.raw`\(\text{<img src=x>}\)`).includes("<img"));

assert.strictEqual(plainText(String.raw`If \(x^2 = 4\), find \textbf{x}.`), "If x^2 = 4, find x.");
assert.strictEqual(slugify("Further Mathematics"), "further-mathematics");
assert.strictEqual(slugify("  Laws of Indices & Logs "), "laws-of-indices-logs");
assert.strictEqual(truncate("short", 60), "short");
assert.ok(truncate("word ".repeat(30), 20).length <= 20);
assert.strictEqual(escapeHtml(`"x"`), "&quot;x&quot;");

// JSON-LD: the accepted answer is the right one, and is not also suggested.
const ld = quizJsonLd({
  q: { year: 2018, text: "2+2?", options: ["3", "4", "5", "6"], correctIndex: 1, explanation: "" },
  subjectName: "Mathematics",
  url: "https://x/y",
});
const part = ld.hasPart[0];
assert.strictEqual(part.acceptedAnswer.text, "B. 4");
assert.strictEqual(part.suggestedAnswer.length, 3);
assert.ok(!part.suggestedAnswer.some((a) => a.text === "B. 4"));

console.log("render: all checks passed");
