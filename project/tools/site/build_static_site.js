#!/usr/bin/env node
/**
 * The post-build step: static, indexable pages for every WAEC past
 * question, written into the Flutter build so one `firebase deploy --only
 * hosting` ships both — and the unused KaTeX fonts trimmed from the build
 * (`trim_fonts.js`).
 *
 *   flutter build web --release
 *   node tools/site/build_static_site.js [--refresh] [--origin=https://…] [--out=build/web]
 *
 * Why: the app draws on a canvas, so search engines see nothing in it. A
 * student searching "WAEC 2018 mathematics question" should land on that
 * question, see it rendered properly, and be one tap from practising the
 * topic in the app (PLAN.md Phase 3). The app stays at `/`; these live at
 * `/past-questions/**`. Hosting serves a real file before the SPA rewrite,
 * which only covers the app's own routes, so a missing page here gets this
 * script's `404.html` with a real 404 status.
 *
 * Only past questions (`source == 'waec'`, `hasAnswer: true`, a real
 * `correctIndex`). Generated practice questions are never published here
 * — they are not past questions, and that line is the point of Wave A.
 *
 * **Reads.** About one per question plus one per diagram — ~4,500 on the
 * first run, against a 50,000-a-day Spark quota. Everything read is cached
 * in `tools/site/.cache/` (gitignored), so later builds read nothing;
 * `--refresh` re-reads. Run the refresh at most daily, never in a loop.
 *
 * Writes nothing to Firestore.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { execSync } = require("child_process");
const { initAdmin } = require("../admin/credential");
const { svgProblem } = require("../admin/svg_safety");
const R = require("./render");
const { trimFonts } = require("./trim_fonts");
const { siteOrigin, DEFAULT_ORIGIN } = require("./origin");

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v ?? true];
  }),
);
// The site address: `--origin`, else `kSiteOrigin` (origin.js).
const ORIGIN = String(args.origin || siteOrigin()).replace(/\/$/, "");
R.configure({ origin: ORIGIN });
const OUT = path.resolve(__dirname, "..", "..", args.out || "build/web");
const CACHE = path.join(__dirname, ".cache");
const BASE = "past-questions";

// ─── Data ────────────────────────────────────────────────────────────

const QUESTION_FIELDS = [
  "text", "options", "correctIndex", "explanation", "year",
  "subjectId", "topicId", "imageId", "explanationImageId",
  // Other topics a question also counts for (studio, 2026-10-17); read on
  // the next --refresh.
  "alsoTopicIds",
];

async function loadData() {
  const file = path.join(CACHE, "data.json");
  if (!args.refresh && fs.existsSync(file)) {
    console.log("Using cached data (pass --refresh to re-read Firestore).");
    return JSON.parse(fs.readFileSync(file, "utf8"));
  }
  const db = initAdmin().firestore();
  console.log("Reading subjects, topics and past questions…");
  const [subjects, topics, questions] = await Promise.all([
    db.collection("subjects").get(),
    db.collection("topics").get(),
    db.collection("questions")
      .where("source", "==", "waec")
      .where("hasAnswer", "==", true)
      .select(...QUESTION_FIELDS)
      .get(),
  ]);
  const imageIds = new Set();
  for (const d of questions.docs) {
    const q = d.data();
    if (q.imageId) imageIds.add(q.imageId);
    if (q.explanationImageId) imageIds.add(q.explanationImageId);
  }
  const assets = {};
  const ids = [...imageIds];
  for (let i = 0; i < ids.length; i += 100) {
    const refs = ids.slice(i, i + 100).map((id) => db.collection("lessonAssets").doc(id));
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) {
        const a = snap.data();
        assets[snap.id] = { mime: a.mime, data: a.data, width: a.width, height: a.height };
      }
    }
  }
  const data = {
    readAt: new Date().toISOString(),
    subjects: subjects.docs.map((d) => ({ id: d.id, name: d.data().name })),
    topics: topics.docs.map((d) => ({
      id: d.id, name: d.data().name, subjectId: d.data().subjectId, order: d.data().order ?? 0,
    })),
    questions: questions.docs.map((d) => ({ id: d.id, ...d.data() })),
    assets,
  };
  fs.mkdirSync(CACHE, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(data));
  console.log(
    `Read ${subjects.size + topics.size + questions.size + Object.keys(assets).length} documents.`,
  );
  return data;
}

/** A question is published only if a student could check it. */
function publishable(q) {
  return (
    Number.isInteger(q.year) &&
    Array.isArray(q.options) &&
    q.options.length >= 2 &&
    q.options.length <= 5 &&
    Number.isInteger(q.correctIndex) &&
    q.correctIndex >= 0 &&
    q.correctIndex < q.options.length &&
    String(q.text || "").trim() !== ""
  );
}

// ─── Output ──────────────────────────────────────────────────────────

const written = [];
/** Question pages over the warning size, listed after the build. */
const heavyPages = [];
function write(rel, html, { sitemap = true, budget = false } = {}) {
  const file = path.join(OUT, rel);
  // Plan v2 6.6: a question page over budget stops the build.
  if (budget && Buffer.byteLength(html) > R.PAGE_WARN) heavyPages.push([rel, Buffer.byteLength(html)]);
  if (budget && Buffer.byteLength(html) > R.PAGE_BUDGET) {
    throw new Error(`${rel} is ${Math.round(Buffer.byteLength(html) / 1024)} KB, over the ${R.PAGE_BUDGET / 1024} KB page budget`);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, html);
  if (sitemap && rel.endsWith("index.html")) {
    written.push({
      url: `${ORIGIN}/${rel.replace(/index\.html$/, "")}`,
      hash: crypto.createHash("sha1").update(html).digest("hex"),
    });
  }
}

/**
 * Titles and descriptions for every question page, unique across the site
 * (audit E5: 86 titles and 34 descriptions were shared, because questions
 * that start alike truncate alike). Within a clash the stem is lengthened,
 * then the first options are added, then, for true duplicates (the same
 * question twice in a paper, audit A5), a short id.
 */
function questionHeads(questions, subjects) {
  const opts = (q) => q.options.slice(0, 2).map((o) => R.truncate(R.plainMath(o), 18)).join(", ");
  const steps = [
    (q, s) => [`WAEC ${q.year} ${s.name}: ${R.truncate(R.plainMath(q.text), 60)}`, 120],
    (q, s) => [`WAEC ${q.year} ${s.name}: ${R.truncate(R.plainMath(q.text), 110)}`, 200],
    (q, s) => [`WAEC ${q.year} ${s.name}: ${R.truncate(R.plainMath(q.text), 110)} (options: ${opts(q)})`, 200],
    (q, s) => [`WAEC ${q.year} ${s.name}: ${R.truncate(R.plainMath(q.text), 100)} (${q.id.slice(0, 4)})`, 200],
  ];
  const level = new Map(questions.map((q) => [q.id, 0]));
  const head = (q) => {
    const s = subjects.get(q.subjectId);
    const [stem, n] = steps[level.get(q.id)](q, s);
    const lv = level.get(q.id);
    const more = lv >= 2 ? ` (options: ${opts(q)}${lv >= 3 ? `; ref ${q.id.slice(0, 4)}` : ""})` : "";
    return {
      stem,
      title: `${stem} | Paragon`,
      description:
        `WAEC ${q.year} ${s.name} past question with the answer${q.explanation ? " and a worked explanation" : ""}: ` +
        `${R.truncate(R.plainMath(q.text), n)}${more}`,
    };
  };
  for (let round = 0; round < steps.length - 1; round++) {
    for (const field of ["title", "description"]) {
      const groups = new Map();
      for (const q of questions) {
        const k = head(q)[field];
        groups.set(k, [...(groups.get(k) || []), q]);
      }
      for (const group of groups.values()) {
        if (group.length > 1) {
          for (const q of group) level.set(q.id, Math.min(level.get(q.id) + 1, steps.length - 1));
        }
      }
    }
  }
  const heads = new Map(questions.map((q) => [q.id, head(q)]));
  const titles = new Set();
  for (const [id, h] of heads) {
    if (titles.has(h.title)) throw new Error(`Duplicate page title after de-duplication: ${h.title} (${id})`);
    titles.add(h.title);
  }
  const descriptions = new Set([...heads.values()].map((h) => h.description));
  if (descriptions.size < heads.size) {
    console.warn(`${heads.size - descriptions.size} question pages still share a description.`);
  }
  return heads;
}

/** Links are root-relative: the pages are always served from the site root
 *  (production and preview channels alike). Kept as a function so a
 *  sub-path deploy would be a one-line change. */
const rootFrom = () => "/";

const EXT = { "image/webp": "webp", "image/jpeg": "jpg", "image/png": "png", "image/svg+xml": "svg" };
function imageTag(assets, id, alt, root) {
  const a = id && assets[id];
  const ext = a && EXT[a.mime];
  if (!ext) return "";
  // An SVG becomes a document on the app's own origin when opened
  // directly, so one that could run or fetch anything stops the build
  // (svg_safety.js). Firestore ids are [A-Za-z0-9], but the id names a
  // file here, so it is checked too.
  if (!/^[A-Za-z0-9_-]+$/.test(String(id))) throw new Error(`Unexpected lesson asset id: ${id}`);
  if (a.mime === "image/svg+xml") {
    const problem = svgProblem(a.data);
    if (problem) throw new Error(`lessonAssets/${id} is an unsafe SVG (${problem}); replace it before building.`);
  }
  const rel = `${BASE}/img/${id}.${ext}`;
  const file = path.join(OUT, rel);
  if (!fs.existsSync(file)) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, a.mime === "image/svg+xml" ? a.data : Buffer.from(a.data, "base64"));
  }
  const w = Number.isInteger(a.width) ? a.width : 0;
  const h = Number.isInteger(a.height) ? a.height : 0;
  const size = w > 0 && h > 0 ? ` width="${w}" height="${h}"` : "";
  return `<figure class="diagram"><img src="${root}${rel}" alt="${R.escapeHtml(alt)}" loading="lazy"${size}></figure>`;
}

function optionsList(q) {
  return `<ol class="options">${q.options
    .map((o, i) => `<li><span class="letter">${R.LETTERS[i]}</span><span>${R.renderRich(o)}</span></li>`)
    .join("")}</ol>`;
}

function breadcrumb(items) {
  return `<nav class="crumbs">${items
    .map(([label, href]) => (href ? `<a href="${href}">${R.escapeHtml(label)}</a>` : `<span>${R.escapeHtml(label)}</span>`))
    .join(" › ")}</nav>`;
}

function build(data) {
  const subjects = new Map(data.subjects.map((s) => [s.id, { ...s, slug: R.slugify(s.name) }]));
  const topics = new Map(data.topics.map((t) => [t.id, t]));

  // Topic slugs, unique within a subject.
  const topicSlug = new Map();
  for (const s of subjects.values()) {
    const used = new Set();
    for (const t of data.topics.filter((t) => t.subjectId === s.id).sort((a, b) => a.order - b.order)) {
      let slug = R.slugify(t.name) || t.id;
      for (let n = 2; used.has(slug); n++) slug = `${R.slugify(t.name)}-${n}`;
      used.add(slug);
      topicSlug.set(t.id, slug);
    }
  }

  const questions = data.questions.filter(publishable).filter((q) => subjects.has(q.subjectId));
  const bySubject = new Map();
  for (const q of questions) {
    if (!bySubject.has(q.subjectId)) bySubject.set(q.subjectId, []);
    bySubject.get(q.subjectId).push(q);
  }

  const qDir = (s, q) => `${BASE}/waec/${s.slug}/${q.year}/${q.id.slice(0, 10)}/`;
  // Readable app links (audit C9): the app resolves slugs to ids.
  const appTopic = (s, t) => `/subject/${s.slug}/course/topic/${R.slugify(t.name)}`;
  const heads = questionHeads(questions, subjects);
  // Readable in a list: maths as text, never TeX source (audit B3).
  const preview = (q) => R.escapeHtml(R.truncate(R.plainMath(q.text), 160));
  /** What a question page has that the archive it came from does not
   *  (Plan v2 6.3): how often its topic is examined, and its nearest
   *  neighbours in the topic. Each block appears only with data behind it. */
  const valueBlocks = (q, t, s, inTopic, subjectTotal, root) => {
    if (!t) return "";
    const phrase = R.frequencyPhrase(inTopic.length, subjectTotal);
    const similar = R.similarQuestions(inTopic, q);
    const parts = [];
    if (phrase) {
      parts.push(`<h2>How often this comes up</h2>
<p>${R.escapeHtml(t.name)}: ${phrase.replace("WAEC", `WAEC ${R.escapeHtml(s.name)}`)}, going by Paragon's past papers.</p>`);
    }
    if (similar.length) {
      parts.push(`<h2>Similar questions</h2>
<ul class="list">${similar.map((x) => `<li><a href="${root}${qDir(s, x)}">WAEC ${x.year}: ${preview(x)}</a></li>`).join("")}</ul>`);
    }
    return parts.length ? `<section class="related">${parts.join("\n")}</section>` : "";
  };
  // The visible breadcrumb's trail as JSON-LD, with absolute URLs (E7).
  const crumbsLd = (items) =>
    R.breadcrumbJsonLd(items.map(([label, rel]) => [label, rel == null ? undefined : `${ORIGIN}/${rel}`]));
  const listLd = (name, list, s) => R.itemListJsonLd(name, list.map((q) => `${ORIGIN}/${qDir(s, q)}`));

  const subjectCards = [];
  for (const [subjectId, list] of bySubject) {
    const s = subjects.get(subjectId);
    list.sort((a, b) => a.year - b.year || (a.id < b.id ? -1 : 1));
    const years = [...new Set(list.map((q) => q.year))].sort((a, b) => b - a);
    const sDir = `${BASE}/waec/${s.slug}/`;
    // Each topic's questions in this subject, for the frequency line and
    // "Similar questions" (Plan v2 6.3).
    const byTopic = new Map();
    for (const q of list) {
      if (!byTopic.has(q.topicId)) byTopic.set(q.topicId, []);
      byTopic.get(q.topicId).push(q);
    }

    // One page per question.
    for (const year of years) {
      const inYear = list.filter((q) => q.year === year);
      inYear.forEach((q, i) => {
        const dir = qDir(s, q);
        const root = rootFrom(dir);
        const t = topics.get(q.topicId);
        const tSlug = t && topicSlug.get(t.id);
        const prev = inYear[i - 1];
        const next = inYear[i + 1];
        const url = `${ORIGIN}/${dir}`;
        const head = heads.get(q.id);
        const answer = `${R.LETTERS[q.correctIndex]}. ${R.renderRich(q.options[q.correctIndex])}`;
        const body = `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [String(year), `${root}${sDir}${year}/`]])}
<p class="kicker">WAEC ${year} · ${R.escapeHtml(s.name)} · objective question</p>
<h1 class="stem">${R.renderRich(q.text)}</h1>
${imageTag(data.assets, q.imageId, `Diagram for the question: ${R.truncate(R.plainMath(q.text), 110)}`, root)}
${optionsList(q)}
<details class="answer"><summary>Show answer</summary>
<p><strong>Answer: ${answer}</strong></p>
${q.explanation ? `<div class="explanation">${R.renderRich(q.explanation)}</div>` : q.explanationImageId ? "" : `<p class="muted">No worked answer yet for this question.</p>`}
${imageTag(data.assets, q.explanationImageId, `Worked answer to: ${R.truncate(R.plainMath(q.text), 110)}`, root)}
</details>
<div class="cta">
${t ? `<a class="button" href="${appTopic(s, t)}">Practise ${R.escapeHtml(t.name)} in Paragon</a>` : ""}
<a class="button secondary" href="/waec/${s.slug}/setup">Sit a WAEC ${R.escapeHtml(s.name)} paper</a>
</div>
${t && tSlug ? `<p>Topic: <a href="${root}${sDir}topic/${tSlug}/">${R.escapeHtml(t.name)}: every past question</a></p>` : ""}
${valueBlocks(q, t, s, byTopic.get(q.topicId) || [], list.length, root)}
<nav class="pager">${prev ? `<a href="${root}${qDir(s, prev)}">← Previous</a>` : "<span></span>"}${next ? `<a href="${root}${qDir(s, next)}">Next →</a>` : "<span></span>"}</nav>`;
        write(`${dir}index.html`, R.page({
          // No question number: Paragon does not have the paper's own
          // numbering, and its order is not WAEC's.
          title: head.title,
          description: head.description,
          canonical: url,
          body,
          jsonLd: [
            R.quizJsonLd({ q, subjectName: s.name, url, name: head.stem }),
            crumbsLd([["Past questions", `${BASE}/`], [`WAEC ${s.name}`, sDir], [String(year), `${sDir}${year}/`], [head.stem]]),
          ],
          root,
          hasMath: true,
        }), { budget: true });
      });

      // The year's paper: every question, answers on their own pages.
      const dir = `${sDir}${year}/`;
      const root = rootFrom(dir);
      write(`${dir}index.html`, R.page({
        title: `WAEC ${year} ${s.name} past questions | Paragon`,
        description: `All ${inYear.length} WAEC ${year} ${s.name} objective questions in Paragon, each with its answer.`,
        canonical: `${ORIGIN}/${dir}`,
        root,
        jsonLd: [
          crumbsLd([["Past questions", `${BASE}/`], [`WAEC ${s.name}`, sDir], [String(year)]]),
          listLd(`WAEC ${year} ${s.name} past questions`, inYear, s),
        ],
        body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [String(year)]])}
<h1>WAEC ${year} ${R.escapeHtml(s.name)}</h1>
<p>${inYear.length} questions. Open one to see it in full, with its answer.</p>
<div class="cta"><a class="button" href="/waec/${s.slug}/setup?from=${year}&amp;to=${year}">Sit this paper in Paragon</a></div>
<ol class="paper">${inYear
          .map((q) => `<li><a href="${root}${qDir(s, q)}">${preview(q)}</a></li>`)
          .join("\n")}</ol>`,
      }));
    }

    // One page per topic: its past questions across the years.
    const topicLinks = [];
    for (const t of data.topics.filter((t) => t.subjectId === subjectId).sort((a, b) => a.order - b.order)) {
      const inTopic = list
        .filter((q) => q.topicId === t.id || (Array.isArray(q.alsoTopicIds) && q.alsoTopicIds.includes(t.id)))
        .sort((a, b) => b.year - a.year);
      if (inTopic.length === 0) continue;
      const slug = topicSlug.get(t.id);
      const dir = `${sDir}topic/${slug}/`;
      const root = rootFrom(dir);
      topicLinks.push(`<li><a href="topic/${slug}/">${R.escapeHtml(t.name)}</a> <span class="count">${inTopic.length}</span></li>`);
      write(`${dir}index.html`, R.page({
        title: `${t.name}: WAEC ${s.name} past questions | Paragon`,
        description: `${inTopic.length} WAEC ${s.name} past questions on ${t.name}, with answers.`,
        canonical: `${ORIGIN}/${dir}`,
        root,
        jsonLd: [
          crumbsLd([["Past questions", `${BASE}/`], [`WAEC ${s.name}`, sDir], [t.name]]),
          listLd(`${t.name}: WAEC ${s.name} past questions`, inTopic, s),
        ],
        body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [t.name]])}
<h1>${R.escapeHtml(t.name)}</h1>
<p>${inTopic.length} WAEC ${R.escapeHtml(s.name)} past questions on this topic.</p>
<div class="cta"><a class="button" href="${appTopic(s, t)}">Learn and practise ${R.escapeHtml(t.name)} in Paragon</a></div>
<ol class="paper">${inTopic
          .map((q) => `<li><a class="qlink" href="${root}${qDir(s, q)}">WAEC ${q.year}</a><div>${preview(q)}</div></li>`)
          .join("\n")}</ol>`,
      }));
    }

    // The subject: years and topics.
    const root = rootFrom(sDir);
    write(`${sDir}index.html`, R.page({
      title: `WAEC ${s.name} past questions and answers | Paragon`,
      description: `${list.length} WAEC ${s.name} objective past questions from ${years[years.length - 1]} to ${years[0]}, by year and by topic, with answers.`,
      canonical: `${ORIGIN}/${sDir}`,
      root,
      jsonLd: crumbsLd([["Past questions", `${BASE}/`], [`WAEC ${s.name}`]]),
      body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`]])}
<h1>WAEC ${R.escapeHtml(s.name)} past questions</h1>
<p>${list.length} objective questions, each with its answer.</p>
<div class="cta"><a class="button" href="/waec/${s.slug}/setup">Sit a timed paper in Paragon</a></div>
<h2>By year</h2>
<ul class="grid">${years.map((y) => `<li><a href="${y}/">${y}</a> <span class="count">${list.filter((q) => q.year === y).length}</span></li>`).join("")}</ul>
<h2>By topic</h2>
<ul class="list">${topicLinks.join("")}</ul>`,
    }));
    subjectCards.push({ s, count: list.length, from: years[years.length - 1], to: years[0] });
  }

  // The index, at /past-questions/ and again at /past-questions/waec/,
  // which every subject's URL implies and used to be a 404 (audit E8).
  // The second copy points its canonical at the first.
  subjectCards.sort((a, b) => a.s.name.localeCompare(b.s.name));
  const index = (rel) => R.page({
    title: "WAEC past questions and answers | Paragon",
    description: "Free WAEC objective past questions with answers, by subject, year and topic.",
    canonical: `${ORIGIN}/${BASE}/`,
    root: "/",
    jsonLd: crumbsLd([["Past questions"]]),
    body: `
<h1>WAEC past questions</h1>
<p>Real WAEC objective questions with their answers, by year and by topic. Paragon also has practice questions and lessons for every topic; those are in the app.</p>
<ul class="list">${subjectCards
      .map((c) => `<li><a href="/${BASE}/waec/${c.s.slug}/">WAEC ${R.escapeHtml(c.s.name)}</a> <span class="count">${c.count} questions, ${c.from}–${c.to}</span></li>`)
      .join("")}</ul>
<div class="cta"><a class="button" href="/">Start practising free</a></div>`,
  });
  write(`${BASE}/index.html`, index());
  write(`${BASE}/waec/index.html`, index(), { sitemap: false });

  writeNotFound();

  // The app's search over past questions (audit C13): a file on Hosting,
  // fetched only when a student types a real query, so it costs no
  // Firestore reads. Rows are [subject slug, year, plain stem, page id].
  const searchIndex = {
    subjects: Object.fromEntries(subjectCards.map((c) => [c.s.slug, c.s.name])),
    questions: questions.map((q) => {
      const s = subjects.get(q.subjectId);
      // The fifth entry, the full id, lets the content studio open a
      // search result without a query; the app's search reads only four.
      return [s.slug, q.year, R.truncate(R.plainMath(q.text), 140), q.id.slice(0, 10), q.id];
    }),
  };
  write(`${BASE}/search.json`, JSON.stringify(searchIndex), { sitemap: false });

  return { questions: questions.length, subjects: subjectCards.length };
}

// ─── Privacy, terms and About as plain pages ─────────────────────────

/** The app's own legal and About text, from `tool/export_legal.dart`. Run
 *  on every build, never cached, so the static copies cannot fall behind
 *  the app's. Needs `dart` on the PATH, as the Flutter build does. */
function loadLegal() {
  const project = path.resolve(__dirname, "..", "..");
  const json = execSync("dart run tool/export_legal.dart", {
    cwd: project,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    stdio: ["ignore", "pipe", "inherit"],
  });
  return JSON.parse(json.slice(json.indexOf("{")));
}

function sectionHtml(s) {
  return `<h2>${R.escapeHtml(s.heading)}</h2>
${s.paragraphs.map((p) => `<p>${R.escapeHtml(p)}</p>`).join("\n")}
${s.bullets.length ? `<ul>${s.bullets.map((b) => `<li>${R.escapeHtml(b)}</li>`).join("")}</ul>` : ""}`;
}

/**
 * `/privacy/`, `/terms/` and `/about/` as real HTML (audit E2). The app
 * renders these on a canvas, so a crawler, Google's OAuth consent review
 * and every footer link from the static pages used to get "Loading".
 * Hosting serves these files ahead of the SPA rewrite; moving between
 * screens inside the app still shows the app's own versions.
 */
function writeLegalPages(legal) {
  const contact = `<h2>Contact</h2>
<p>${R.escapeHtml(legal.about.contactText)}</p>
<p><a href="mailto:${R.escapeHtml(legal.contactEmail)}">${R.escapeHtml(legal.contactEmail)}</a></p>`;
  const docPage = (slug, doc, description) =>
    write(`${slug}/index.html`, R.page({
      title: `${doc.title} | Paragon`,
      description,
      canonical: `${ORIGIN}/${slug}/`,
      root: "/",
      body: `
<h1>${R.escapeHtml(doc.title)}</h1>
<p class="kicker">Last updated ${R.escapeHtml(legal.lastUpdated)} · ${R.escapeHtml(legal.publisher)}</p>
<p>${R.escapeHtml(doc.intro)}</p>
${doc.sections.map(sectionHtml).join("\n")}
<div class="cta"><a class="button" href="/">Open the app</a></div>`,
    }));
  docPage("privacy", legal.privacy, "What Paragon collects about you, why, and what you can do about it.");
  docPage("terms", legal.terms, "The terms for using Paragon, free WAEC prep.");
  write("about/index.html", R.page({
    title: "About Paragon | Paragon",
    description: "Paragon is free WAEC prep: lessons, topic tests, practice and past papers. Where the questions come from, and how to reach us.",
    canonical: `${ORIGIN}/about/`,
    root: "/",
    body: `
<h1>About Paragon</h1>
${legal.about.sections.map(sectionHtml).join("\n")}
${contact}
<p><a href="/privacy/">Privacy Policy</a> · <a href="/terms/">Terms</a></p>
<div class="cta"><a class="button" href="/">Open the app</a></div>`,
  }));
}

/** Hosting serves `/404.html`, with a 404 status, for any path that is
 *  neither a file nor one of the app's routes (the SPA rewrite in
 *  firebase.json). It used to answer every such path with the app and a
 *  200, which search engines count as a soft 404 (audit A6, 2026-10-15).
 *  Links are absolute: it is served at whatever path was asked for. */
function writeNotFound() {
  write("404.html", R.page({
    title: "Page not found | Paragon",
    description: "This page does not exist.",
    canonical: `${ORIGIN}/`,
    root: "/",
    noindex: true,
    body: `
<h1>We couldn't find that page</h1>
<p>The link may be old or mistyped. The past questions are all still here, by subject, year and topic.</p>
<div class="cta">
<a class="button" href="/${BASE}/">Browse past questions</a>
<a class="button secondary" href="/">Open the app</a>
</div>`,
  }), { sitemap: false });
}

function copyAssets() {
  const kat = path.dirname(require.resolve("katex/dist/katex.min.css"));
  const dest = path.join(OUT, BASE, "katex");
  fs.mkdirSync(path.join(dest, "fonts"), { recursive: true });
  fs.copyFileSync(path.join(kat, "katex.min.css"), path.join(dest, "katex.min.css"));
  // woff2 only: every browser that runs the app reads it, and the CSS
  // falls through to the next format only when one is missing.
  for (const f of fs.readdirSync(path.join(kat, "fonts"))) {
    if (f.endsWith(".woff2")) fs.copyFileSync(path.join(kat, "fonts", f), path.join(dest, "fonts", f));
  }
  fs.copyFileSync(path.join(__dirname, "site.css"), path.join(OUT, BASE, "site.css"));
}

/**
 * Each page's `lastmod` is the day its HTML last changed, not the build day
 * (audit E6: search engines ignore a lastmod that is always "today"). A
 * hash of every page is kept in `.cache/lastmod.json` between builds; a
 * page not in it (a first build, or a fresh CI cache) gets today.
 */
function lastmods(pages, today) {
  const file = path.join(CACHE, "lastmod.json");
  let previous = {};
  try {
    previous = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (_) {
    // first build: every page is new
  }
  const next = {};
  for (const { url, hash } of pages) {
    const before = previous[url];
    next[url] = before && before.hash === hash ? before : { hash, date: today };
  }
  fs.mkdirSync(CACHE, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(next));
  return next;
}

function writeSitemaps() {
  const today = new Date().toISOString().slice(0, 10);
  const dates = lastmods(written, today);
  // The app itself has no meaningful lastmod: leave it out.
  const urls = [{ url: `${ORIGIN}/`, date: null }, ...written.map(({ url }) => ({ url, date: dates[url].date }))];
  const chunks = [];
  for (let i = 0; i < urls.length; i += 45000) chunks.push(urls.slice(i, i + 45000));
  const urlset = (list) =>
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${list
      .map(({ url, date }) => `<url><loc>${R.escapeHtml(url)}</loc>${date ? `<lastmod>${date}</lastmod>` : ""}</url>`)
      .join("\n")}\n</urlset>\n`;
  if (chunks.length === 1) {
    fs.writeFileSync(path.join(OUT, "sitemap.xml"), urlset(chunks[0]));
  } else {
    chunks.forEach((c, i) => fs.writeFileSync(path.join(OUT, `sitemap-${i + 1}.xml`), urlset(c)));
    fs.writeFileSync(
      path.join(OUT, "sitemap.xml"),
      `<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${chunks
        .map((_, i) => `<sitemap><loc>${ORIGIN}/sitemap-${i + 1}.xml</loc></sitemap>`)
        .join("\n")}\n</sitemapindex>\n`,
    );
  }
  // The app's own screens are one canvas each and say nothing to a
  // crawler; the studio and account pages are private. Everything else,
  // the static pages above all, is open.
  fs.writeFileSync(
    path.join(OUT, "robots.txt"),
    `User-agent: *\nDisallow: /admin\nDisallow: /account\nAllow: /\n\nSitemap: ${ORIGIN}/sitemap.xml\n`,
  );
  return urls.length;
}

async function main() {
  // KaTeX warns on every Unicode character it has no metrics for (º, ∆…);
  // the output is still right, so keep the log readable.
  const warn = console.warn;
  console.warn = (...a) => {
    if (!String(a[0]).startsWith("No character metrics")) warn(...a);
  };
  if (!fs.existsSync(path.join(OUT, "index.html"))) {
    console.error(`No app build at ${OUT}. Run \`flutter build web --release\` first.`);
    process.exit(1);
  }
  // Part of the post-build step too: see trim_fonts.js.
  const trimmed = trimFonts(OUT);
  if (trimmed.files) {
    console.log(`Dropped ${trimmed.families} unused KaTeX font families (${trimmed.files} files, ${Math.round(trimmed.bytes / 1024)} KB).`);
  }
  // The app shell's canonical and share tags name the default address;
  // point them at the configured one (a custom domain).
  const shell = path.join(OUT, "index.html");
  const html = fs.readFileSync(shell, "utf8");
  if (ORIGIN !== DEFAULT_ORIGIN && html.includes(DEFAULT_ORIGIN)) {
    fs.writeFileSync(shell, html.split(DEFAULT_ORIGIN).join(ORIGIN));
  }
  fs.rmSync(path.join(OUT, BASE), { recursive: true, force: true });
  const legal = loadLegal();
  const data = await loadData();
  copyAssets();
  const { questions, subjects } = build(data);
  writeLegalPages(legal);
  const urls = writeSitemaps();
  console.log(`Wrote ${questions} question pages across ${subjects} subjects; ${urls} URLs in the sitemap.`);
  if (heavyPages.length) {
    console.log(`${heavyPages.length} question pages over ${R.PAGE_WARN / 1024} KB (the build stops at ${R.PAGE_BUDGET / 1024} KB):`);
    for (const [rel, n] of heavyPages.sort((a, b) => b[1] - a[1])) console.log(`  ${Math.round(n / 1024)} KB  ${rel}`);
  }
  process.exit(0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = { publishable };
