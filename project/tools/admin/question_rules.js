/**
 * Question-content rules: the checks from the 15 Oct 2026 audit, and the
 * mechanical fixes that are safe to apply without a person deciding.
 * Pure; no Firestore. `content_audit.js` reports with the checks,
 * `fix_questions.js` applies the fixes, `question_rules.test.js` pins both.
 *
 * Text follows the app's dialect (`FullLatexView`): maths is `\(…\)`,
 * `\[…\]` or `$$…$$`, and a lone `$` is a dollar sign. Fixes only ever
 * touch text *outside* maths, and only turn plain-text notation that
 * changes the meaning ("10-3" read as ten minus three) into maths.
 */
const katex = require("katex");

// KaTeX warns on every Unicode character it has no metrics for (º, ∆…);
// it still renders, so keep the reports readable.
const warn = console.warn;
console.warn = (...a) => {
  if (!String(a[0]).startsWith("No character metrics")) warn(...a);
};

// ─── Maths and text ──────────────────────────────────────────────────

/** [{math, text}] spans, in order; concatenating `raw` gives the input back. */
function splitMath(source) {
  const s = String(source ?? "");
  const out = [];
  let text = "";
  let i = 0;
  const flush = () => {
    if (text) out.push({ math: false, raw: text });
    text = "";
  };
  while (i < s.length) {
    if (s[i] === "\\" && s[i + 1] === "$") {
      text += "\\$";
      i += 2;
      continue;
    }
    const open = s[i] === "\\" && (s[i + 1] === "(" || s[i + 1] === "[") ? s.slice(i, i + 2) : s.startsWith("$$", i) ? "$$" : null;
    if (open) {
      const close = open === "\\(" ? "\\)" : open === "\\[" ? "\\]" : "$$";
      const end = s.indexOf(close, i + 2);
      if (end > i + 1) {
        flush();
        out.push({ math: true, raw: s.slice(i, end + 2), tex: s.slice(i + 2, end) });
        i = end + 2;
        continue;
      }
    }
    text += s[i];
    i++;
  }
  flush();
  return out;
}

/** Applies [fn] to the text outside maths only. [fn] also learns whether
 *  maths comes straight before the text (`\(3 \times 10^{8}\)ms-1`). */
function mapText(source, fn) {
  const parts = splitMath(source);
  return parts
    .map((p, i) => (p.math ? p.raw : fn(p.raw, i > 0 && parts[i - 1].math)))
    .join("");
}

const textOnly = (source) => splitMath(source).filter((p) => !p.math).map((p) => p.raw).join(" ");

// ─── Mechanical fixes ────────────────────────────────────────────────

/** `4 x 10-3` → `\(4 \times 10^{-3}\)`; `3.0 x108` → `\(3.0 \times 10^{8}\)`.
 *  Negative powers need the minus right after the 10 ("10-3", never
 *  "10 - 3", which is subtraction); positive ones a power of 1-99. */
function fixPowersOfTen(t) {
  // The scraped text has any number of spaces ("1.6  x 10-2"), and π can
  // stand in front ("4 π x 10-8").
  return t
    .replace(/(\d+(?:\.\d+)?(?:\s?π)?|π)\s*[x×X]\s*10-(\d{1,2})(?!\d)/g, (m, a, p) => `\\(${a.replace("π", "\\pi")} \\times 10^{-${p}}\\)`)
    .replace(/(\d+(?:\.\d+)?)\s*[x×X]\s*10([1-9]\d?)(?![\d.,])/g, "\\($1 \\times 10^{$2}\\)");
}

// Unit symbols, longest first, for splitting "Jkg-1K-1" into J kg⁻¹ K⁻¹.
const UNIT_SYMBOLS = ["mol", "rad", "kg", "km", "cm", "mm", "Kg", "Ω", "m", "s", "K", "N", "J", "C", "V", "g", "h", "k"];
// Compound units as they appear in the corpus. A whitelist, because
// "x-3" and "n-1" are algebra and must never be touched.
const UNIT_TOKENS = new Set([
  "cm2", "cm3", "m2", "m3", "km2", "mm2", "mm3", "cm-3", "cm-1", "ms-1", "ms-2", "s-1", "K-1",
  "Nm-2", "Nm-1", "Jkg-1K-1", "Jkg-1k-1", "JKg-1", "Jkg-1", "kgms-1", "kgms-2", "Vm-1", "NC-1",
  "kg-1", "kg-2", "Jg-1", "Jg-1K-1", "Jg-1k-1", "kgm-3", "Kgm-3", "m-2", "m-3", "m-1", "gcm-3",
  "kg-1K-1", "kmh-1", "rads-1", "Ω-1cm-1", "Ω-1", "Ωm", "Nm2kg-2", "Nm-2kg-2", "Nm2C-2", "Js-1",
  "JK-1", "m-1s-2", "m-2s-2", "mol-1",
]);

function unitToTex(token) {
  const parts = [];
  let rest = token;
  while (rest) {
    const sym = UNIT_SYMBOLS.find((u) => rest.startsWith(u));
    if (!sym) return null;
    rest = rest.slice(sym.length);
    const exp = /^-?\d/.exec(rest);
    const power = exp ? exp[0] : "";
    rest = rest.slice(power.length);
    const name = sym === "Ω" ? "\\Omega" : sym === "Kg" ? "kg" : sym;
    parts.push(power ? `${name}^{${power}}` : name);
  }
  return `\\(\\mathrm{${parts.join("\\,")}}\\)`;
}

const UNIT_AT = "([A-Za-zΩ][A-Za-zΩ0-9-]*)(?=$|[\\s,.;:)\\]?<>])";

/** `20 ms-1` → `20 \(\mathrm{m\,s^{-1}}\)`; `462 cm3` → `462 \(\mathrm{cm^{3}}\)`.
 *  Only right after a number standing on its own (not the 2 in `Nm2`), or
 *  at the start of text that follows maths (`\(3 \times 10^{8}\)ms-1`). */
function fixUnits(t, afterMath = false) {
  const unit = (token) => (UNIT_TOKENS.has(token) ? unitToTex(token) : null);
  let out = t.replace(
    new RegExp(`(^|[^A-Za-z0-9.])(\\d+(?:\\.\\d+)?)(\\s?)${UNIT_AT}`, "g"),
    (m, lead, num, space, token) => {
      const tex = unit(token);
      return tex ? `${lead}${num} ${tex}` : m;
    },
  );
  if (afterMath) {
    out = out.replace(new RegExp(`^(\\s?)${UNIT_AT}`), (m, space, token) => {
      const tex = unit(token);
      return tex ? ` ${tex}` : m;
    });
  }
  return out;
}

/** `30o`, `042o`, `10oC` → `\(30^\circ\)`. The letter o after a number,
 *  where WAEC's typesetting had a degree sign. */
function fixDegrees(t) {
  // …or straight before maths: "120o\(180^\circ\)" in one option.
  return t.replace(/(\d+(?:\.\d+)?)\s?o(?=[CNSEW]\b|[\s,.;:)\]/\\]|$)/g, "\\($1^\\circ\\)");
}

/** `N140,000` → `₦140,000`. Mathematics and Further Mathematics only:
 *  in Physics N is a newton, or nitrogen. */
function fixNaira(t) {
  return t.replace(/(^|[^A-Za-z0-9])N(\d[\d,]*(?:\.\d+)?)/g, "$1₦$2");
}

/** Known misspellings in the corpus (audit B9). Whole words only. */
const TYPOS = {
  simplfy: "simplify", Simplfy: "Simplify", restivity: "resistivity", lenght: "length",
  lenghts: "lengths", seperate: "separate", seperated: "separated", equalateral: "equilateral",
  equaliteral: "equilateral", paralell: "parallel", parrallel: "parallel", perpendicualr: "perpendicular",
  circumfrence: "circumference", diamter: "diameter", traingle: "triangle", triange: "triangle",
  quadrilaterial: "quadrilateral", accelaration: "acceleration", acceleraton: "acceleration",
  temprature: "temperature", temperture: "temperature", resistence: "resistance",
  freqency: "frequency", frequecy: "frequency", wavelenght: "wavelength", calcuate: "calculate",
  Calcuate: "Calculate", detemine: "determine", Detemine: "Determine", probablity: "probability",
};
function fixTypos(t) {
  return (
    t
      .replace(/\b[A-Za-z]+\b/g, (w) => TYPOS[w] ?? w)
      // OCR read a capital I as a lower-case l: "lf sin θ", "ln the
      // diagram". "ln" is also the natural log, so only before a word.
      .replace(/(^|[.!?]\s+|\n\s*)lf\b/g, "$1If")
      .replace(/\blf\b/g, "if")
      .replace(/(^|[.!?]\s+|\n\s*)ln (?=(?:the|a|an|order|which|this|figure|each|what)\b)/g, "$1In ")
      .replace(/\bln (?=(?:the|a|an|order|which|this|figure|each|what)\b)/g, "in ")
  );
}

/** "find the value…" → "Find the value…" (audit B10). Only a whole first
 *  word of two or more letters, so a stem opening on a variable (`x + 2 = 5`)
 *  is left alone. */
function fixFirstLetter(stem) {
  return stem.replace(/^(\s*)([a-z])([a-z]+\b)/, (m, sp, first, rest) => `${sp}${first.toUpperCase()}${rest}`);
}

const MATHS_SUBJECTS = new Set(["Mathematics", "Further Mathematics"]);

/**
 * Every mechanical fix for one question, as {field, index?, rule, before,
 * after}. Rules run in a fixed order, each on the previous one's output.
 */
function fixQuestion(q, subjectName) {
  const rules = [
    ["powers-of-ten", fixPowersOfTen],
    ["units", fixUnits],
    ["degrees", fixDegrees],
    ["typos", fixTypos],
    ...(MATHS_SUBJECTS.has(subjectName) ? [["naira", fixNaira]] : []),
  ];
  const changes = [];
  const run = (field, value, index) => {
    let out = String(value ?? "");
    const applied = [];
    for (const [rule, fn] of rules) {
      const next = mapText(out, fn);
      if (next !== out) applied.push(rule);
      out = next;
    }
    if (field === "text") {
      // A stem opening on maths starts with "\(" and is left alone.
      const capped = fixFirstLetter(out);
      if (capped !== out) applied.push("first-letter");
      out = capped;
    }
    if (out !== String(value ?? "")) changes.push({ field, index, rules: applied, before: value, after: out });
    return out;
  };
  const text = run("text", q.text);
  const options = (q.options || []).map((o, i) => run("options", o, i));
  const explanation = run("explanation", q.explanation);
  return { changes, text, options, explanation };
}

// ─── Checks (the audit's rules) ──────────────────────────────────────

const norm = (s) =>
  String(s ?? "")
    .toLowerCase()
    .replace(/\\[a-z]+/g, " ")
    .replace(/[^a-z0-9]+/g, "");

/** Maths that KaTeX cannot render, or TeX commands sitting in plain text. */
function brokenLatex(value) {
  const out = [];
  for (const p of splitMath(value)) {
    if (p.math) {
      try {
        katex.renderToString(p.tex, { throwOnError: true, strict: "ignore" });
      } catch (e) {
        out.push(`won't render: ${p.tex.slice(0, 50)}`);
      }
    } else {
      const stray = p.raw.replace(/\\\$/g, "").match(/\\[a-zA-Z]+/g);
      if (stray) out.push(`TeX outside maths: ${[...new Set(stray)].join(" ")}`);
    }
  }
  return out;
}

// ─── Answer suspects (Plan v2 §2.3) ──────────────────────────────────
//
// These never change anything. They flag a question for a person to check
// against the original paper, and they are deliberately narrow: each one
// skips any question it cannot read, rather than guess.

const LETTER = "ABCDE";
const near = (a, b) => Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));

/** The number an option (or a bit of a stem) states, or null: integers,
 *  decimals, thousands commas, `\frac{a}{b}`, `a/b`, mixed `2\frac{1}{3}`,
 *  `3.4 \times 10^{-3}`, with a trailing unit allowed. */
function numericValue(source, { units = true } = {}) {
  let s = String(source ?? "")
    .replace(/\\[()[\]]|\$\$/g, "")
    .replace(/\\[dt]frac/g, "\\frac")
    .replace(/\\,|\\;|\\!|~/g, "")
    .replace(/−/g, "-")
    .trim();
  const bare = numberIn(s);
  if (bare != null || !units) return bare;
  // A unit after the number ("0.0080 kg", "12 \mathrm{cm^{2}}").
  // Only after a space or as \mathrm: "4x-4" is algebra, not 4 of unit x.
  const unit = /^(.*\d)(?:\s*\\mathrm\{[^}]*\}|\s+[A-Za-zΩ°%][A-Za-zΩ°%0-9^{}-]*)$/.exec(s);
  return unit ? numberIn(unit[1].trim()) : null;
}

function numberIn(str) {
  let s = str;
  if (/^-?\d{1,3}(,\d{3})+(\.\d+)?$/.test(s)) s = s.replace(/,/g, "");
  let m;
  if ((m = /^(-?)(\d+)\s*\\frac\{(\d+)\}\{(\d+)\}$/.exec(s))) {
    const v = Number(m[2]) + Number(m[3]) / Number(m[4]);
    return Number(m[4]) ? (m[1] ? -v : v) : null;
  }
  if ((m = /^(-?)\\frac\{(-?\d+(?:\.\d+)?)\}\{(\d+(?:\.\d+)?)\}$/.exec(s)) || (m = /^(-?)(-?\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/.exec(s))) {
    const v = Number(m[2]) / Number(m[3]);
    return Number(m[3]) ? (m[1] ? -v : v) : null;
  }
  if ((m = /^(-?\d+(?:\.\d+)?)\s*(?:\\times|×|x|X)\s*10\^\{?(-?\d+)\}?$/.exec(s))) {
    return Number(m[1]) * 10 ** Number(m[2]);
  }
  if (/^-?\d+(\.\d+)?$/.test(s) || /^-?\.\d+$/.test(s)) return Number(s);
  return null;
}

/** Decimal rounding on the digits, half up, so 0.0125 to 3 d.p. is 0.013
 *  (a float would make it 0.012). `places` may be negative (to tens). */
function roundDecimal(str, places) {
  const s = String(str).trim();
  const neg = s.startsWith("-");
  const [int, frac = ""] = s.replace(/^-/, "").split(".");
  const digits = BigInt((int || "0") + frac);
  const drop = frac.length - places;
  if (drop <= 0) return Number(s);
  const div = 10n ** BigInt(drop);
  let q = digits / div;
  if ((digits % div) * 2n >= div) q += 1n;
  // Back through a string, so 13 at 3 places is exactly 0.013.
  const v = Number(`${q}e${-places}`);
  return neg ? -v : v;
}

/** [str] rounded to [n] significant figures. */
function roundSignificant(str, n) {
  const [int, frac = ""] = String(str).replace(/^-/, "").split(".");
  const i = int.replace(/^0+/, "");
  const exponent = i ? i.length - 1 : -(frac.match(/^0*/)[0].length + 1);
  return roundDecimal(str, n - 1 - exponent);
}

/** How many significant figures an option is written to ("0.0080" → 2,
 *  "800" → null: trailing zeros of an integer are ambiguous). */
function writtenSignificant(source) {
  const s = String(source ?? "").replace(/\\[()]/g, "").replace(/,/g, "").trim().match(/^-?\d*\.?\d+/);
  if (!s) return null;
  const t = s[0].replace(/^-/, "");
  if (!t.includes(".")) return /0$/.test(t) ? null : t.replace(/^0+/, "").length;
  return t.replace(".", "").replace(/^0+/, "").length;
}

const WORD_NUMBERS = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6 };
const countOf = (w) => (/^\d+$/.test(w) ? Number(w) : WORD_NUMBERS[w.toLowerCase()]);

/** The first plain number in the stem's text and maths ("0.007985",
 *  "\(24.0457\)"), as written. */
function stemNumbers(text) {
  return (String(text ?? "").replace(/\\[()]/g, " ").match(/-?\d[\d,]*\.?\d*/g) || []).map((n) => n.replace(/,(?=\d{3}\b)/g, ""));
}

/**
 * A stem with a decimal ("0.612") asked as a fraction, where one option is
 * the decimal as written and another is the decimal read as recurring
 * (68/111 = 0.612612…). The dots over the digits were lost somewhere
 * between the paper and the archive, so either may be the answer.
 */
function recurringSuspect(q) {
  if (!/(fraction|form|\\frac\{[a-z]\}\{[a-z]\}|[a-z]\/[a-z]|express|convert)/i.test(String(q.text))) return null;
  const decimals = stemNumbers(q.text).filter((n) => /^\d*\.\d{2,}$/.test(n));
  const values = (q.options || []).map(numericValue);
  for (const d of decimals) {
    const [int, frac] = d.split(".");
    const asWritten = values.findIndex((v) => v != null && near(v, Number(d)));
    for (let k = 1; k <= frac.length; k++) {
      // The last k digits repeat: 0.612 with k = 3 is 0.612612…
      const head = frac.slice(0, frac.length - k);
      const cycle = frac.slice(frac.length - k);
      const recurring = Number(`${int || 0}.${head}${cycle.repeat(Math.ceil(24 / k))}`);
      const i = values.findIndex((v, j) => v != null && j !== asWritten && near(v, recurring));
      if (i >= 0 && asWritten >= 0) {
        return `${d}: ${LETTER[asWritten]} is it as written, ${LETTER[i]} is ${int || 0}.${head}(${cycle}) recurring; marked ${LETTER[q.correctIndex] ?? "?"}`;
      }
    }
  }
  return null;
}

/**
 * A rounding or standard-form stem, worked out: {expected, matches} where
 * matches are the options equal to the computed answer (written to the
 * right number of figures), or null when the stem is not one it can read.
 * Conservative: a stem with any arithmetic in it is skipped.
 */
function roundingAnswer(q) {
  const raw = String(q.text ?? "");
  const text = textOnly(raw) + " " + raw;
  const options = q.options || [];
  if (/[×*÷+]|\\times|\\div|\\frac|\\sqrt|\\log|\blog\b/.test(raw)) return null;
  // "The square root of…", "which cannot be…": not a plain rounding.
  if (/\b(root|reciprocal|square|cube|cannot|not)\b/i.test(raw)) return null;
  const phrase = /\b(?:correct|round|approximate|express|write|give)\w*\b(?:[^.?]|\.(?=\d))*?\bto\s+(\d+|one|two|three|four|five|six)\s+(significant figures?|s\.?\s?f\.?|decimal places?|d\.?\s?p\.?)/i;
  let expected;
  let figures = null;
  let standard = false;
  const m = phrase.exec(text);
  if (m) {
    // The count ("to 3 significant figures") is not the number rounded.
    const numbers = stemNumbers(raw.replace(/\bto\s+\d+\s+(significant|s\.?\s?f|decimal|d\.?\s?p)/gi, " "));
    if (numbers.length !== 1) return null;
    const n = countOf(m[1]);
    if (/significant|s\.?\s?f/i.test(m[2])) {
      expected = roundSignificant(numbers[0], n);
      figures = n;
    } else {
      expected = roundDecimal(numbers[0], n);
    }
  } else if (/\bstandard form\b/i.test(text) && /\b(express|write|convert)\b/i.test(text)) {
    const numbers = stemNumbers(raw);
    if (numbers.length !== 1) return null;
    expected = Number(numbers[0]);
    standard = true;
  } else {
    return null;
  }
  const matches = options
    .map((o, i) => [numericValue(o), i])
    .filter(([v]) => v != null && near(v, expected))
    .filter(([, i]) => figures == null || [null, figures].includes(writtenSignificant(options[i])))
    // Standard form is a × 10ⁿ with 1 ≤ a < 10: 0.462 × 10⁻¹ is not it.
    .filter(([, i]) => !standard || /^(\\\()?\s*-?[1-9](\.\d+)?\s*(\\times|×)/.test(String(options[i]).trim()))
    .map(([, i]) => i);
  return { expected, matches };
}

/** The marked option disagrees with a rounding stem worked out: exactly
 *  one option is the computed answer, and it is not the one marked. */
function answerMismatch(q) {
  const marked = q.correctIndex;
  if (!Number.isInteger(marked) || marked < 0) return null;
  const r = roundingAnswer(q);
  if (!r || r.matches.length !== 1 || r.matches[0] === marked) return null;
  return `computed ${r.expected}: that is ${LETTER[r.matches[0]]}, marked ${LETTER[marked]}`;
}

/** Two options that say the same number differently (½ and 0.5). Not on
 *  rounding stems, where 0.008 and 0.0080 are different answers. */
function equivalentOptions(q) {
  if (/significant|decimal place|s\.f|d\.p|standard form/i.test(String(q.text))) return null;
  const options = q.options || [];
  // Bare numbers only: "4 nodes" and "4 antinodes" are different answers.
  const values = options.map((o) => numericValue(o, { units: false }));
  for (let i = 0; i < values.length; i++) {
    for (let j = i + 1; j < values.length; j++) {
      if (values[i] != null && values[j] != null && near(values[i], values[j]) && String(options[i]).trim() !== String(options[j]).trim()) {
        return `${LETTER[i]} ${options[i]} = ${LETTER[j]} ${options[j]}`;
      }
    }
  }
  return null;
}

/** Misreadings at the start of a stem, with the word meant. */
const STEM_TYPOS = [[/^\s*Expression(?=\s+(?:-?\d|\\\(|\.\d))/, "Express"]];

/** Maths typed as ASCII outside `\(…\)`: `2^(x+1)`, `√(2x)`, `32_four`,
 *  `3 x 4` with x as a times sign. */
function asciiMaths(value) {
  const t = textOnly(value);
  const found = [
    [/\S\^\s*[({\d-]/, "^"],
    [/√\s*\(/, "√("],
    [/\b\d+_[a-z0-9]+\b/i, "base as _"],
    [/\b\d+(?:\.\d+)?\s+x\s+\d/, "x as times"],
  ].filter(([re]) => re.test(t));
  return found.length ? found.map(([, d]) => d).join(", ") : null;
}

/** An explanation that rounds to a different count than the stem asks
 *  ("three significant figures" asked, "two" worked). */
function explanationMismatch(q) {
  const unit = /\b(\d|one|two|three|four|five|six)\s+(significant figures?|decimal places?)/i;
  const asked = unit.exec(textOnly(q.text));
  if (!asked || !q.explanation) return null;
  const n = countOf(asked[1]);
  const kind = asked[2].toLowerCase().startsWith("s") ? "s" : "d";
  const said = [...textOnly(q.explanation).matchAll(new RegExp(unit.source, "gi"))]
    .filter((m) => m[2].toLowerCase().startsWith(kind))
    .map((m) => countOf(m[1]));
  if (!said.length || said.includes(n)) return null;
  return `stem asks ${n}, explanation says ${said.join("/")}`;
}

/** Per-question checks: [{rule, level, detail}]. Level A breaks meaning;
 *  level S is a suspect for a person to check against the paper. */
function checkQuestion(q) {
  const found = [];
  const add = (rule, level, detail) => found.push({ rule, level, detail });
  const options = q.options || [];
  const plain = [q.text, ...options].map(textOnly).join(" | ");

  if (q.correctIndex != null && (!Number.isInteger(q.correctIndex) || q.correctIndex < -1 || q.correctIndex >= options.length)) {
    add("answer-out-of-range", "A", `correctIndex ${q.correctIndex} of ${options.length}`);
  }
  if (options.length > 5) add("too-many-options", "A", `${options.length} options`);
  const equivalent = equivalentOptions(q);
  if (equivalent) add("equivalent-options", "A", equivalent);
  const recurring = recurringSuspect(q);
  if (recurring) add("recurring-decimal-suspect", "S", recurring);
  const mismatch = answerMismatch(q);
  if (mismatch) add("answer-mismatch-suspect", "S", mismatch);
  for (const [re, word] of STEM_TYPOS) {
    const m = re.exec(String(q.text ?? ""));
    if (m) add("stem-typo", "B", `"${m[0].trim()}" → "${word}"`);
  }
  for (const [field, value] of [["question", q.text], ["options", options.join(" | ")]]) {
    const ascii = asciiMaths(value);
    if (ascii) add(`needs-latex-${field}`, "B", ascii);
  }
  const explained = explanationMismatch(q);
  if (explained) add("explanation-mismatch", "B", explained);

  // Strict: "-17" and "17", \frac{1}{2} and 12, and t and T are all
  // different answers. Only spacing and `$` are ignored.
  const keys = options.map((o) => String(o ?? "").replace(/\s+|\$/g, ""));
  const dup = keys.filter((k, i) => k && keys.indexOf(k) !== i);
  if (dup.length) add("duplicate-options", "A", options.join(" | "));
  if (options.length < 4) add("too-few-options", "A", `${options.length} options`);
  if (/[x×X]\s*10-\d/.test(plain)) add("lost-negative-power", "A", plain.match(/.{0,20}[x×X]\s*10-\d+.{0,10}/)[0]);
  for (const [field, value] of [["question", q.text], ["options", options.join(" | ")], ["explanation", q.explanation]]) {
    for (const d of brokenLatex(value)) add(`raw-latex-${field}`, field === "explanation" ? "B" : "A", d);
  }
  if (/\d\s?o(?=C\b|[\s,.;:)]|$)/.test(plain)) add("degree-as-o", "B", "");
  if (/\b\d+(\.\d+)?\s?(cm|m|km|mm)(2|3)\b/.test(plain)) add("flat-units", "B", "");
  if (/\b(diagram|(?<!significant )figure|venn|sketch|(shown|illustrated) (above|below))\b/i.test(q.text) && !q.imageId) {
    add("diagram-missing", "A", String(q.text).slice(0, 80));
  }
  if (/\b(the table|table (shows|below|above))\b/i.test(q.text) && !q.imageId && !/\\begin\{array\}/.test(q.text)) {
    add("flattened-table", "B", String(q.text).slice(0, 80));
  }
  if (!String(q.explanation ?? "").trim()) add("missing-explanation", "B", "");
  // The raw stem: one that opens on maths ("\(f(x)\) is…") starts fine.
  if (/^\s*[a-z]{2,}\b/.test(String(q.text ?? ""))) add("lower-case-start", "B", "");
  if (/(^|[^A-Za-z0-9])N\d/.test(plain)) add("naira-as-N", "B", "");
  if (Object.keys(TYPOS).some((w) => new RegExp(`\\b${w}\\b`).test(plain))) add("typo", "B", "");
  return found;
}

const paperKey = (q) => `${q.subjectId}|${q.year}`;
const questionKey = (q) => `${norm(q.text)}#${(q.options || []).map(norm).sort().join("/")}`;

function trigrams(s) {
  const t = norm(s);
  const out = new Set();
  for (let i = 0; i + 3 <= t.length; i++) out.add(t.slice(i, i + 3));
  return out;
}
function jaccard(a, b) {
  let inter = 0;
  for (const x of a) if (b.has(x)) inter++;
  return inter / (a.size + b.size - inter || 1);
}

/**
 * Checks across questions: exact duplicates in one paper, near duplicates
 * in one paper (trigram Jaccard ≥ 0.8), and the same question in two
 * years. Each group lists ids, oldest id first, so "keep the first" is
 * deterministic.
 */
function checkCorpus(questions) {
  const byPaper = new Map();
  for (const q of questions) {
    if (!byPaper.has(paperKey(q))) byPaper.set(paperKey(q), []);
    byPaper.get(paperKey(q)).push(q);
  }
  const exact = [];
  const near = [];
  for (const list of byPaper.values()) {
    const seen = new Map();
    for (const q of list) {
      const k = questionKey(q);
      if (seen.has(k)) seen.get(k).push(q.id);
      else seen.set(k, [q.id]);
    }
    for (const ids of seen.values()) if (ids.length > 1) exact.push(ids);
    const grams = list.map((q) => [q, trigrams(q.text + " " + (q.options || []).join(" "))]);
    for (let i = 0; i < grams.length; i++) {
      for (let j = i + 1; j < grams.length; j++) {
        const [a, ga] = grams[i];
        const [b, gb] = grams[j];
        if (questionKey(a) === questionKey(b)) continue;
        if (jaccard(ga, gb) >= 0.8) near.push([a.id, b.id]);
      }
    }
  }
  const acrossYears = new Map();
  for (const q of questions) {
    const k = `${q.subjectId}|${questionKey(q)}`;
    if (!acrossYears.has(k)) acrossYears.set(k, []);
    acrossYears.get(k).push(q);
  }
  const repeats = [...acrossYears.values()]
    .filter((g) => new Set(g.map((q) => q.year)).size > 1)
    .map((g) => g.map((q) => `${q.year}:${q.id}`));
  const paperSizes = [...byPaper.entries()].map(([k, list]) => [k, list.length]);
  return { exact, near, repeats, paperSizes };
}

module.exports = {
  splitMath,
  mapText,
  textOnly,
  fixPowersOfTen,
  fixUnits,
  fixDegrees,
  fixNaira,
  fixTypos,
  fixFirstLetter,
  fixQuestion,
  checkQuestion,
  checkCorpus,
  brokenLatex,
  numericValue,
  roundDecimal,
  roundSignificant,
  recurringSuspect,
  answerMismatch,
  roundingAnswer,
  equivalentOptions,
  asciiMaths,
  explanationMismatch,
  UNIT_TOKENS,
};
