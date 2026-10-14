#!/usr/bin/env node
/**
 * Lints what students can see right now: every published Learn item.
 *
 *   node content_lint.js            # all subjects
 *   node content_lint.js --json     # machine-readable, for CI
 *
 * Read-only. It never writes; it prints ids so a reviewer can fix or
 * unpublish each one in the studio. Exits 1 when anything fails, so CI can
 * gate on it.
 *
 * The rules mirror `checkPublishable` in lib/core/lessons/lesson_check.dart,
 * which the editor applies before publishing — change both together:
 *   - a placeholder title (`test2`, `test_article`, `Sample`, `lorem…`);
 *   - an empty title, an article with no text, a video with no link;
 *   - maths that fails to parse (KaTeX with throwOnError — close to, not
 *     identical with, flutter_math_fork; the editor's check is the exact
 *     one, this catches what predates it).
 *
 * Cost: one collection-group query over published resources — a few
 * hundred reads at most.
 */
const katex = require("katex");
const { initAdmin } = require("./credential");

const JSON_OUT = process.argv.includes("--json");

/** Mirrors `placeholderTitle` in lesson_check.dart. */
const PLACEHOLDER_TITLE = new RegExp(
  "^(?:(?:test|testing|sample|placeholder|todo|asdf\\w*|x{3,}|untitled|dummy|foo|bar)" +
    "[\\s_\\-]*\\d*[\\s_\\-]*(?:article|video|exercise|lesson)?\\d*" +
    "|.*\\blorem\\b.*" +
    "|[a-z0-9]+(?:_[a-z0-9]+)+)$",
  "i"
);

/** Maths spans, matched the way FullLatexView matches them. */
function mathProblems(body) {
  const out = [];
  const s = String(body || "").replace(/\r\n/g, "\n");
  let pos = 0;
  const check = (tex) => {
    try {
      katex.renderToString(tex, { throwOnError: true, strict: "ignore" });
    } catch (e) {
      out.push(`maths won't render: ${tex.slice(0, 40)}`);
    }
  };
  while (pos < s.length) {
    if (s[pos] === "\\" && s[pos + 1] === "$") {
      pos += 2;
      continue;
    }
    if (s[pos] === "\\" && (s[pos + 1] === "(" || s[pos + 1] === "[")) {
      const close = s[pos + 1] === "(" ? "\\)" : "\\]";
      const end = s.indexOf(close, pos + 2);
      if (end < 0) {
        out.push(`'${s.slice(pos, pos + 2)}' is never closed`);
        pos += 2;
        continue;
      }
      check(s.slice(pos + 2, end));
      pos = end + 2;
      continue;
    }
    if (s.startsWith("$$", pos)) {
      const end = s.indexOf("$$", pos + 2);
      if (end > pos + 2) {
        check(s.slice(pos + 2, end));
        pos = end + 2;
        continue;
      }
    }
    pos++;
  }
  return out;
}

function problemsFor(r) {
  const out = [];
  const title = String(r.title || "").trim();
  if (!title) out.push("empty title");
  else if (PLACEHOLDER_TITLE.test(title)) out.push(`placeholder title "${title}"`);
  if (r.type === "article") {
    if (!String(r.body || "").trim()) out.push("article has no text");
    out.push(...mathProblems(r.body));
  }
  if (r.type === "video" && !String(r.youtubeId || "").trim()) {
    out.push("video has no YouTube link");
  }
  return out;
}

async function main() {
  const db = initAdmin().firestore();
  const published = await db
    .collectionGroup("resources")
    .where("status", "==", "published")
    .get();

  const failures = [];
  for (const doc of published.docs) {
    const problems = problemsFor(doc.data());
    if (problems.length) {
      failures.push({
        topicId: doc.ref.parent.parent.id,
        resourceId: doc.id,
        problems,
      });
    }
  }

  if (JSON_OUT) {
    console.log(JSON.stringify({ checked: published.size, failures }, null, 2));
  } else {
    console.log(`Checked ${published.size} published items.`);
    for (const f of failures) {
      console.log(`  topics/${f.topicId}/resources/${f.resourceId}`);
      for (const p of f.problems) console.log(`    - ${p}`);
    }
    console.log(failures.length ? `${failures.length} failing.` : "All clean.");
  }
  process.exit(failures.length ? 1 : 0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(2);
  });
}

module.exports = { PLACEHOLDER_TITLE, problemsFor, mathProblems };
