// node explanation_report.test.js
const assert = require("assert");
const { classify, summarise, fromHtml } = require("./explanation_report");

const source = {
  mathematics: [
    { year: 2018, questionHtml: "<p>Expression 0.612 in the form \\(\\frac{x}{y}\\)</p>", explanationHtml: "<p>0.612 = \\(\\frac{612}{1000}\\)</p><p>= \\(\\frac{153}{250}\\)</p>" },
    { year: 2018, questionHtml: "<p>A car of mass 4 x 10-3 kg moves with a uniform speed of 2 m/s along a straight road. Find its momentum</p>", explanationHtml: "<p>Multiply the numbers and keep the power of ten.</p>" },
  ],
};
const subjectName = { m: "Mathematics" };
const q = (id, text, explanation) => ({ id, subjectId: "m", year: 2018, topicId: "t", text, explanation });
const rows = classify(
  [
    q("copied", "Expression 0.612 in the form \\(\\frac{x}{y}\\)", "0.612 = \\(\\frac{612}{1000}\\)\n= \\(\\frac{153}{250}\\)"),
    // The stem was fixed (10-3 → 10^{-3}), so only the fuzzy match finds it.
    q("fixed", "A car of mass \\(4 \\times 10^{-3}\\) kg moves with a uniform speed of 2 m/s along a straight road. Find its momentum", "Multiply the numbers and keep the power of ten."),
    q("rewritten", "Expression 0.612 in the form \\(\\frac{x}{y}\\)", "Read 0.612 as recurring: let r be the number, so 1000r - r = 612, r = 68/111."),
    q("empty", "Something", ""),
    q("nowhere", "A stem the source never had", "An explanation"),
  ],
  subjectName,
  { t: "Fractions" },
  source,
);
const origin = Object.fromEntries(rows.map((r) => [r.id, r.explanationOrigin]));
assert.deepStrictEqual(origin, { copied: "imported", fixed: "imported", rewritten: "rewritten", empty: "none", nowhere: "unknown" });
assert.strictEqual(rows[0].topic, "Fractions");
assert.strictEqual(rows[0].explanationHasLatex, true);
assert.strictEqual(rows[1].explanationHasLatex, false);
assert.deepStrictEqual(summarise(rows).Mathematics[2018], { total: 5, none: 1, imported: 2, rewritten: 1, unknown: 1 });
assert.strictEqual(fromHtml("<p>a &amp; b</p>").trim(), "a & b");

console.log("explanation_report: ok");
