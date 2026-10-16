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

// ─── plainMath: readable maths in titles, previews and JSON-LD (B3, B4) ──
const { plainMath, page, breadcrumbJsonLd, itemListJsonLd } = require("./render");
const pm = (s) => plainMath(s);
assert.strictEqual(pm(String.raw`Simplify \(\frac{2x-1}{x+3}\)`), "Simplify (2x-1)/(x+3)");
assert.strictEqual(pm(String.raw`Evaluate \(3\sqrt{45}\)`), "Evaluate 3√45");
assert.strictEqual(pm(String.raw`\(\sqrt{x+1}\)`), "√(x+1)");
assert.strictEqual(pm(String.raw`\(x^2 + y^{3}\)`), "x² + y³");
assert.strictEqual(pm(String.raw`\(2^{x+1}\)`), "2ˣ⁺¹");
assert.strictEqual(pm(String.raw`\(e^{\pi}\)`), "e^π");
assert.strictEqual(pm(String.raw`\(4 \times 10^{-3}\) m`), "4 × 10⁻³ m");
assert.strictEqual(pm(String.raw`\(30^\circ\)`), "30°");
assert.strictEqual(pm(String.raw`\(\angle PQR = 60^{\circ}\)`), "∠PQR = 60°");
assert.strictEqual(pm(String.raw`\(\theta \le \pi\)`), "θ ≤ π");
assert.strictEqual(pm(String.raw`\(\log_{10} 100\)`), "log₁₀ 100");
assert.strictEqual(pm(String.raw`\(\frac{\frac{1}{2}}{3}\)`), "(1/2)/3");
assert.strictEqual(pm(String.raw`\(\left( \frac{a}{b} \right)\)`), "( a/b )");
assert.strictEqual(pm(String.raw`\(\text{area} = \pi r^2\)`), "area = πr²");
// Unknown commands keep their name rather than vanishing.
assert.strictEqual(pm(String.raw`\(\sin x\)`), "sin x");
// Stray TeX outside delimiters (some scraped text has it) is converted too.
assert.strictEqual(pm(String.raw`Find \frac{1}{2} of 8`), "Find 1/2 of 8");
// Control: money and plain text are untouched; no TeX survives anywhere.
assert.strictEqual(pm("It costs $5 and $10."), "It costs $5 and $10.");
assert.strictEqual(pm("The diagonals of a rhombus are 16 cm"), "The diagonals of a rhombus are 16 cm");
assert.ok(!/\\[a-zA-Z]/.test(pm(String.raw`\(\frac{a}{b}\) and \(\sqrt[3]{x}\)`)));
// Truncating after conversion cannot cut a fraction in half.
const long = truncate(pm(String.raw`Find the value of \(\frac{2x-1}{x+3}\) when x is ` + "very ".repeat(20)), 40);
assert.ok(!long.includes("\\"), long);

// JSON-LD text is plain maths, and Quiz.name is the page's title (E9).
const ld2 = quizJsonLd({
  q: { year: 2019, text: String.raw`Simplify \(\frac{1}{2}\)`, options: [String.raw`\(x^2\)`, "b"], correctIndex: 0, explanation: String.raw`\(\sqrt{4} = 2\)` },
  subjectName: "Mathematics",
  url: "https://x/y",
  name: "WAEC 2019 Mathematics: Simplify 1/2",
});
assert.strictEqual(ld2.name, "WAEC 2019 Mathematics: Simplify 1/2");
assert.strictEqual(ld2.hasPart[0].text, "Simplify 1/2");
assert.strictEqual(ld2.hasPart[0].acceptedAnswer.text, "A. x²");
assert.strictEqual(ld2.hasPart[0].acceptedAnswer.answerExplanation.text, "√4 = 2");

// The page shell: og:image on every page (E1), several JSON-LD blocks, and
// noindex pages carry no canonical.
const html = page({
  title: "T", description: "D", canonical: "https://x/", body: "", root: "/",
  jsonLd: [breadcrumbJsonLd([["A", "https://x/a/"], ["B"]]), itemListJsonLd("L", ["https://x/1/"])],
});
assert.ok(html.includes(`property="og:image" content="${require("./origin").DEFAULT_ORIGIN}/og-image.jpg"`));
assert.ok(html.includes('name="twitter:card" content="summary_large_image"'));
assert.strictEqual((html.match(/application\/ld\+json/g) || []).length, 2);
assert.ok(html.includes('"@type":"BreadcrumbList"') && html.includes('"position":2'));
assert.ok(html.includes('href="/terms/"'));
assert.ok(!html.includes("checked by students and our team"));
const nf = page({ title: "T", description: "D", canonical: "https://x/", body: "", root: "/", noindex: true });
assert.ok(nf.includes('content="noindex"') && !nf.includes('rel="canonical"'));

console.log("render: all checks passed");
