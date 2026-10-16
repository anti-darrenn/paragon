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

/** schema.org Quiz for one question — what Google's rich results read. */
function quizJsonLd({ q, subjectName, url }) {
  const options = q.options.map((o, i) => ({
    "@type": "Answer",
    position: i,
    text: `${LETTERS[i]}. ${plainText(o)}`,
  }));
  return {
    "@context": "https://schema.org",
    "@type": "Quiz",
    name: `WAEC ${q.year} ${subjectName} question`,
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
        text: plainText(q.text),
        suggestedAnswer: options.filter((_, i) => i !== q.correctIndex),
        acceptedAnswer: {
          ...options[q.correctIndex],
          ...(q.explanation ? { answerExplanation: { "@type": "Comment", text: plainText(q.explanation) } } : {}),
        },
      },
    ],
  };
}

/**
 * The page shell. `root` is the relative path back to the site root for
 * the stylesheet; `canonical` is absolute.
 */
function page({ title, description, canonical, body, jsonLd, root, hasMath, noindex }) {
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
<meta name="twitter:card" content="summary">
<meta name="theme-color" content="#0D1117">
<link rel="icon" href="/favicon.png">
<link rel="stylesheet" href="${root}past-questions/site.css">
${hasMath ? `<link rel="stylesheet" href="${root}past-questions/katex/katex.min.css">` : ""}
${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd).replace(/</g, "\\u003c")}</script>` : ""}
</head>
<body>
<header class="top"><a class="brand" href="/">Paragon</a><a class="cta-small" href="/">Open the app</a></header>
<main>
${body}
</main>
<footer>Paragon is free WAEC prep. Not affiliated with WAEC; answers are checked by students and our team, so if one looks wrong, report it in the app. <a href="/about">About</a> · <a href="/privacy">Privacy</a></footer>
</body>
</html>
`;
}

module.exports = {
  escapeHtml,
  renderRich,
  plainText,
  slugify,
  truncate,
  quizJsonLd,
  page,
  LETTERS,
};
