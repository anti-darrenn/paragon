/**
 * The static site's copy of `lib/core/latex/tex_preprocess.dart`: LaTeX as
 * people write it in Overleaf, turned into the dialect the renderers draw.
 * Line-for-line the same algorithm; `tex_preprocess.test.js` runs the
 * shared cases in `test/fixtures/tex_preprocess_cases.json` against both.
 * Change the two together.
 */

/** `re` matched exactly at index `i` of `s` (Dart's matchAsPrefix). */
function at(re, s, i) {
  const y = new RegExp(re.source, re.flags.includes("y") ? re.flags : re.flags + "y");
  y.lastIndex = i;
  return y.exec(s);
}

const LETTER = /[A-Za-z]/;
const isLetter = (c) => c !== undefined && c !== "" && LETTER.test(c);

let held = null;

function hold(rendered) {
  held.push(rendered);
  return `\u0001${held.length - 1}\u0002`;
}
const PLACEHOLDER = /\u0001(\d+)\u0002/g;
const restore = (t, h) => t.replace(PLACEHOLDER, (_, n) => h[Number(n)]);
const heldInner = (n) => {
  const r = held[n];
  return r.slice(2, r.length - 2);
};

function normalizeTex(source) {
  source = String(source ?? "");
  if (!source.includes("\\")) return source;
  const s = expandMacros(source.replace(/\r\n/g, "\n"));
  const outer = held;
  const h = (held = []);
  try {
    let b = "";
    let i = 0;
    while (i < s.length) {
      const m = nextMathSpan(s, i);
      if (!m) {
        b += s.slice(i);
        break;
      }
      b += s.slice(i, m.start);
      const inner = s.slice(m.start + m.open.length, m.innerEnd);
      b += hold(`${m.open}${normalizeMath(inner)}${m.close}`);
      i = m.end;
    }
    let out = restore(text(b), h);
    if (!source.startsWith("\n")) out = out.replace(/^\n+/, "");
    if (!source.endsWith("\n")) out = out.replace(/\n+$/, "");
    return out;
  } finally {
    held = outer;
  }
}

function dollarMathToParens(s) {
  let out = "";
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c === "\\" && i + 1 < s.length) {
      out += s.slice(i, i + 2);
      i += 2;
      continue;
    }
    if (c === "$") {
      if (s[i + 1] === "$") {
        const close = s.indexOf("$$", i + 2);
        if (close < 0) {
          out += s.slice(i);
          break;
        }
        out += s.slice(i, close + 2);
        i = close + 2;
        continue;
      }
      const close = unescapedDollar(s, i + 1);
      if (close > i + 1) {
        out += `\\(${s.slice(i + 1, close)}\\)`;
        i = close + 1;
        continue;
      }
      out += "\\$";
      i++;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

function unescapedDollar(s, from) {
  for (let i = from; i < s.length; i++) {
    if (s[i] === "\\") {
      i++;
      continue;
    }
    if (s[i] === "$") return i;
  }
  return -1;
}

// ─── Math spans ───────────────────────────────────────────────────────

function nextMathSpan(s, from) {
  let i = from;
  while (i < s.length) {
    if (s[i] === "\\" && i + 1 < s.length) {
      const n = s[i + 1];
      if (n === "(" || n === "[") {
        const close = n === "(" ? "\\)" : "\\]";
        const end = s.indexOf(close, i + 2);
        if (end !== -1) return { start: i, innerEnd: end, end: end + 2, open: `\\${n}`, close };
      }
      i += 2;
      continue;
    }
    if (s[i] === "$" && s[i + 1] === "$") {
      const end = s.indexOf("$$", i + 2);
      if (end !== -1) return { start: i, innerEnd: end, end: end + 2, open: "$$", close: "$$" };
    }
    i++;
  }
  return null;
}

// ─── Macros ───────────────────────────────────────────────────────────

const DEFINE_COMMAND = /\\(?:re)?newcommand\*?\s*\{?\s*\\([A-Za-z]+)\s*\}?\s*(?:\[(\d)\])?\s*(?:\[[^\]]*\])?\s*\{/;
const DEF_COMMAND = /\\[gex]?def\s*\\([A-Za-z]+)\s*((?:#\d)*)\s*\{/;
const DECLARE_OPERATOR = /\\DeclareMathOperator\*?\s*\{\s*\\([A-Za-z]+)\s*\}\s*\{/;
const LET_COMMAND = /\\let\s*\\([A-Za-z]+)\s*=?\s*(\\[A-Za-z]+)/g;

function expandMacros(source) {
  if (
    !source.includes("command") &&
    !source.includes("def") &&
    !source.includes("\\let") &&
    !source.includes("DeclareMathOperator")
  ) {
    return source;
  }
  const macros = new Map();
  let s = source;

  const cut = (re, take) => {
    let out = s;
    for (;;) {
      const m = re.exec(out);
      if (!m) break;
      const open = m.index + m[0].length - 1;
      const close = matchingBrace(out, open);
      if (close < 0) break;
      take(m, out.slice(open + 1, close));
      out = out.slice(0, m.index) + out.slice(close + 1).replace(/^[ \t]*\n?[ \t]*/, "");
    }
    return out;
  };

  s = cut(DEFINE_COMMAND, (m, body) => macros.set(m[1], { args: Number(m[2] || 0), body }));
  s = cut(DEF_COMMAND, (m, body) => macros.set(m[1], { args: ((m[2] || "").match(/#/g) || []).length, body }));
  s = cut(DECLARE_OPERATOR, (m, body) => macros.set(m[1], { args: 0, body: `\\operatorname{${body}}` }));
  s = s.replace(LET_COMMAND, (_, name, to) => {
    macros.set(name, { args: 0, body: to });
    return "";
  });
  if (macros.size === 0) return s;

  const names = [...macros.keys()].sort((a, b) => b.length - a.length);
  for (let pass = 0; pass < 8; pass++) {
    let changed = false;
    for (const name of names) {
      const macro = macros.get(name);
      const use = new RegExp(`\\\\${name}(?![A-Za-z])`);
      let from = 0;
      for (;;) {
        const m = use.exec(s.slice(from));
        if (!m) break;
        const start = from + m.index;
        let p = start + m[0].length;
        const args = [];
        for (let k = 0; k < macro.args; k++) {
          while (p < s.length && s[p] === " ") p++;
          if (p >= s.length) break;
          if (s[p] === "{") {
            const close = matchingBrace(s, p);
            if (close < 0) break;
            args.push(s.slice(p + 1, close));
            p = close + 1;
          } else {
            args.push(s[p]);
            p++;
          }
        }
        let body = macro.body;
        for (let k = args.length; k >= 1; k--) body = body.split(`#${k}`).join(args[k - 1]);
        const next = p < s.length ? s[p] : "";
        const pad = isLetter(next) && /\\[A-Za-z]+$/.test(body) ? " " : "";
        s = s.slice(0, start) + body + pad + s.slice(p);
        from = start + body.length;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return s;
}

function matchingBrace(s, open) {
  if (open < 0 || open >= s.length || s[open] !== "{") return -1;
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    const c = s[i];
    if (c === "\\") {
      i++;
      continue;
    }
    if (c === "{") depth++;
    if (c === "}") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function matching(s, open, o, c) {
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    if (s[i] === "\\") {
      i++;
      continue;
    }
    if (s[i] === o) depth++;
    if (s[i] === c) {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

// ─── Text ─────────────────────────────────────────────────────────────

const KEPT_TEXT = new Set(["textbf", "textit", "underline", "texttt", "vspace"]);
const DROPPED_TEXT = new Set([
  "noindent", "indent", "centering", "raggedright", "raggedleft", "hfill",
  "vfill", "clearpage", "newpage", "pagebreak", "maketitle", "small",
  "large", "Large", "LARGE", "huge", "Huge", "normalsize", "footnotesize",
  "scriptsize", "tiny", "smallskip", "medskip", "nolinebreak", "protect",
  "displaystyle", "textstyle", "selectfont", "normalfont", "bfseries",
  "itshape", "rmfamily", "sffamily", "ttfamily", "upshape", "mdseries",
  "tableofcontents", "nonumber", "notag", "hline", "toprule", "midrule",
  "bottomrule",
]);
const DROPPED_WITH_ARG = new Set([
  "label", "index", "cite", "pagestyle", "thispagestyle", "vspace*",
  "setlength", "usepackage", "documentclass", "includegraphics", "caption",
  "ref", "eqref", "pageref",
]);
const UNWRAPPED = new Set([
  "textrm", "textnormal", "textup", "textmd", "mbox", "hbox", "text",
  "textsf", "textsl", "url", "nolinkurl", "fbox", "framebox", "makebox",
  "title", "author", "date", "smash", "boxed", "ensuremath",
]);
const TEXT_SYMBOLS = {
  "%": "%", "&": "&", "#": "#", _: "_", "{": "{", "}": "}",
  " ": " ", ",": " ", ";": " ", ":": " ", "!": "",
  "/": "", "-": "",
};
const TEXT_NAMED = {
  ldots: "…", dots: "…", textellipsis: "…", textdegree: "°",
  degree: "°", pounds: "£", textsterling: "£", euro: "€",
  texteuro: "€", yen: "¥", copyright: "©", textcopyright: "©",
  textregistered: "®", texttrademark: "™", textbullet: "•",
  textendash: "–", textemdash: "—", textasciitilde: "~",
  textasciicircum: "^", textbar: "|", textless: "<",
  textgreater: ">", textquoteleft: "‘", textquoteright: "’",
  textquotedblleft: "“", textquotedblright: "”", S: "§", P: "¶",
  dag: "†", ddag: "‡", checkmark: "✓", LaTeX: "LaTeX",
  TeX: "TeX", quad: " ", qquad: "  ",
  enspace: " ", thinspace: " ", naira: "₦", textnaira: "₦",
  textonehalf: "½", texttimes: "×", textdiv: "÷", textpm: "±",
  textmu: "µ", ohm: "Ω", textohm: "Ω", celsius: "°C",
  degreeCelsius: "°C", percent: "%", aa: "å", AA: "Å",
  ss: "ß", o: "ø", O: "Ø", ae: "æ", AE: "Æ", oe: "œ",
  OE: "Œ", i: "ı", l: "ł", L: "Ł",
};
const ACCENTS = {
  "'": "́", "`": "̀", "^": "̂", '"': "̈",
  "~": "̃", "=": "̄", ".": "̇", u: "̆",
  v: "̌", H: "̋", c: "̧", d: "̣",
  b: "̱", k: "̨", r: "̊",
};
const SECTIONS = new Set(["part", "chapter", "section", "subsection", "subsubsection", "paragraph", "subparagraph"]);
const DISPLAY_ENVIRONMENTS = {
  equation: "", "equation*": "", displaymath: "", align: "aligned",
  "align*": "aligned", flalign: "aligned", "flalign*": "aligned",
  alignat: "alignedat", "alignat*": "alignedat", eqnarray: "aligned",
  "eqnarray*": "aligned", gather: "gathered", "gather*": "gathered",
  multline: "gathered", "multline*": "gathered",
};
const INLINE_MATH_ENVIRONMENTS = new Set([
  "matrix", "pmatrix", "bmatrix", "Bmatrix", "vmatrix", "Vmatrix",
  "smallmatrix", "cases", "dcases", "aligned", "gathered", "array",
  "alignedat", "split", "subarray",
]);
const has = (o, k) => Object.prototype.hasOwnProperty.call(o, k);

const OLD_FONT_GROUP = /\{\\(bf|bfseries|it|itshape|em|sl|slshape|rm|tt|ttfamily|sc|scshape)\b\s*([^{}]*)\}/g;

function text(t) {
  if (!t.includes("\\")) return t;
  let s = t.replace(OLD_FONT_GROUP, (_, kind, body) => {
    switch (kind) {
      case "bf": case "bfseries": return `\\textbf{${body}}`;
      case "it": case "itshape": case "em": case "sl": case "slshape": return `\\textit{${body}}`;
      case "tt": case "ttfamily": return `\\texttt{${body}}`;
      case "sc": case "scshape": return body.toUpperCase();
      default: return body;
    }
  });
  s = environments(s);
  s = textCommands(s);
  return s;
}

const BEGIN_ENV = /\\begin\s*\{([A-Za-z*]+)\}/g;

function envEnd(s, name, bodyStart) {
  const open = `\\begin{${name}}`;
  const close = `\\end{${name}}`;
  let depth = 1;
  let p = bodyStart;
  for (;;) {
    const nextOpen = s.indexOf(open, p);
    const nextClose = s.indexOf(close, p);
    if (nextClose < 0) return -1;
    if (nextOpen >= 0 && nextOpen < nextClose) {
      depth++;
      p = nextOpen + open.length;
      continue;
    }
    depth--;
    if (depth === 0) return nextClose;
    p = nextClose + close.length;
  }
}

function environments(t) {
  let s = t;
  for (let guard = 0; guard < 200; guard++) {
    const begins = [...s.matchAll(BEGIN_ENV)].map((m) => ({ start: m.index, end: m.index + m[0].length, name: m[1] }));
    if (!begins.length) break;

    const maths = begins.filter((b) => has(DISPLAY_ENVIRONMENTS, b.name) || INLINE_MATH_ENVIRONMENTS.has(b.name) || b.name === "math");
    if (maths.length) {
      const b = maths[0];
      const end = envEnd(s, b.name, b.end);
      if (end >= 0) {
        const body = s.slice(b.end, end);
        const after = end + `\\end{${b.name}}`.length;
        let h;
        if (has(DISPLAY_ENVIRONMENTS, b.name)) {
          const target = DISPLAY_ENVIRONMENTS[b.name];
          const cleaned = normalizeMath(body.trim());
          h = target === ""
            ? `\\[${cleaned}\\]`
            : `\\[${normalizeMath(`\\begin{${target}}${cleaned}\\end{${target}}`)}\\]`;
        } else if (b.name === "math") {
          h = `\\(${normalizeMath(body.trim())}\\)`;
        } else {
          h = `\\(${normalizeMath(`\\begin{${b.name}}${body}\\end{${b.name}}`)}\\)`;
        }
        s = s.slice(0, b.start) + hold(h) + s.slice(after);
        continue;
      }
    }

    let pick = null;
    let pickEnd = -1;
    for (const b of [...begins].reverse()) {
      const end = envEnd(s, b.name, b.end);
      if (end < 0) continue;
      if (/\\begin\s*\{([A-Za-z*]+)\}/.test(s.slice(b.end, end))) continue;
      pick = b;
      pickEnd = end;
      break;
    }
    if (!pick) break;
    const name = pick.name;
    let body = s.slice(pick.end, pickEnd);
    const after = pickEnd + `\\end{${name}}`.length;
    let replacement;
    if (name === "itemize" || name === "enumerate" || name === "description") {
      replacement = list(name, body);
    } else if (name === "tabular" || name === "tabular*" || name === "tabularx") {
      if (name !== "tabular") {
        const w = body.trimStart();
        if (w.startsWith("{")) body = w.slice(matchingBrace(w, 0) + 1);
      }
      replacement = `\n${hold(`\\[${tabular(body)}\\]`)}\n`;
    } else {
      let b = body;
      if (name === "minipage" || name === "figure" || name === "table" || name === "wrapfigure") {
        b = b.replace(/^\s*(\[[^\]]*\])?\s*(\{[^{}]*\})?/, "");
      }
      replacement = `\n${b.trim()}\n`;
    }
    s = s.slice(0, pick.start) + replacement + s.slice(after);
  }
  return s.replace(/\n{3,}/g, "\n\n");
}

function list(kind, body) {
  const items = body.split(/\\item\b/).slice(1);
  const out = [];
  items.forEach((raw, k) => {
    let item = raw.trim();
    let label = null;
    if (item.startsWith("[")) {
      const close = matching(item, 0, "[", "]");
      if (close > 0) {
        label = item.slice(1, close);
        item = item.slice(close + 1).trim();
      }
    }
    const lines = item.split("\n");
    const head = lines[0];
    const rest = lines.slice(1).map((l) => `   ${l}`);
    const marker = kind === "description"
      ? (label === null ? "" : `\\textbf{${label}} `)
      : label !== null
        ? `${label} `
        : kind === "enumerate"
          ? `${k + 1}. `
          : "• ";
    out.push([`${marker}${head}`, ...rest].join("\n"));
  });
  return `\n${out.join("\n")}\n`;
}

function tabular(body) {
  let b = body.trimStart();
  let spec = "l";
  if (b.startsWith("{")) {
    const close = matchingBrace(b, 0);
    spec = b.slice(1, close);
    b = b.slice(close + 1);
  }
  const rows = splitTopLevel(b, "\\\\")
    .map((r) => r.trim())
    .filter((r) => r.length)
    .map((row) => {
      let r = row;
      const rules = [];
      for (;;) {
        const m = /^\\(hline|toprule|midrule|bottomrule|cline\{[^}]*\})\s*/.exec(r);
        if (!m) break;
        rules.push("\\hline ");
        r = r.slice(m[0].length);
      }
      const cells = splitTopLevel(r, "&").map(cellToMath).join("&");
      return `${rules.join("")}${cells}`;
    });
  return `\\begin{array}{${arraySpec(spec)}}${rows.join("\\\\")}\\end{array}`;
}

function arraySpec(spec) {
  let s = spec.replace(/\*\{(\d+)\}\{([^{}]*)\}/g, (_, n, cols) => cols.repeat(Number(n) || 1));
  s = s.replace(/[@!<>]\{[^{}]*\}/g, "");
  s = s.replace(/[pmb]\{[^{}]*\}/g, "l");
  s = s.replace(/[XS]/g, "l");
  s = s.replace(/[^lcr|:]/g, "");
  return s === "" ? "l" : s;
}

const CELL_PIECE = /\u0001(\d+)\u0002|\\\(([\s\S]*?)\\\)/g;

function cellToMath(cell) {
  const c = textCommands(cell.trim());
  if (c.trim() === "") return "";
  let out = "";
  let last = 0;
  const txt = (t) => {
    if (t.trim() === "") {
      if (t.length && out.length) out += "\\ ";
      return;
    }
    out += `\\text{${escapeForText(t)}}`;
  };
  for (const m of c.matchAll(CELL_PIECE)) {
    txt(c.slice(last, m.index));
    out += m[1] !== undefined ? heldInner(Number(m[1])) : m[2];
    last = m.index + m[0].length;
  }
  txt(c.slice(last));
  return out;
}

const escapeForText = (s) => s.replace(/(?<!\\)([%&#_$])/g, "\\$1");

function splitTopLevel(s, sep) {
  const out = [];
  let depth = 0;
  let last = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c === "\\" && sep !== "\\\\") {
      i++;
      continue;
    }
    if (c === "{") depth++;
    if (c === "}") depth--;
    if (depth === 0 && s.startsWith(sep, i)) {
      if (sep === "&" && i > 0 && s[i - 1] === "\\") continue;
      out.push(s.slice(last, i));
      i += sep.length - 1;
      last = i + 1;
    } else if (c === "\\" && sep === "\\\\" && i + 1 < s.length) {
      if (s[i + 1] !== "\\") i++;
    }
  }
  out.push(s.slice(last));
  return out;
}

const COMMAND_NAME = /[A-Za-z]+\*?/;

function textCommands(s) {
  const hasTeX = s.includes("\\");
  let out = "";
  let i = 0;
  let pending = "";
  const flush = () => {
    out += pending;
    pending = "";
  };
  const lastIsNotLetter = () => out === "" || !isLetter(out[out.length - 1]);
  const emitPlain = (ch) => {
    if (ch === " " && pending !== "" && !pending.endsWith(" ")) {
      pending += " ";
      return;
    }
    if (pending.endsWith(" ")) flush();
    if (/[0-9.]/.test(ch)) {
      pending += ch;
      return;
    }
    if (isLetter(ch) && pending === "" && lastIsNotLetter()) {
      pending += ch;
      return;
    }
    flush();
    out += ch;
  };

  while (i < s.length) {
    const c = s[i];

    if (hasTeX) {
      if (s.startsWith("---", i) && !dashRun(s, i, 3)) {
        flush();
        out += "—";
        i += 3;
        continue;
      }
      if (s.startsWith("--", i) && !dashRun(s, i, 2)) {
        flush();
        out += "–";
        i += 2;
        continue;
      }
    }
    if (s.startsWith("``", i)) {
      const close = s.indexOf("''", i + 2);
      if (close > 0) {
        flush();
        out += `“${textCommands(s.slice(i + 2, close))}”`;
        i = close + 2;
        continue;
      }
    }
    if (hasTeX && c === "~") {
      flush();
      out += " ";
      i++;
      continue;
    }

    if (c !== "\\" || i + 1 >= s.length) {
      emitPlain(c);
      i++;
      continue;
    }

    const next = s[i + 1];
    if (next === "$") {
      flush();
      out += "\\$";
      i += 2;
      continue;
    }
    if (next === "\\") {
      flush();
      out += "\n";
      i += 2;
      if (s[i] === "[") {
        const close = s.indexOf("]", i);
        if (close > 0) i = close + 1;
      }
      while (s[i] === " ") i++;
      continue;
    }
    const letterAccent = isLetter(next);
    if (has(ACCENTS, next) && (!letterAccent || (s[i + 2] === "{" && at(COMMAND_NAME, s, i + 1)[0].length === 1))) {
      const r = accent(s, i);
      if (r) {
        flush();
        out += r.text;
        i = r.end;
        continue;
      }
    }
    if (has(TEXT_SYMBOLS, next)) {
      flush();
      out += TEXT_SYMBOLS[next];
      i += 2;
      continue;
    }

    const nm = at(COMMAND_NAME, s, i + 1);
    if (!nm) {
      emitPlain(c);
      i++;
      continue;
    }
    let name = nm[0];
    let p = i + 1 + name.length;
    if (name.endsWith("*") && !SECTIONS.has(name.slice(0, -1)) && name !== "vspace*" && name !== "hspace*") {
      name = name.slice(0, -1);
      p--;
    }
    const bare = name.endsWith("*") ? name.slice(0, -1) : name;

    if (KEPT_TEXT.has(name)) {
      flush();
      out += `\\${name}`;
      i = p;
      continue;
    }
    if (name === "emph" || name === "textsl") {
      flush();
      out += "\\textit";
      i = p;
      continue;
    }
    if (name === "uline") {
      flush();
      out += "\\underline";
      i = p;
      continue;
    }
    if (name === "textsc" || name === "MakeUppercase" || name === "uppercase") {
      const a = arg(s, p);
      if (a) {
        flush();
        out += textCommands(a.text).toUpperCase();
        i = a.end;
        continue;
      }
    }
    if (name === "MakeLowercase" || name === "lowercase") {
      const a = arg(s, p);
      if (a) {
        flush();
        out += textCommands(a.text).toLowerCase();
        i = a.end;
        continue;
      }
    }
    if (name === "textsuperscript" || name === "textsubscript") {
      const a = arg(s, p);
      if (a) {
        flush();
        const mark = name === "textsuperscript" ? "^" : "_";
        out += `\\(${mark}{\\text{${escapeForText(a.text)}}}\\)`;
        i = a.end;
        continue;
      }
    }
    if (SECTIONS.has(bare)) {
      let q = p;
      if (s[q] === "[") q = matching(s, q, "[", "]") + 1;
      const a = arg(s, q);
      if (a) {
        flush();
        const sep = bare === "paragraph" || bare === "subparagraph" ? " " : "\n";
        out += `\\textbf{${a.text.trim()}}${sep}`;
        i = a.end;
        while (i < s.length && sep === "\n" && (s[i] === "\n" || s[i] === " " || s[i] === "\t")) i++;
        continue;
      }
    }
    if (name === "footnote") {
      const a = arg(s, p);
      if (a) {
        flush();
        out += ` (${a.text})`;
        i = a.end;
        continue;
      }
    }
    if (name === "href") {
      const a = arg(s, p);
      const b = a ? arg(s, a.end) : null;
      if (b) {
        flush();
        out += b.text;
        i = b.end;
        continue;
      }
    }
    if (name === "textcolor" || name === "colorbox") {
      const a = arg(s, p);
      const b = a ? arg(s, a.end) : null;
      if (b) {
        flush();
        out += textCommands(b.text);
        i = b.end;
        continue;
      }
    }
    if (name === "color") {
      const a = arg(s, p);
      if (a) {
        i = a.end;
        continue;
      }
    }
    if (UNWRAPPED.has(name)) {
      const a = arg(s, p);
      if (a) {
        flush();
        out += textCommands(a.text);
        i = a.end;
        continue;
      }
    }
    if (DROPPED_WITH_ARG.has(name)) {
      let q = p;
      if (s[q] === "[") q = matching(s, q, "[", "]") + 1;
      const a = arg(s, q);
      flush();
      i = a ? a.end : p;
      continue;
    }
    if (name === "hspace" || name === "hspace*" || name === "vspace*") {
      const a = arg(s, p);
      flush();
      if (name === "hspace" || name === "hspace*") out += " ";
      i = a ? a.end : p;
      continue;
    }
    if (name === "par") {
      flush();
      out += "\n\n";
      i = p;
      continue;
    }
    if (name === "newline" || name === "linebreak" || name === "bigskip" || name === "break") {
      flush();
      out += "\n";
      i = skipSpaces(s, p);
      continue;
    }
    if (DROPPED_TEXT.has(name)) {
      flush();
      i = skipSpaces(s, p);
      continue;
    }
    if (has(TEXT_NAMED, name)) {
      flush();
      out += TEXT_NAMED[name];
      i = p;
      if (s.startsWith("{}", i)) i += 2;
      continue;
    }
    if (name === "item") {
      flush();
      out += "• ";
      i = skipSpaces(s, p);
      continue;
    }

    const end = mathRunEnd(s, i);
    if (pending.endsWith(" ") && !BINARY_OR_FUNCTION.has(bare)) flush();
    const run = pending + s.slice(i, end);
    pending = "";
    out += `\\(${normalizeMath(run.trim())}\\)`;
    i = end;
  }
  flush();
  return out;
}

function dashRun(s, i, n) {
  const before = i > 0 ? s[i - 1] : "";
  const after = i + n < s.length ? s[i + n] : "";
  return before === "-" || after === "-";
}

function arg(s, p) {
  const q = skipSpaces(s, p);
  if (s[q] === "{") {
    const close = matchingBrace(s, q);
    if (close < 0) return null;
    return { text: s.slice(q + 1, close), end: close + 1 };
  }
  return null;
}

function skipSpaces(s, p) {
  let q = p;
  while (q < s.length && (s[q] === " " || s[q] === "\t")) q++;
  return q;
}

function accent(s, i) {
  const mark = ACCENTS[s[i + 1]];
  let q = i + 2;
  let letter;
  if (s[q] === "{") {
    const close = matchingBrace(s, q);
    if (close < 0) return null;
    letter = s.slice(q + 1, close);
    q = close + 1;
  } else {
    q = skipSpaces(s, q);
    if (q >= s.length) return null;
    letter = s[q];
    q++;
  }
  if (letter === "\\i") letter = "i";
  if (letter === "\\j") letter = "j";
  if (letter === "") return { text: mark, end: q };
  return { text: `${letter[0]}${mark}${letter.slice(1)}`, end: q };
}

function mathRunEnd(s, i) {
  let p = i;
  while (p < s.length) {
    const c = s[p];
    if (c === "\\") {
      const n = s[p + 1];
      if (n === "(" || n === "[" || n === "\\" || n === "$") break;
      const nm = at(COMMAND_NAME, s, p + 1);
      if (!nm) {
        p += 2;
        continue;
      }
      const name = nm[0].replace(/\*/g, "");
      if (KEPT_TEXT.has(name) || name === "emph") break;
      p = name === "operatorname" ? p + 1 + nm[0].length : p + 1 + name.length;
      if (name === "left") {
        p = afterRight(s, p);
        continue;
      }
      if (name === "begin") {
        const env = at(/\s*\{([A-Za-z*]+)\}/, s, p);
        if (env) {
          const endTag = `\\end{${env[1]}}`;
          const e = s.indexOf(endTag, p + env[0].length);
          p = e < 0 ? s.length : e + endTag.length;
          continue;
        }
      }
      while (p < s.length) {
        if (s[p] === "{") {
          const close = matchingBrace(s, p);
          if (close < 0) return s.length;
          p = close + 1;
        } else if (s[p] === "[" && optionalArgCommand(name)) {
          const close = matching(s, p, "[", "]");
          if (close < 0) break;
          p = close + 1;
        } else {
          break;
        }
      }
      continue;
    }
    if (c === "^" || c === "_") {
      p++;
      if (s[p] === "{") {
        const close = matchingBrace(s, p);
        p = close < 0 ? s.length : close + 1;
      } else if (s[p] === "\\") {
        const nm = at(COMMAND_NAME, s, p + 1);
        p = nm ? p + 1 + nm[0].length : p + 2;
      } else if (p < s.length) {
        p++;
      }
      continue;
    }
    if (c === "{") {
      const close = matchingBrace(s, p);
      if (close < 0) break;
      p = close + 1;
      continue;
    }
    if (c === "(") {
      const close = matching(s, p, "(", ")");
      if (close < 0 || close - p > 80) break;
      p = close + 1;
      continue;
    }
    if (/[A-Za-z0-9]/.test(c)) {
      p++;
      continue;
    }
    if ("+-=*/<>|'".includes(c) || c === "&") {
      if (p + 1 < s.length && /[A-Za-z0-9\\({]/.test(s[p + 1]) && c !== "&") {
        p++;
        continue;
      }
      break;
    }
    if ((c === "." || c === ",") && p + 1 < s.length && /[0-9]/.test(s[p + 1]) && p > i && /[0-9]/.test(s[p - 1])) {
      p++;
      continue;
    }
    if (c === " " && p + 1 < s.length) {
      const rest = s.slice(p + 1);
      const word = (/^[A-Za-z]+/.exec(rest) || [])[0];
      const prevCmd = /\\([A-Za-z]+)$/.exec(s.slice(i, p));
      if (prevCmd && BINARY_OR_FUNCTION.has(prevCmd[1]) && (/^[0-9\\(]/.test(rest) || (word && word.length === 1))) {
        p++;
        continue;
      }
      if (rest.startsWith("\\")) {
        const nm = at(COMMAND_NAME, rest, 1);
        if (nm && BINARY_OR_FUNCTION.has(nm[0])) {
          p++;
          continue;
        }
      }
      break;
    }
    break;
  }
  return p;
}

const optionalArgCommand = (name) => name === "sqrt" || name.startsWith("x") || name === "SI" || name === "qty";

const BINARY_OR_FUNCTION = new Set([
  "times", "div", "cdot", "pm", "mp", "le", "leq", "ge", "geq", "neq", "ne",
  "approx", "equiv", "to", "rightarrow", "Rightarrow", "implies", "iff",
  "in", "notin", "subset", "subseteq", "cup", "cap", "sin", "cos", "tan",
  "log", "ln", "lg", "exp", "sec", "csc", "cot", "arcsin", "arccos",
  "arctan", "sinh", "cosh", "tanh", "pi", "theta", "alpha", "beta",
  "propto", "sim", "cong", "parallel", "perp", "angle", "triangle", "lt",
  "gt", "leqslant", "geqslant", "circ", "det", "lim", "sum", "int", "prod",
]);

function afterRight(s, from) {
  let depth = 1;
  let p = from;
  while (p < s.length) {
    if (s.startsWith("\\left", p) && !isLetter(s[p + 5])) {
      depth++;
      p += 5;
      continue;
    }
    if (s.startsWith("\\right", p) && !isLetter(s[p + 6])) {
      depth--;
      p += 6;
      if (depth === 0) {
        if (s[p] === "\\") {
          const nm = at(COMMAND_NAME, s, p + 1);
          p = nm ? p + 1 + nm[0].length : p + 2;
        } else if (p < s.length) {
          p++;
        }
        return p;
      }
      continue;
    }
    p++;
  }
  return s.length;
}

// ─── Maths ────────────────────────────────────────────────────────────

const MATH_RENAMES = {
  pmb: "\\boldsymbol", bm: "\\boldsymbol", emph: "\\textit", mbox: "\\text",
  hbox: "\\text", textup: "\\text", textnormal: "\\text", uline: "\\underline",
  textbackslash: "\\backslash", S: "\\text{§}", P: "\\text{¶}", euro: "\\text{€}",
  copyright: "\\text{©}", naira: "\\text{₦}", celsius: "{}^{\\circ}\\mathrm{C}",
  degreeCelsius: "{}^{\\circ}\\mathrm{C}", degree: "{}^{\\circ}", textdegree: "{}^{\\circ}",
  ohm: "\\Omega", micro: "\\mu", percent: "\\%", recurring: "\\overline",
  overarc: "\\overset{\\frown}", wideparen: "\\overset{\\frown}", overparen: "\\overset{\\frown}",
  limits: "", nolimits: "", nonumber: "", notag: "", displaybreak: "", allowbreak: "",
  smash: "", centering: "",
};
const MATH_ENV_RENAMES = {
  gathered: "array}{c", gather: "array}{c", "gather*": "array}{c", multline: "array}{c",
  "multline*": "array}{c", split: "aligned", align: "aligned", "align*": "aligned",
  flalign: "aligned", "flalign*": "aligned", eqnarray: "aligned", "eqnarray*": "aligned",
  alignat: "alignedat", "alignat*": "alignedat", equation: "", "equation*": "",
  "dcases*": "dcases", "cases*": "cases",
};

function normalizeMath(tex) {
  if (!tex.includes("\\")) return tex;
  let s = tex.replace(/\\(begin|end)\{([A-Za-z]+\*?)\}/g, (m, kind, env) => {
    if (!has(MATH_ENV_RENAMES, env)) return m;
    const to = MATH_ENV_RENAMES[env];
    if (to === "") return "";
    if (kind === "end") return `\\end{${to.split("}")[0]}}`;
    return `\\begin{${to}}`;
  });
  s = rewriteArraySpecs(s);

  let out = "";
  const tags = [];
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c !== "\\") {
      out += c;
      i++;
      continue;
    }
    const nm = at(COMMAND_NAME, s, i + 1);
    if (!nm) {
      out += s.slice(i, Math.min(i + 2, s.length));
      i += 2;
      continue;
    }
    let name = nm[0];
    let p = i + 1 + name.length;
    if (name.endsWith("*") && name !== "operatorname*") {
      name = name.slice(0, -1);
      p--;
    }

    let done = false;
    switch (name) {
      case "ce":
      case "pu": {
        const a = arg(s, p);
        if (a) {
          out += name === "ce" ? ceToTex(a.text) : pu(a.text);
          i = a.end;
          done = true;
        }
        break;
      }
      case "si":
      case "unit": {
        const a = arg(s, skipOptional(s, p));
        if (a) {
          out += siUnitToTex(a.text);
          i = a.end;
          done = true;
        }
        break;
      }
      case "SI":
      case "qty": {
        const a = arg(s, skipOptional(s, p));
        const b = a ? arg(s, skipOptional(s, a.end)) : null;
        if (b) {
          out += `${num(a.text)}\\,${siUnitToTex(b.text)}`;
          i = b.end;
          done = true;
        }
        break;
      }
      case "num": {
        const a = arg(s, skipOptional(s, p));
        if (a) {
          out += num(a.text);
          i = a.end;
          done = true;
        }
        break;
      }
      case "ang": {
        const a = arg(s, skipOptional(s, p));
        if (a) {
          const parts = a.text.split(";");
          const marks = ["^{\\circ}", "'", "''"];
          let b = "";
          for (let k = 0; k < parts.length && k < 3; k++) {
            if (parts[k].trim() === "") continue;
            b += `${parts[k].trim()}${marks[k]}`;
          }
          out += b;
          i = a.end;
          done = true;
        }
        break;
      }
      case "nicefrac":
      case "sfrac":
      case "xfrac": {
        const a = arg(s, p);
        const b = a ? arg(s, a.end) : null;
        if (b) {
          out += `{}^{${a.text}}\\!/_{${b.text}}`;
          i = b.end;
          done = true;
        }
        break;
      }
      case "substack": {
        const a = arg(s, p);
        if (a) {
          out += `\\begin{array}{c}${a.text}\\end{array}`;
          i = a.end;
          done = true;
        }
        break;
      }
      case "sideset": {
        const a = arg(s, p);
        const b = a ? arg(s, a.end) : null;
        if (b) {
          i = b.end;
          done = true;
        }
        break;
      }
      case "tag": {
        const a = arg(s, p);
        if (a) {
          tags.push(a.text);
          i = a.end;
          done = true;
        }
        break;
      }
      case "label":
      case "mspace":
      case "hspace":
      case "vspace": {
        const a = arg(s, p);
        if (a) {
          if (name === "mspace" || name === "hspace") out += "\\,";
          i = a.end;
          done = true;
        }
        break;
      }
      case "textsc": {
        const a = arg(s, p);
        if (a) {
          out += `\\text{${a.text.toUpperCase()}}`;
          i = a.end;
          done = true;
        }
        break;
      }
      default:
        break;
    }
    if (done) continue;
    if (has(MATH_RENAMES, name)) {
      const to = MATH_RENAMES[name];
      out += to;
      i = p;
      if (to !== "" && /[A-Za-z]$/.test(to) && i < s.length && isLetter(s[i])) out += " ";
      continue;
    }
    out += `\\${name}`;
    i = p;
  }
  for (const t of tags) out += `\\qquad(${t})`;
  return out;
}

function skipOptional(s, p) {
  const q = skipSpaces(s, p);
  if (s[q] === "[") {
    const close = matching(s, q, "[", "]");
    if (close > 0) return close + 1;
  }
  return q;
}

function rewriteArraySpecs(s) {
  const re = /\\begin\{(array|subarray)\}/g;
  let out = "";
  let last = 0;
  for (const m of s.matchAll(re)) {
    if (m.index < last) continue;
    const open = m.index + m[0].length;
    if (s[open] !== "{") continue;
    const close = matchingBrace(s, open);
    if (close < 0) continue;
    out += s.slice(last, open) + `{${arraySpec(s.slice(open + 1, close))}}`;
    last = close + 1;
  }
  return out + s.slice(last);
}

// ─── siunitx ──────────────────────────────────────────────────────────

const SI_PREFIXES = {
  yocto: "y", zepto: "z", atto: "a", femto: "f", pico: "p", nano: "n",
  micro: "\\mu ", milli: "m", centi: "c", deci: "d", deca: "da", deka: "da",
  hecto: "h", kilo: "k", mega: "M", giga: "G", tera: "T", peta: "P", exa: "E",
};
const SI_UNITS = {
  metre: "m", meter: "m", gram: "g", kilogram: "kg", second: "s",
  ampere: "A", kelvin: "K", mole: "mol", candela: "cd",
  newton: "N", joule: "J", watt: "W", pascal: "Pa", hertz: "Hz",
  coulomb: "C", volt: "V", ohm: "\\Omega", farad: "F",
  tesla: "T", henry: "H", weber: "Wb", siemens: "S",
  becquerel: "Bq", gray: "Gy", sievert: "Sv", lumen: "lm",
  lux: "lx", radian: "rad", steradian: "sr", litre: "L",
  liter: "L", tonne: "t", minute: "min", hour: "h", day: "d",
  electronvolt: "eV", bar: "bar", angstrom: "Å", astronomicalunit: "au",
  dalton: "Da", hectare: "ha", decibel: "dB", neper: "Np",
  percent: "\\%", atomicmassunit: "u", mmHg: "mmHg",
  arcminute: "'", arcsecond: "''",
};

function siUnitToTex(unit) {
  const u = unit.trim();
  if (u === "") return "";
  if (!u.includes("\\")) return literalUnit(u);
  const terms = [];
  let prefix = "";
  let per = false;
  let power = "";
  let pendingPower = null;
  let i = 0;
  const reset = () => {
    prefix = "";
    per = false;
    power = "";
    pendingPower = null;
  };
  while (i < u.length) {
    if (u[i] !== "\\") {
      const m = at(/[A-Za-z]+/, u, i);
      if (m) {
        terms.push(unitTerm(`${prefix}${m[0]}`, per, power, pendingPower));
        reset();
        i += m[0].length;
      } else {
        i++;
      }
      continue;
    }
    const nm = at(/[A-Za-z]+/, u, i + 1);
    if (!nm) {
      i += 2;
      continue;
    }
    const name = nm[0];
    i = i + 1 + name.length;
    if (name === "per") per = true;
    else if (name === "square") power = "2";
    else if (name === "cubic") power = "3";
    else if (name === "squared" || name === "cubed") {
      const pw = name === "squared" ? "2" : "3";
      if (terms.length) terms[terms.length - 1] = repower(terms[terms.length - 1], pw);
    } else if (name === "tothe" || name === "raiseto") {
      const a = arg(u, i);
      if (a) {
        if (name === "tothe" && terms.length) terms[terms.length - 1] = repower(terms[terms.length - 1], a.text);
        else pendingPower = a.text;
        i = a.end;
      }
    } else if (has(SI_PREFIXES, name)) {
      prefix += SI_PREFIXES[name];
    } else if (has(SI_UNITS, name)) {
      terms.push(unitTerm(`${prefix}${SI_UNITS[name]}`, per, power, pendingPower));
      reset();
    } else if (name === "degreeCelsius" || name === "celsius") {
      terms.push("{}^{\\circ}\\mathrm{C}");
    } else if (name === "degree") {
      terms.push("{}^{\\circ}");
    } else {
      terms.push(`\\${name}`);
    }
  }
  return terms.join("\\,");
}

function unitTerm(symbol, per, power, raise) {
  const body = symbol.startsWith("\\") && !symbol.startsWith("\\mu") ? symbol : `\\mathrm{${symbol}}`;
  let exp = raise ?? power;
  if (per) exp = exp === "" ? "-1" : `-${exp}`;
  return exp === "" ? body : `${body}^{${exp}}`;
}

function repower(term, pw) {
  const m = /\^\{(-?)([^{}]*)\}$/.exec(term);
  if (!m) return `${term}^{${pw}}`;
  return `${term.slice(0, m.index)}^{${m[1]}${pw}}`;
}

function literalUnit(u) {
  let b = "";
  let i = 0;
  let first = true;
  while (i < u.length) {
    const c = u[i];
    const word = at(/[A-Za-zµΩ°%]+/, u, i);
    if (word) {
      if (!first && !b.endsWith("/")) b += "\\,";
      const w = word[0].replace(/µ/g, "\\mu ").replace(/Ω/g, "\\Omega ").replace(/%/g, "\\%");
      b += w.includes("°") ? `${w.replace(/°/g, "{}^{\\circ}\\mathrm{")}}` : `\\mathrm{${w}}`;
      first = false;
      i += word[0].length;
      continue;
    }
    if (c === "^") {
      i++;
      if (u[i] === "{") {
        const close = matchingBrace(u, i);
        b += `^{${u.slice(i + 1, close)}}`;
        i = close + 1;
      } else {
        const e = at(/-?[0-9]+/, u, i);
        if (e) {
          b += `^{${e[0]}}`;
          i += e[0].length;
        }
      }
      continue;
    }
    if (c === "/") {
      b += "/";
      i++;
      continue;
    }
    i++;
  }
  return b.split("\\mathrm{}").join("");
}

function num(n) {
  const t = n.trim().replace(/ /g, "");
  const m = /^([+-]?[0-9.,]+)[eE]([+-]?[0-9]+)$/.exec(t);
  if (m) return `${m[1]}\\times10^{${m[2]}}`;
  return t.replace(/x/g, "\\times ").replace(/\+-/g, "\\pm ");
}

function pu(s) {
  const m = /^\s*([+-]?[0-9.,]+(?:[eE][+-]?[0-9]+)?)\s*([\s\S]*)$/.exec(s);
  if (!m) return literalUnit(s);
  const unit = m[2].trim();
  return unit === "" ? num(m[1]) : `${num(m[1])}\\,${literalUnit(unit)}`;
}

// ─── mhchem ───────────────────────────────────────────────────────────

function ceToTex(input) {
  return ceTokens(input.trim()).map(ceToken).join(" ").replace(/ +/g, " ").trim();
}

function ceTokens(s) {
  const out = [];
  let b = "";
  let depth = 0;
  for (const c of s) {
    if (c === "[" || c === "{") depth++;
    if (c === "]" || c === "}") depth--;
    if (c === " " && depth === 0) {
      if (b) out.push(b);
      b = "";
      continue;
    }
    b += c;
  }
  if (b) out.push(b);
  return out;
}

const CE_ARROWS = [
  ["<=>>", "\\rightleftharpoons"],
  ["<<=>", "\\rightleftharpoons"],
  ["<=>", "\\rightleftharpoons"],
  ["<-->", "\\leftrightarrows"],
  ["<->", "\\leftrightarrow"],
  ["->", "\\rightarrow"],
  ["<-", "\\leftarrow"],
  ["=", "="],
];

function ceToken(t) {
  if (t === "+") return "+";
  if (t === "^") return "\\uparrow";
  if (t === "v") return "\\downarrow";
  if (t === "." || t === "*") return "\\cdot";
  for (const [a, arrow] of CE_ARROWS) {
    if (t.startsWith(a)) {
      const rest = t.slice(a.length);
      const conds = [...rest.matchAll(/\[([^\]]*)\]/g)].map((m) => m[1]);
      if (!conds.length) return arrow;
      const cond = (c) => (c.startsWith("$") && c.endsWith("$") ? c.slice(1, -1) : `\\text{${c}}`);
      if (arrow === "\\rightarrow" || arrow === "\\leftarrow") {
        const x = arrow === "\\rightarrow" ? "\\xrightarrow" : "\\xleftarrow";
        return conds.length > 1 ? `${x}[${cond(conds[1])}]{${cond(conds[0])}}` : `${x}{${cond(conds[0])}}`;
      }
      const over = `\\overset{${cond(conds[0])}}{${arrow}}`;
      return conds.length > 1 ? `\\underset{${cond(conds[1])}}{${over}}` : over;
    }
  }
  return ceSpecies(t);
}

function ceSpecies(t) {
  let b = "";
  let i = 0;
  const coef = /^([0-9]+(?:[./][0-9]+)?|[a-z](?=[A-Z(]))/.exec(t);
  if (coef) {
    b += `${coef[0]}\\,`;
    i = coef[0].length;
  }
  let afterAtom = false;
  while (i < t.length) {
    const c = t[i];
    const state = at(/\((s|l|g|aq|aq\.|cr|ppt)\)/, t, i);
    if (state) {
      b += `\\,(\\mathrm{${state[1]}})`;
      i += state[0].length;
      afterAtom = false;
      continue;
    }
    if (c === "^") {
      i++;
      let charge;
      if (t[i] === "{") {
        const close = matchingBrace(t, i);
        charge = t.slice(i + 1, close);
        i = close + 1;
      } else {
        const m = at(/[0-9]*[+-]|[0-9]+/, t, i);
        charge = m ? m[0] : "";
        i += m ? m[0].length : 0;
      }
      b += `^{${charge}}`;
      afterAtom = false;
      continue;
    }
    if (c === "_") {
      i++;
      if (t[i] === "{") {
        const close = matchingBrace(t, i);
        b += `_{${t.slice(i + 1, close)}}`;
        i = close + 1;
      } else if (i < t.length) {
        b += `_{${t[i]}}`;
        i++;
      }
      continue;
    }
    const el = at(/[A-Z][a-z]?/, t, i);
    if (el) {
      b += `\\mathrm{${el[0]}}`;
      i += el[0].length;
      afterAtom = true;
      continue;
    }
    const digits = at(/[0-9]+/, t, i);
    if (digits) {
      b += afterAtom ? `_{${digits[0]}}` : digits[0];
      i += digits[0].length;
      continue;
    }
    if (c === "(" || c === "[") {
      b += c;
      i++;
      afterAtom = false;
      continue;
    }
    if (c === ")" || c === "]") {
      b += c;
      i++;
      afterAtom = true;
      continue;
    }
    if (c === "." || c === "*" || c === "·") {
      b += "\\cdot ";
      i++;
      afterAtom = false;
      const n = at(/[0-9]+/, t, i);
      if (n) {
        b += n[0];
        i += n[0].length;
      }
      continue;
    }
    if ((c === "+" || c === "-") && i === t.length - 1 && i > 0) {
      b += `^{${c}}`;
      i++;
      continue;
    }
    const charge = at(/([0-9])([+-])$/, t, i);
    if (charge && afterAtom) {
      b += `^{${charge[1]}${charge[2]}}`;
      i += charge[0].length;
      continue;
    }
    if (c === "\\") {
      const nm = at(COMMAND_NAME, t, i + 1);
      const end = nm ? i + 1 + nm[0].length : i + 2;
      b += t.slice(i, end);
      i = end;
      continue;
    }
    if (c === "$") {
      const close = t.indexOf("$", i + 1);
      if (close > i) {
        b += t.slice(i + 1, close);
        i = close + 1;
        continue;
      }
    }
    if (/[a-z]/.test(c)) {
      b += `\\mathrm{${c}}`;
      i++;
      afterAtom = true;
      continue;
    }
    b += c;
    i++;
  }
  const adjacent = /(\\mathrm\{[A-Za-z]+)\}\\mathrm\{/g;
  while (/(\\mathrm\{[A-Za-z]+)\}\\mathrm\{/.test(b)) b = b.replace(adjacent, "$1");
  return b;
}

module.exports = { normalizeTex, normalizeMath, dollarMathToParens, ceToTex, siUnitToTex, arraySpec };
