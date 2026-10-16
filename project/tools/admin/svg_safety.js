/**
 * What makes an uploaded SVG unsafe to serve as a file.
 *
 * Inside the app an SVG is drawn by flutter_svg, which runs nothing. But
 * `build_static_site.js` writes question images to
 * `/past-questions/img/<id>.svg` on the app's own origin, and an SVG opened
 * directly is a document: a script in it would run with the origin's
 * storage, signed-in session included. So anything that can run, fetch or
 * expand is refused rather than cleaned — a diagram never needs any of it.
 *
 * Mirrored by `svgProblem` in lib/features/admin/studio/image_upload.dart,
 * which refuses the same things at upload. Change both together. Pure,
 * tested (svg_safety.test.js).
 */
const RULES = [
  [/<\s*script/i, "a <script> element"],
  [/<\s*foreignObject/i, "a <foreignObject> element"],
  [/<\s*(iframe|embed|object|audio|video)\b/i, "an embedded document or media element"],
  [/\son[a-z]+\s*=/i, "an event handler attribute (on…=)"],
  [/javascript\s*:/i, "a javascript: URL"],
  [/<!ENTITY/i, "an XML entity declaration"],
  // Links and images may point inside the file (#id) or at inline image
  // data, never at another host or scheme.
  [/(?:href|src)\s*=\s*["']?\s*(?!#|data:image\/)[a-z][a-z0-9+.-]*:/i, "a link to an external resource"],
  [/(?:href|src)\s*=\s*["']?\s*\/\//i, "a link to an external resource"],
  [/@import|url\(\s*["']?\s*(?:[a-z][a-z0-9+.-]*:|\/\/)(?!image\/)/i, "a stylesheet fetch from outside the file"],
];

/** The first reason [text] is unsafe, or null when it is a plain drawing. */
function svgProblem(text) {
  const s = String(text);
  if (!/<svg[\s>]/i.test(s)) return "not an SVG document";
  for (const [pattern, why] of RULES) {
    if (pattern.test(s)) return why;
  }
  return null;
}

module.exports = { svgProblem };
