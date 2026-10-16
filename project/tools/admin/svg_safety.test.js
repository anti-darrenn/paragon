// node svg_safety.test.js — what an uploaded SVG may not contain.
const assert = require("assert");
const { svgProblem } = require("./svg_safety");

const svg = (inner, attrs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 10 10"${attrs}>${inner}</svg>`;

// Refused.
for (const [why, text] of [
  ["script", svg("<script>alert(document.cookie)</script>")],
  ["script, spaced and upper case", svg("< SCRIPT>x</script>")],
  ["event handler", svg('<rect width="5" height="5" onclick="x()"/>')],
  ["event handler on the root", svg("", ' onload="x()"')],
  ["foreignObject", svg("<foreignObject><div>x</div></foreignObject>")],
  ["javascript: link", svg('<a xlink:href="javascript:alert(1)"><text>x</text></a>')],
  ["external image", svg('<image href="https://evil.example/pixel.png"/>')],
  ["protocol-relative image", svg('<image href="//evil.example/p.png"/>')],
  ["external use", svg('<use xlink:href="http://evil.example/s.svg#a"/>')],
  ["entity expansion", '<!DOCTYPE svg [<!ENTITY a "aaaa">]>' + svg("<text>&a;</text>")],
  ["css import", svg("<style>@import 'https://evil.example/x.css';</style>")],
  ["css url fetch", svg('<rect style="fill:url(https://evil.example/x)"/>')],
  ["iframe", svg('<iframe src="x"></iframe>')],
  ["not an svg", "<html><body>hi</body></html>"],
]) {
  assert.ok(svgProblem(text), `should refuse: ${why}`);
}

// Control: ordinary diagrams pass, namespaces and internal references included.
for (const [why, text] of [
  ["shapes and text", svg('<line x1="0" y1="0" x2="10" y2="10" stroke="black"/><text x="1" y="5">30°</text>')],
  ["internal use", svg('<defs><path id="a" d="M0 0L5 5"/></defs><use xlink:href="#a"/>')],
  ["gradient by url(#id)", svg('<defs><linearGradient id="g"/></defs><rect fill="url(#g)" width="5" height="5"/>')],
  ["inline png image", svg('<image href="data:image/png;base64,iVBORw0KGgo="/>')],
  ["opacity and offset attributes", svg('<stop offset="0" stop-opacity="0.5"/>')],
]) {
  assert.strictEqual(svgProblem(text), null, `should allow: ${why}`);
}

console.log("svg_safety: all checks passed");
