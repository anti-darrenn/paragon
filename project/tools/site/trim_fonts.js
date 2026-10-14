/**
 * Drops the KaTeX font families Paragon never uses from the web build.
 *
 * Flutter web downloads every font in `assets/FontManifest.json` at
 * startup, and `flutter_math_fork` declares all twenty KaTeX files, so the
 * first visit fetched Fraktur and Script for maths no question contains
 * (the live-site review counted ~20 font requests; PLAN.md P4.3). A
 * package's fonts cannot be excluded in pubspec, so this edits the built
 * manifest instead and deletes the files.
 *
 * Dropped: Caligraphic, Fraktur, SansSerif, Script, Typewriter — 233 KB,
 * 9 requests. On 2026-10-14 the whole corpus, every generator and every
 * lesson had no \mathcal, \mathfrak, \mathscr, \mathsf, \textsf, \texttt
 * or \mathtt (with a control: 66k \frac found the same way). The editor
 * and content_lint.js warn if an author uses one (`DROPPED_COMMANDS`);
 * rendered anyway, it falls back to the main font rather than failing.
 *
 * Kept: Main, Math, AMS (\mathbb and many symbols) and Size1–4 (large
 * brackets and roots).
 */
const fs = require("fs");
const path = require("path");

const DROPPED_FAMILIES = ["Caligraphic", "Fraktur", "SansSerif", "Script", "Typewriter"];
const DROPPED_COMMANDS = ["mathcal", "mathfrak", "mathscr", "mathsf", "textsf", "texttt", "mathtt"];

function trimFonts(buildDir) {
  const manifestPath = path.join(buildDir, "assets", "FontManifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const drop = (family) =>
    DROPPED_FAMILIES.some((f) => family === `packages/flutter_math_fork/KaTeX_${f}`);
  let bytes = 0;
  let files = 0;
  for (const entry of manifest.filter((e) => drop(e.family))) {
    for (const font of entry.fonts) {
      const file = path.join(buildDir, "assets", font.asset);
      if (fs.existsSync(file)) {
        bytes += fs.statSync(file).size;
        fs.rmSync(file);
        files++;
      }
    }
  }
  const kept = manifest.filter((e) => !drop(e.family));
  fs.writeFileSync(manifestPath, JSON.stringify(kept));
  return { files, bytes, families: manifest.length - kept.length };
}

module.exports = { trimFonts, DROPPED_FAMILIES, DROPPED_COMMANDS };
