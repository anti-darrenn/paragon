#!/usr/bin/env node
/**
 * Static, indexable pages for every WAEC past question, written into the
 * Flutter build so one `firebase deploy --only hosting` ships both.
 *
 *   flutter build web --release
 *   node tools/site/build_static_site.js [--refresh] [--origin=https://…] [--out=build/web]
 *
 * Why: the app draws on a canvas, so search engines see nothing in it. A
 * student searching "WAEC 2018 mathematics question" should land on that
 * question, see it rendered properly, and be one tap from practising the
 * topic in the app (PLAN.md Phase 3). The app stays at `/`; these live at
 * `/past-questions/**`, and Hosting serves a real file before the SPA
 * rewrite, so no firebase.json change is needed.
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
const { initAdmin } = require("../admin/credential");
const R = require("./render");

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v ?? true];
  }),
);
const ORIGIN = String(args.origin || "https://paragon-hq.web.app").replace(/\/$/, "");
const OUT = path.resolve(__dirname, "..", "..", args.out || "build/web");
const CACHE = path.join(__dirname, ".cache");
const BASE = "past-questions";

// ─── Data ────────────────────────────────────────────────────────────

const QUESTION_FIELDS = [
  "text", "options", "correctIndex", "explanation", "year",
  "subjectId", "topicId", "imageId", "explanationImageId",
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
function write(rel, html, { sitemap = true } = {}) {
  const file = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, html);
  if (sitemap && rel.endsWith("index.html")) {
    written.push(`${ORIGIN}/${rel.replace(/index\.html$/, "")}`);
  }
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
  const rel = `${BASE}/img/${id}.${ext}`;
  const file = path.join(OUT, rel);
  if (!fs.existsSync(file)) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, a.mime === "image/svg+xml" ? a.data : Buffer.from(a.data, "base64"));
  }
  const size = a.width && a.height ? ` width="${a.width}" height="${a.height}"` : "";
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
  const appTopic = (s, t) => `/subject/${s.id}/course/topic/${t.id}`;

  const subjectCards = [];
  for (const [subjectId, list] of bySubject) {
    const s = subjects.get(subjectId);
    list.sort((a, b) => a.year - b.year || (a.id < b.id ? -1 : 1));
    const years = [...new Set(list.map((q) => q.year))].sort((a, b) => b - a);
    const sDir = `${BASE}/waec/${s.slug}/`;

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
        const stem = R.truncate(R.plainText(q.text), 60);
        const answer = `${R.LETTERS[q.correctIndex]}. ${R.renderRich(q.options[q.correctIndex])}`;
        const body = `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [String(year), `${root}${sDir}${year}/`]])}
<p class="kicker">WAEC ${year} · ${R.escapeHtml(s.name)} · objective question</p>
<h1 class="stem">${R.renderRich(q.text)}</h1>
${imageTag(data.assets, q.imageId, `Diagram for this question`, root)}
${optionsList(q)}
<details class="answer"><summary>Show answer</summary>
<p><strong>Answer: ${answer}</strong></p>
${q.explanation ? `<div class="explanation">${R.renderRich(q.explanation)}</div>` : ""}
${imageTag(data.assets, q.explanationImageId, "Worked answer", root)}
</details>
<div class="cta">
${t ? `<a class="button" href="${appTopic(s, t)}">Practise ${R.escapeHtml(t.name)} in Paragon</a>` : ""}
<a class="button secondary" href="/waec/${s.id}/setup">Sit a WAEC ${R.escapeHtml(s.name)} paper</a>
</div>
${t && tSlug ? `<p>Topic: <a href="${root}${sDir}topic/${tSlug}/">${R.escapeHtml(t.name)}: every past question</a></p>` : ""}
<nav class="pager">${prev ? `<a href="${root}${qDir(s, prev)}">← Previous</a>` : "<span></span>"}${next ? `<a href="${root}${qDir(s, next)}">Next →</a>` : "<span></span>"}</nav>`;
        write(`${dir}index.html`, R.page({
          // No question number: Paragon does not have the paper's own
          // numbering, and its order is not WAEC's.
          title: `WAEC ${year} ${s.name}: ${stem} | Paragon`,
          description: `WAEC ${year} ${s.name} past question with the answer${q.explanation ? " and a worked explanation" : ""}: ${R.truncate(R.plainText(q.text), 120)}`,
          canonical: url,
          body,
          jsonLd: R.quizJsonLd({ q, subjectName: s.name, url }),
          root,
          hasMath: true,
        }));
      });

      // The year's paper: every question, answers on their own pages.
      const dir = `${sDir}${year}/`;
      const root = rootFrom(dir);
      write(`${dir}index.html`, R.page({
        title: `WAEC ${year} ${s.name} past questions | Paragon`,
        description: `All ${inYear.length} WAEC ${year} ${s.name} objective questions in Paragon, each with its answer.`,
        canonical: `${ORIGIN}/${dir}`,
        root,
        body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [String(year)]])}
<h1>WAEC ${year} ${R.escapeHtml(s.name)}</h1>
<p>${inYear.length} questions. Open one to see it in full, with its answer.</p>
<div class="cta"><a class="button" href="/waec/${s.id}/setup">Sit these as a timed paper in Paragon</a></div>
<ol class="paper">${inYear
          .map((q) => `<li><a href="${root}${qDir(s, q)}">${R.escapeHtml(R.truncate(R.plainText(q.text), 160))}</a></li>`)
          .join("\n")}</ol>`,
      }));
    }

    // One page per topic: its past questions across the years.
    const topicLinks = [];
    for (const t of data.topics.filter((t) => t.subjectId === subjectId).sort((a, b) => a.order - b.order)) {
      const inTopic = list.filter((q) => q.topicId === t.id).sort((a, b) => b.year - a.year);
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
        body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`, `${root}${sDir}`], [t.name]])}
<h1>${R.escapeHtml(t.name)}</h1>
<p>${inTopic.length} WAEC ${R.escapeHtml(s.name)} past questions on this topic.</p>
<div class="cta"><a class="button" href="${appTopic(s, t)}">Learn and practise ${R.escapeHtml(t.name)} in Paragon</a></div>
<ol class="paper">${inTopic
          .map((q) => `<li><a class="qlink" href="${root}${qDir(s, q)}">WAEC ${q.year}</a><div>${R.escapeHtml(R.truncate(R.plainText(q.text), 160))}</div></li>`)
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
      body: `
${breadcrumb([["Past questions", `${root}${BASE}/`], [`WAEC ${s.name}`]])}
<h1>WAEC ${R.escapeHtml(s.name)} past questions</h1>
<p>${list.length} objective questions, each with its answer.</p>
<div class="cta"><a class="button" href="/waec/${s.id}/setup">Sit a timed paper in Paragon</a></div>
<h2>By year</h2>
<ul class="grid">${years.map((y) => `<li><a href="${y}/">${y}</a> <span class="count">${list.filter((q) => q.year === y).length}</span></li>`).join("")}</ul>
<h2>By topic</h2>
<ul class="list">${topicLinks.join("")}</ul>`,
    }));
    subjectCards.push({ s, count: list.length, from: years[years.length - 1], to: years[0] });
  }

  // The index.
  subjectCards.sort((a, b) => a.s.name.localeCompare(b.s.name));
  write(`${BASE}/index.html`, R.page({
    title: "WAEC past questions and answers | Paragon",
    description: "Free WAEC objective past questions with answers, by subject, year and topic.",
    canonical: `${ORIGIN}/${BASE}/`,
    root: "../",
    body: `
<h1>WAEC past questions</h1>
<p>Real WAEC objective questions with their answers, by year and by topic. Paragon also has practice questions and lessons for every topic; those are in the app.</p>
<ul class="list">${subjectCards
      .map((c) => `<li><a href="waec/${c.s.slug}/">WAEC ${R.escapeHtml(c.s.name)}</a> <span class="count">${c.count} questions, ${c.from}–${c.to}</span></li>`)
      .join("")}</ul>
<div class="cta"><a class="button" href="/">Start practising free</a></div>`,
  }));

  return { questions: questions.length, subjects: subjectCards.length };
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

function writeSitemaps() {
  const urls = [`${ORIGIN}/`, ...written];
  const chunks = [];
  for (let i = 0; i < urls.length; i += 45000) chunks.push(urls.slice(i, i + 45000));
  const today = new Date().toISOString().slice(0, 10);
  const urlset = (list) =>
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${list
      .map((u) => `<url><loc>${R.escapeHtml(u)}</loc><lastmod>${today}</lastmod></url>`)
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
  fs.rmSync(path.join(OUT, BASE), { recursive: true, force: true });
  const data = await loadData();
  copyAssets();
  const { questions, subjects } = build(data);
  const urls = writeSitemaps();
  console.log(`Wrote ${questions} question pages across ${subjects} subjects; ${urls} URLs in the sitemap.`);
  process.exit(0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = { publishable };
