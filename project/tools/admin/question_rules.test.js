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
// "Three-figure bearing" and "four-figure tables" name no picture.
assert.ok(!rules({ text: "Express the direction S47°W as a three-figure bearing." }).includes("diagram-missing"));
assert.ok(rules({ text: "The figure shows a triangle; find x" }).includes("diagram-missing"));
assert.ok(rules({ text: "Find \\(\\fra{1}{2}\\)" }).includes("raw-latex-question"));
// A bare maths command renders since normalizeTex (2026-10-17), so it is no
// longer a finding; a bare command nothing can draw still is (the control).
assert.ok(!rules({ text: "Find \\frac{1}{2}" }).includes("raw-latex-question"));
assert.ok(!rules({ text: "Express 0.\\overline{3} as a fraction" }).includes("raw-latex-question"));
assert.ok(rules({ text: "Find \\notacommand{1}" }).includes("raw-latex-question"));
assert.ok(!rules({ text: "It costs \\$5" }).includes("raw-latex-question"));
assert.ok(rules({ text: "Q", explanation: "" }).includes("missing-explanation"));

// ─── Answer suspects (Plan v2 §2.3) ──
// The 2018 Mathematics question as stored: 68/111 is 0.612 recurring.
const p612 = {
  text: "Expression 0.612 in the form \\(\\frac{x}{y}\\), where x and y are integers and y \\(\\neq\\) 0",
  options: ["\\(\\frac{153}{250}\\)", "\\(\\frac{68}{111}\\)", "\\(\\frac{61}{100}\\)", "\\(\\frac{21}{33}\\)"],
  correctIndex: 0,
};
assert.ok(rules(p612).includes("recurring-decimal-suspect"));
// Fixed the way a reviewer fixes it — the recurring digits marked in the
// stem, the matching answer marked — and the suspect clears.
assert.ok(!rules({
  ...p612,
  text: "Express 0.\\overline{612} in the form \\(\\frac{x}{y}\\), where x and y are integers and y \\(\\neq\\) 0",
  correctIndex: 1,
}).includes("recurring-decimal-suspect"));
assert.ok(!rules({
  ...p612,
  text: "Express \\(0.\\dot{6}1\\dot{2}\\) in the form \\(\\frac{x}{y}\\)",
  correctIndex: 1,
}).includes("recurring-decimal-suspect"));
assert.ok(rules(p612).includes("stem-typo"));
assert.match(R.recurringSuspect(p612), /B is 0\.\(612\) recurring; marked A/);
// Control: no option is the recurring reading.
assert.ok(!rules({ ...p612, options: ["\\(\\frac{153}{250}\\)", "\\(\\frac{3}{5}\\)", "\\(\\frac{61}{100}\\)", "\\(\\frac{21}{33}\\)"] }).includes("recurring-decimal-suspect"));
// 0.1(6) is 1/6: a single repeating digit.
assert.ok(R.recurringSuspect({ text: "Express 0.16 as a fraction", options: ["4/25", "1/6", "1/5", "2/9"], correctIndex: 0 }));
assert.ok(!rules({ ...p612, text: "Express 0.612 in the form x/y" }).includes("stem-typo"));

assert.strictEqual(R.numericValue("\\(\\frac{68}{111}\\)"), 68 / 111);
assert.strictEqual(R.numericValue("-1\\(\\frac{1}{2}\\)"), -1.5); // the corpus's "-1\(\frac12\)"
assert.strictEqual(R.numericValue("\\(-1\\frac{1}{2}\\)"), -1.5);
assert.strictEqual(R.numericValue("\\(3.4 \\times 10^{-3}\\)"), 3.4e-3);
assert.strictEqual(R.numericValue("0.0080 kg"), 0.008);
assert.strictEqual(R.numericValue("4x-4"), null);
assert.strictEqual(R.numericValue("12,345"), 12345);
assert.strictEqual(R.roundDecimal("0.0125", 3), 0.013);
assert.strictEqual(R.roundSignificant("0.007985", 3), 0.00799);
assert.strictEqual(R.roundSignificant("398753", 3), 399000);

// The significant-figures question the reviewer sampled: B is right.
const sf = { text: "Correct 0.007985 to three significant figures", options: ["0.008", "0.00799", "0.00798", "0.0080"], correctIndex: 1 };
assert.ok(!rules(sf).includes("answer-mismatch-suspect"));
assert.ok(!rules(sf).includes("diagram-missing"));
assert.match(R.answerMismatch({ ...sf, correctIndex: 2 }), /computed 0\.00799: that is B, marked C/);
// 0.0080 has 2 figures, so it is not the 3-figure answer even though it equals 0.008.
assert.deepStrictEqual(R.roundingAnswer({ ...sf, text: "Correct 0.007985 to 1 significant figure" }).matches, [0]);
assert.deepStrictEqual(R.roundingAnswer({ ...sf, text: "Correct 0.007985 to 2 significant figures" }).matches, [3]);
// Arithmetic in the stem is not this check's to work out.
assert.strictEqual(R.roundingAnswer({ text: "Simplify 0.63954 ÷ 0.003 correct to two significant figures", options: ["210", "213"], correctIndex: 0 }), null);
// Standard form wants 1 ≤ a < 10.
assert.deepStrictEqual(
  R.roundingAnswer({ text: "Express 0.0462 in standard form", options: ["\\(0.462 \\times 10^{-1}\\)", "\\(4.62 \\times 10^{-2}\\)", "\\(4.62 \\times 10^{2}\\)"], correctIndex: 1 }).matches,
  [1],
);

assert.ok(rules({ text: "Q", options: ["\\(-\\frac{3}{2}\\)", "\\(-1\\frac{1}{2}\\)", "2", "3"] }).includes("equivalent-options"));
assert.ok(!rules({ text: "Q", options: ["4 nodes", "4 antinodes", "2", "3"] }).includes("equivalent-options"));
assert.ok(!rules({ text: "Correct 0.0080 to 2 significant figures", options: ["0.008", "0.0080", "1", "2"] }).includes("equivalent-options"));
assert.ok(rules({ text: "Q", correctIndex: 4 }).includes("answer-out-of-range"));
assert.ok(!rules({ text: "Q", correctIndex: -1 }).includes("answer-out-of-range"));

assert.ok(rules({ text: "Evaluate 2^(x+1)" }).includes("needs-latex-question"));
assert.ok(rules({ text: "Convert 32_four to base ten" }).includes("needs-latex-question"));
assert.ok(rules({ text: "Find 3 x 4" }).includes("needs-latex-question"));
assert.ok(!rules({ text: "Evaluate \\(2^{x+1}\\) if x = 2" }).includes("needs-latex-question"));
assert.ok(!rules({ text: "Find x if 3x = 4" }).includes("needs-latex-question"));

assert.ok(rules({ text: "Correct 2.346 to three significant figures", explanation: "To two significant figures, 2.3" }).includes("explanation-mismatch"));
assert.ok(!rules({ text: "Correct 2.346 to three significant figures", explanation: "To three significant figures, 2.35" }).includes("explanation-mismatch"));

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
