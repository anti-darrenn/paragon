// Follow-ups found after the first passes on 15 Oct 2026. Applied by
// apply_corrections.js.
const r = String.raw;
const NAIRA = r`(^|[^A-Za-z0-9])N(\d[\d,]*(?:\.\d+)?)`;

module.exports = [
  // Electricity bills in Physics are in naira. fix_questions converts
  // naira in maths subjects only, because elsewhere in Physics "N2" is a
  // newton or a node.
  { id: "Ujb50nBnmu6jZF6Yexzs", field: "all", regex: NAIRA, replace: "$1₦$2" },
  { id: "V31mzZkGGmUltjl0tXLk", field: "all", regex: NAIRA, replace: "$1₦$2" },
  { id: "XEFeYXgZ4yLRBGai5QvW", field: "all", regex: NAIRA, replace: "$1₦$2" },
  { id: "jzJuiVCyRS6ixDp5oyji", field: "all", regex: NAIRA, replace: "$1₦$2" },
  // The instruction was typeset inside the maths, so it read in italics
  // with no spaces.
  {
    id: "a7iaToGEpgQqt0kLCPbX",
    field: "text",
    find: r`\(Differentiate f (x) = \frac{1}{(1 - x^2)^5}\)`,
    replace: r`Differentiate \(f(x) = \frac{1}{(1 - x^2)^5}\)`,
  },
];
