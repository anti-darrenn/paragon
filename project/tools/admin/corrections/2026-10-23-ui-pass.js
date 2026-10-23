// Found during the 2026-10-23 UI pass, in the five-question taster: the 1997
// Mathematics triangle question. Its worked answer lost its powers (13² read as
// "132") and repeated its first line at the end; the stem ran two sentences
// together. The diagram also carries another site's watermark, which a
// correction cannot fix: the vetNote asks for a clean diagram in the studio.
//
// Checked by hand: XM = √(13² − 5²) = √144 = 12; MZ = √(15² − 12²) = √81 = 9;
// YZ = YM + MZ = 5 + 9 = 14, option C, which is the key already.
//
//   node apply_corrections.js --file=corrections/2026-10-23-ui-pass.js           # dry run
//   node apply_corrections.js --file=corrections/2026-10-23-ui-pass.js --commit  # after review
module.exports = [
  {
    "id": "7Rdz7QfLXXNefsSqc6mo",
    "field": "text",
    "set": "In triangle XYZ, XM is the altitude from X to YZ. XY = 13 cm, XZ = 15 cm and YM = 5 cm. Find the length of YZ."
  },
  {
    "id": "7Rdz7QfLXXNefsSqc6mo",
    "field": "explanation",
    "set": "\\(XM = \\sqrt{13^2 - 5^2} = \\sqrt{144} = 12\\) cm\n\n\\(MZ = \\sqrt{15^2 - 12^2} = \\sqrt{81} = 9\\) cm\n\n\\(YZ = YM + MZ = 5 + 9 = 14\\) cm"
  },
  {
    "id": "7Rdz7QfLXXNefsSqc6mo",
    "field": "vetNote",
    "set": "Fixed in the UI pass, waiting for your approval: rewrote the worked answer (13² had become 132, and the first line repeated at the end) and tidied the stem. C stays. The diagram shows myschool.ng's watermark: upload a clean drawing in the workbench."
  }
];
