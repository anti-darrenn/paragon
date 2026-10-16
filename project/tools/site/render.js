/**
 * Pure rendering for the static past-question pages: question text with
 * maths to HTML, slugs, and the page shell. No Firestore here, so it is
 * testable on its own (`node render.test.js`).
 *
 * The text dialect is the corpus's, read the way `FullLatexView` reads it:
 * inline maths `\(...\)`, display `\[...\]` or `$$...$$`, `\textbf{}`,
 * `\textit{}`, `\vspace{}` and `\$` outside maths, and a lone `$` is a
 * dollar sign, never maths. Change both together.
 */
const katex = require("katex");

const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
const escapeHtml = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ESC[c]);

function renderMath(tex, display) {
  try {
    return katex.renderToString(tex, {
      displayMode: display,
      throwOnError: true,
      strict: "ignore",
      output: "htmlAndMathml",
    });
  } catch (_) {
    // As the app does: show the source rather than nothing.
    return `<code class="tex-error">${escapeHtml(tex)}</code>`;
  }
}

/** Text outside maths: escape, then the few text macros the app supports. */
function renderText(s) {
  return escapeHtml(s)
    .replace(/\\\$/g, "$")
    .replace(/\\textbf\{([^{}]*)\}/g, "<strong>$1</strong>")
    .replace(/\\textit\{([^{}]*)\}/g, "<em>$1</em>")
    .replace(/\\vspace\{[^{}]*\}/g, "<br>")
    .replace(/\r?\n/g, "<br>");
}

/** Mixed text and maths to HTML. */
function renderRich(source) {
  const s = String(source ?? "");
  let out = "";
  let text = "";
  let i = 0;
  const flush = () => {
    out += renderText(text);
    text = "";
  };
  while (i < s.length) {
    if (s[i] === "\\" && s[i + 1] === "$") {
      text += "\\$";
      i += 2;
      continue;
    }
    if (s[i] === "\\" && (s[i + 1] === "(" || s[i + 1] === "[")) {
      const display = s[i + 1] === "[";
      const close = display ? "\\]" : "\\)";
      const end = s.indexOf(close, i + 2);
      if (end > 0) {
        flush();
        out += renderMath(s.slice(i + 2, end), display);
        i = end + 2;
        continue;
      }
    }
    if (s.startsWith("$$", i)) {
      const end = s.indexOf("$$", i + 2);
      if (end > i + 2) {
        flush();
        out += renderMath(s.slice(i + 2, end), true);
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

/** Plain text for titles, descriptions and JSON-LD: maths kept as source. */
function plainText(source) {
  return String(source ?? "")
    .replace(/\\[()[\]]/g, "")
    .replace(/\$\$/g, "")
    .replace(/\\textbf\{([^{}]*)\}|\\textit\{([^{}]*)\}/g, "$1$2")
    .replace(/\\vspace\{[^{}]*\}/g, " ")
    .replace(/\\\$/g, "$")
    .replace(/\s+/g, " ")
    .trim();
}

// ─── Maths as plain text ─────────────────────────────────────────────

const SYMBOLS = {
  times: "×", div: "÷", cdot: "·", pm: "±", mp: "∓", le: "≤", leq: "≤", ge: "≥",
  geq: "≥", ne: "≠", neq: "≠", approx: "≈", equiv: "≡", infty: "∞", circ: "°", degree: "°",
  angle: "∠", triangle: "△", to: "→", rightarrow: "→", Rightarrow: "⇒", leftarrow: "←",
  in: "∈", notin: "∉", cup: "∪", cap: "∩", subset: "⊂", subseteq: "⊆", emptyset: "∅",
  varnothing: "∅", therefore: "∴", because: "∵", perp: "⊥", parallel: "∥", sum: "Σ", int: "∫",
  prod: "∏", partial: "∂", nabla: "∇", forall: "∀", exists: "∃", ldots: "…", cdots: "⋯",
  dots: "…", prime: "′", propto: "∝", sim: "~", cong: "≅", lt: "<", gt: ">",
  alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", varepsilon: "ε", zeta: "ζ",
  eta: "η", theta: "θ", vartheta: "θ", iota: "ι", kappa: "κ", lambda: "λ", mu: "μ", nu: "ν",
  xi: "ξ", pi: "π", rho: "ρ", sigma: "σ", tau: "τ", upsilon: "υ", phi: "φ", varphi: "φ",
  chi: "χ", psi: "ψ", omega: "ω", Gamma: "Γ", Delta: "Δ", Theta: "Θ", Lambda: "Λ", Xi: "Ξ",
  Pi: "Π", Sigma: "Σ", Phi: "Φ", Psi: "Ψ", Omega: "Ω",
  "%": "%", "$": "$", "&": "&", "#": "#", "_": "_", "{": "{", "}": "}",
  ",": " ", ";": " ", ":": " ", "!": "", " ": " ", quad: " ", qquad: " ",
};
// Spaced like the binary operators and relations they are.
const RELATIONS = new Set([
  "times", "div", "cdot", "pm", "mp", "le", "leq", "ge", "geq", "ne", "neq", "approx", "equiv",
  "to", "rightarrow", "Rightarrow", "leftarrow", "in", "notin", "cup", "cap", "subset",
  "subseteq", "propto", "cong", "sim", "lt", "gt", "perp", "parallel",
]);
// Commands whose argument is kept as it is.
const UNWRAP = new Set([
  "text", "textrm", "textbf", "textit", "mathrm", "mathbf", "mathit", "operatorname",
  "boldsymbol", "vec", "hat", "overline", "underline", "widehat", "overrightarrow", "mbox", "bm",
]);
const SUP = { 0: "⁰", 1: "¹", 2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷", 8: "⁸", 9: "⁹", "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", n: "ⁿ", i: "ⁱ", x: "ˣ", y: "ʸ" };
const SUB = { 0: "₀", 1: "₁", 2: "₂", 3: "₃", 4: "₄", 5: "₅", 6: "₆", 7: "₇", 8: "₈", 9: "₉", "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎" };

/** One argument at [i]: a `{…}` group (nesting respected), a command, or a character. */
function readArg(s, i) {
  while (s[i] === " ") i++;
  if (s[i] === "{") {
    let depth = 0;
    for (let j = i; j < s.length; j++) {
      if (s[j] === "\\") { j++; continue; }
      if (s[j] === "{") depth++;
      else if (s[j] === "}" && --depth === 0) return [s.slice(i + 1, j), j + 1];
    }
    return [s.slice(i + 1), s.length];
  }
  if (s[i] === "\\") {
    const m = /^\\([a-zA-Z]+|.)/.exec(s.slice(i));
    if (m) return [m[0], i + m[0].length];
  }
  return [s[i] ?? "", i + 1];
}

/** `x+1` needs brackets around it in `a/b`; `x` and `12` do not. */
const wrap = (t) => (/^[\p{L}\p{N}.′]+$|^\([^()]*\)$/u.test(t) ? t : `(${t})`);

function script(text, map, mark) {
  const chars = [...text.replace(/\s+/g, "")];
  return chars.length && chars.every((c) => map[c]) ? chars.map((c) => map[c]).join("") : `${mark}${wrap(text)}`;
}

/** TeX source to readable plain text: `\frac{2x-1}{x+3}` → `(2x-1)/(x+3)`. */
function texToPlain(s) {
  let out = "";
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c === "\\") {
      const m = /^\\([a-zA-Z]+|.)/.exec(s.slice(i));
      const name = m ? m[1] : "";
      i += m ? m[0].length : 1;
      if (name === "frac" || name === "dfrac" || name === "tfrac") {
        const [a, j] = readArg(s, i);
        const [b, k] = readArg(s, j);
        out += `${wrap(texToPlain(a))}/${wrap(texToPlain(b))}`;
        i = k;
      } else if (name === "sqrt") {
        let index = "";
        if (s[i] === "[") {
          const end = s.indexOf("]", i);
          index = texToPlain(s.slice(i + 1, end));
          i = end + 1;
        }
        const [a, j] = readArg(s, i);
        out += `${index ? script(index, SUP, "^") : ""}√${wrap(texToPlain(a))}`;
        i = j;
      } else if (name === "bar") {
        const [a, j] = readArg(s, i);
        out += `${texToPlain(a)}̄`;
        i = j;
      } else if (UNWRAP.has(name)) {
        const [a, j] = readArg(s, i);
        out += texToPlain(a);
        i = j;
      } else if (name === "left" || name === "right" || name === "big" || name === "Big" || name === "displaystyle") {
        // drop the sizing command, keep the bracket after it
      } else if (name === "begin" || name === "end") {
        const [, j] = readArg(s, i);
        out += " ";
        i = j;
      } else if (name in SYMBOLS) {
        // As in TeX, the space after a command word is not text:
        // `\angle PQR` is ∠PQR. Relations and operators get their own.
        if (/^[a-zA-Z]+$/.test(name) && s[i] === " ") i++;
        out += RELATIONS.has(name) ? ` ${SYMBOLS[name]} ` : SYMBOLS[name];
      } else if (/^[a-zA-Z]+$/.test(name)) {
        out += name; // \sin, \log, and any command we do not know
      } else {
        out += name;
      }
    } else if (c === "^" || c === "_") {
      const [a, j] = readArg(s, i + 1);
      const text = texToPlain(a);
      out += text === "°" ? "°" : script(text, c === "^" ? SUP : SUB, c);
      i = j;
    } else if (c === "{" || c === "}") {
      i++;
    } else if (c === "&") {
      out += " ";
      i++;
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

/**
 * Plain text for titles, descriptions, list previews and JSON-LD, with the
 * maths made readable instead of left as TeX source (audit B3, B4). A
 * lone `$` stays a dollar sign, as everywhere in this dialect.
 */
function plainMath(source) {
  const s = String(source ?? "");
  let out = "";
  let i = 0;
  while (i < s.length) {
    if (s[i] === "\\" && (s[i + 1] === "(" || s[i + 1] === "[")) {
      const close = s[i + 1] === "[" ? "\\]" : "\\)";
      const end = s.indexOf(close, i + 2);
      if (end > 0) {
        out += texToPlain(s.slice(i + 2, end));
        i = end + 2;
        continue;
      }
    }
    if (s.startsWith("$$", i)) {
      const end = s.indexOf("$$", i + 2);
      if (end > i + 2) {
        out += texToPlain(s.slice(i + 2, end));
        i = end + 2;
        continue;
      }
    }
    out += s[i];
    i++;
  }
  return plainText(out)
    // Stray TeX outside delimiters, which some scraped text carries.
    .replace(/\\(frac|dfrac|sqrt|times|div|pm|le|ge|ne|pi|theta|alpha|beta|circ)\b(\{[^{}]*\}){0,2}/g, (m) => texToPlain(m))
    .replace(/\s+/g, " ")
    .trim();
}

/** Mirrors `SubjectCatalog.slugify` in the app. */
function slugify(name) {
  return String(name)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function truncate(s, n) {
  return s.length <= n ? s : s.slice(0, n - 1).replace(/\s+\S*$/, "") + "…";
}

const LETTERS = "ABCDE";

/** schema.org Quiz for one question — what Google's rich results read.
 *  [name] is the page's own title stem, not a generic label (audit E9). */
function quizJsonLd({ q, subjectName, url, name }) {
  const options = q.options.map((o, i) => ({
    "@type": "Answer",
    position: i,
    text: `${LETTERS[i]}. ${plainMath(o)}`,
  }));
  return {
    "@context": "https://schema.org",
    "@type": "Quiz",
    name: name || `WAEC ${q.year} ${subjectName} question`,
    url,
    about: { "@type": "Thing", name: subjectName },
    educationalAlignment: {
      "@type": "AlignmentObject",
      alignmentType: "educationalSubject",
      targetName: subjectName,
    },
    hasPart: [
      {
        "@type": "Question",
        eduQuestionType: "Multiple choice",
        text: plainMath(q.text),
        suggestedAnswer: options.filter((_, i) => i !== q.correctIndex),
        acceptedAnswer: {
          ...options[q.correctIndex],
          ...(q.explanation ? { answerExplanation: { "@type": "Comment", text: plainMath(q.explanation) } } : {}),
        },
      },
    ],
  };
}

/** The site-wide share picture (`web/og-image.jpg`, 1200×630). WhatsApp
 *  and the rest show no preview image without one (audit E1). */
let OG_IMAGE = "https://paragon-hq.web.app/og-image.jpg";

/** Sets the site address the share picture is served from. */
function configure({ origin }) {
  OG_IMAGE = `${origin}/og-image.jpg`;
}

/** schema.org BreadcrumbList from `[label, absoluteUrl]` pairs (audit E7). */
function breadcrumbJsonLd(items) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map(([name, item], i) => ({
      "@type": "ListItem",
      position: i + 1,
      name,
      ...(item ? { item } : {}),
    })),
  };
}

/** schema.org ItemList of page URLs, for a year's or a topic's list. */
function itemListJsonLd(name, urls) {
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name,
    numberOfItems: urls.length,
    itemListElement: urls.map((url, i) => ({ "@type": "ListItem", position: i + 1, url })),
  };
}

/** The footer's one line about answers: the same promise the app makes
 *  (audit C11), no stronger. */
const FOOTER_TRUST =
  "Paragon is free WAEC prep, not affiliated with WAEC. Answers are checked as reports come in; if one looks wrong, report it in the app.";

/**
 * The page shell. `root` is the relative path back to the site root for
 * the stylesheet; `canonical` is absolute. `jsonLd` is one object or a list.
 */
function page({ title, description, canonical, body, jsonLd, root, hasMath, noindex }) {
  const ld = (Array.isArray(jsonLd) ? jsonLd : [jsonLd]).filter(Boolean);
  return `<!DOCTYPE html>
<html lang="en-NG">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
${noindex ? `<meta name="robots" content="noindex">` : `<link rel="canonical" href="${escapeHtml(canonical)}">`}
<meta property="og:type" content="website">
<meta property="og:site_name" content="Paragon">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(canonical)}">
<meta property="og:image" content="${OG_IMAGE}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="Paragon: free WAEC prep">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#0D1117">
<link rel="icon" href="/favicon.png">
<link rel="stylesheet" href="${root}past-questions/site.css">
${hasMath ? `<link rel="stylesheet" href="${root}past-questions/katex/katex.min.css">` : ""}
${ld.map((o) => `<script type="application/ld+json">${JSON.stringify(o).replace(/</g, "\\u003c")}</script>`).join("\n")}
</head>
<body>
<header class="top"><a class="brand" href="/">Paragon</a><a class="cta-small" href="/">Open the app</a></header>
<main>
${body}
</main>
<footer>${FOOTER_TRUST} <a href="/about/">About</a> · <a href="/privacy/">Privacy</a> · <a href="/terms/">Terms</a></footer>
</body>
</html>
`;
}

module.exports = {
  escapeHtml,
  renderRich,
  plainText,
  plainMath,
  configure,
  breadcrumbJsonLd,
  itemListJsonLd,
  slugify,
  truncate,
  quizJsonLd,
  page,
  LETTERS,
};
