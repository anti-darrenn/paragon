// node question_rules.test.js — the content checks and mechanical fixes.
const assert = require("assert");
const R = require("./question_rules");

const fix = (t, subject = "Physics") => R.fixQuestion({ text: t, options: [], explanation: "" }, subject).text;

// ─── Powers of ten (audit A3) ──
assert.strictEqual(R.fixPowersOfTen("4 x 10-3 m"), "\\(4 \\times 10^{-3}\\) m");
assert.strictEqual(R.fixPowersOfTen("G = 6.67x10-11"), "G = \\(6.67 \\times 10^{-11}\\)");
assert.strictEqual(R.fixPowersOfTen("3.0 x108"), "\\(3.0 \\times 10^{8}\\)");
assert.strictEqual(R.fixPowersOfTen("1.6  x 10-2J"), "\\(1.6 \\times 10^{-2}\\)J");
assert.strictEqual(R.fixPowersOfTen("area 4 π x 10-8"), "area \\(4 \\pi \\times 10^{-8}\\)");
// Control: subtraction and ordinary multiplication stay.
assert.strictEqual(R.fixPowersOfTen("2 x 10 - 3 = 17"), "2 x 10 - 3 = 17");
assert.strictEqual(R.fixPowersOfTen("5 x 1000"), "5 x 1000");
assert.strictEqual(R.fixPowersOfTen("12 x 10"), "12 x 10");

// ─── Units (B7): only real units after a number; algebra untouched ──
assert.strictEqual(R.fixUnits("462 cm3"), "462 \\(\\mathrm{cm^{3}}\\)");
assert.strictEqual(R.fixUnits("330ms-1."), "330 \\(\\mathrm{m\\,s^{-1}}\\).");
assert.strictEqual(R.fixUnits("is 4200 Jkg-1K-1"), "is 4200 \\(\\mathrm{J\\,kg^{-1}\\,K^{-1}}\\)");
assert.strictEqual(R.fixUnits("2 Ω-1cm-1"), "2 \\(\\mathrm{\\Omega^{-1}\\,cm^{-1}}\\)");
assert.strictEqual(R.fixUnits("x-3 and n-1 and 2x-3"), "x-3 and n-1 and 2x-3");
assert.strictEqual(R.fixUnits("Nm2kg-2"), "Nm2kg-2"); // not after a number: left alone
assert.strictEqual(R.fixUnits("ms-1", true), " \\(\\mathrm{m\\,s^{-1}}\\)"); // right after maths
// Through fixQuestion, a unit after a converted power is converted too.
assert.strictEqual(fix("3.00 x 108ms-1"), "\\(3.00 \\times 10^{8}\\) \\(\\mathrm{m\\,s^{-1}}\\)");

// ─── Degrees (B6) ──
assert.strictEqual(R.fixDegrees("angle 30o, and 042o"), "angle \\(30^\\circ\\), and \\(042^\\circ\\)");
assert.strictEqual(R.fixDegrees("at 10oC"), "at \\(10^\\circ\\)C");
assert.strictEqual(R.fixDegrees("latitude 60oS"), "latitude \\(60^\\circ\\)S");
assert.strictEqual(R.fixDegrees("120o\\(180^\\circ\\)"), "\\(120^\\circ\\)\\(180^\\circ\\)");
assert.strictEqual(R.fixUnits("area 39cm2?"), "area 39 \\(\\mathrm{cm^{2}}\\)?");
assert.strictEqual(R.fixDegrees("2 of them"), "2 of them"); // control

// ─── Naira (B11): maths subjects only ──
assert.strictEqual(fix("costs N2,500.50", "Mathematics"), "Costs ₦2,500.50");
// (A one-letter first word could be a variable, so it is not capitalised.)
assert.strictEqual(fix("a force of N2", "Physics"), "a force of N2");

// ─── Typos, OCR, first letter (B9, B10) ──
assert.strictEqual(fix("simplfy the lenght"), "Simplify the length");
assert.strictEqual(fix("lf sin θ = 1"), "If sin θ = 1");
assert.strictEqual(fix("ln the diagram"), "In the diagram");
assert.strictEqual(R.fixTypos("ln x + ln y"), "ln x + ln y"); // control: the natural log
assert.strictEqual(fix("x + 2 = 5"), "x + 2 = 5"); // a variable is not capitalised

// ─── Never inside maths ──
assert.strictEqual(R.mapText("\\(30o\\) and 30o", R.fixDegrees), "\\(30o\\) and \\(30^\\circ\\)");
assert.strictEqual(R.splitMath("a \\(b\\) c").map((p) => p.raw).join(""), "a \\(b\\) c");

// ─── Checks ──
const rules = (q) => R.checkQuestion({ options: ["1", "2", "3", "4"], explanation: "x", ...q }).map((f) => f.rule);
assert.ok(rules({ text: "Q", options: ["23", "17", "-17", "17"] }).includes("duplicate-options"));
assert.ok(!rules({ text: "Q", options: ["17", "-17", "\\(\\frac{1}{2}\\)", "12"] }).includes("duplicate-options"));
assert.ok(!rules({ text: "Q", options: ["d = t", "d = T", "a", "b"] }).includes("duplicate-options"));
assert.ok(rules({ text: "Q", options: ["a", "b", "c"] }).includes("too-few-options"));
assert.ok(rules({ text: "Find 4 x 10-3" }).includes("lost-negative-power"));
assert.ok(rules({ text: "In the diagram, find x" }).includes("diagram-missing"));
assert.ok(!rules({ text: "In the diagram, find x", imageId: "a" }).includes("diagram-missing"));
assert.ok(!rules({ text: "Correct 0.002473 to 3 significant figures" }).includes("diagram-missing"));
assert.ok(rules({ text: "Find \\(\\fra{1}{2}\\)" }).includes("raw-latex-question"));
assert.ok(rules({ text: "Find \\frac{1}{2}" }).includes("raw-latex-question"));
assert.ok(!rules({ text: "It costs \\$5" }).includes("raw-latex-question"));
assert.ok(rules({ text: "Q", explanation: "" }).includes("missing-explanation"));

const q = (id, year, text, options = ["a", "b", "c", "d"]) => ({ id, year, subjectId: "s", text, options });
const corpus = R.checkCorpus([
  q("1", 2007, "Find x if 2x = 4"),
  q("2", 2007, "Find  x if 2x = 4"),
  q("3", 2007, "Something else entirely"),
  q("4", 2006, "Something else entirely"),
]);
assert.deepStrictEqual(corpus.exact, [["1", "2"]]);
assert.strictEqual(corpus.repeats.length, 1);

console.log("question rules: all checks passed");
