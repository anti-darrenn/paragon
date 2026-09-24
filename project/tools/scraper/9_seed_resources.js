// Seeder for Learn-mode resources — the ordered video / article / exercise
// list that hangs off each topic.
//
// Reads authored files from `content/<subject-slug>/<topic-slug>/` and writes
// them to `topics/{topicId}/resources/{resourceId}`. Dry run by default.
//
//   node 9_seed_resources.js                                  # plan everything
//   node 9_seed_resources.js --subject=mathematics            # one subject
//   node 9_seed_resources.js --topic=quadratic-equations      # one topic
//   node 9_seed_resources.js --subject=mathematics --commit
//
// ── Why the ids are slugs, not auto-ids ──────────────────────────────────
//
// CLAUDE.md requires Firestore auto-IDs for `questions`, and the reason is
// specific to them: drillQuestionsProvider rotates its session window with a
// random cursor over FieldPath.documentId, which sequential ids would cluster
// and break. Nothing cursors over resources — they are read whole and sorted
// by `order` — so a stable slug is strictly better here. It makes this seeder
// idempotent: re-running it updates a resource in place instead of writing a
// second copy of it, which matters because article text WILL be edited after
// it is first seeded.
//
// ── Authoring format ─────────────────────────────────────────────────────
//
// One file per resource, named `NN-slug.md`, where NN sets the order:
//
//   content/mathematics/number-bases/10-what-is-a-base.md
//   content/mathematics/number-bases/20-converting-bases.md
//   content/mathematics/number-bases/30-practice.md
//
// Leave gaps (10, 20, 30) so a resource can be inserted later without
// renaming its neighbours. Each file starts with a `---` frontmatter block:
//
//   ---
//   type: article
//   title: What is a base?
//   ---
//   Prose with maths in the corpus dialect: \(inline\) and \[display\].
//
// For a video, `youtubeId` is optional and usually absent — a video with no
// id is seeded deliberately, and renders as a disabled "Coming soon" row.
// Leaving it out is the normal case, not an omission.
//
//   ---
//   type: video
//   title: Introduction to number bases
//   youtubeId:            # nothing recorded yet
//   durationSeconds: 480
//   ---
//
// For an exercise, `questionCount` says how many to serve from the topic's
// existing bank. No questions are authored here.
//
//   ---
//   type: exercise
//   title: Practise converting bases
//   questionCount: 5
//   ---
//
// ── LaTeX dialect ────────────────────────────────────────────────────────
//
// Inline maths is \(...\). Display maths is \[...\] or $$...$$ alone on a
// line. A lone `$` is a dollar sign, NOT a delimiter — every `$` in this
// corpus is currency, and treating it as maths parsed the text between two
// prices as an expression. `\textbf{}` / `\textit{}` for emphasis; `**bold**`
// does nothing. See docs/LATEX_RENDERING.md.

const fs = require('fs');
const path = require('path');
const Q = require('./seed_quota');
const admin = Q.admin;

const CONTENT = path.join(__dirname, 'content');
const BATCH = 400;                          // Firestore hard limit is 500
const VALID_TYPES = ['video', 'article', 'exercise'];

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const arg = (name) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : null;
};
const ONLY_SUBJECT = arg('subject');
const ONLY_TOPIC = arg('topic');

admin.initializeApp({ credential: Q.loadCredential() });
const db = admin.firestore();

// ─── Frontmatter ─────────────────────────────────────────────────────────

// A deliberately small parser: `key: value` lines between two `---` fences.
// Not YAML, and not pretending to be — no nesting, no lists, no anchors. The
// alternative is a dependency for six scalar fields, and a format authors can
// get subtly wrong in ways that only show up in production.
function parseFrontmatter(raw, label) {
  const text = raw.replace(/^﻿/, '').replace(/\r\n/g, '\n');
  if (!text.startsWith('---\n')) {
    throw new Error(`${label}: must start with a --- frontmatter block`);
  }
  const end = text.indexOf('\n---', 3);
  if (end === -1) throw new Error(`${label}: frontmatter is never closed`);

  const meta = {};
  for (const line of text.slice(4, end).split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const colon = trimmed.indexOf(':');
    if (colon === -1) throw new Error(`${label}: bad frontmatter line "${trimmed}"`);
    const key = trimmed.slice(0, colon).trim();
    // Strip a trailing `# comment`, then surrounding quotes.
    let value = trimmed.slice(colon + 1).replace(/\s+#.*$/, '').trim();
    if (/^".*"$/.test(value) || /^'.*'$/.test(value)) value = value.slice(1, -1);
    meta[key] = value;
  }

  const body = text.slice(text.indexOf('\n', end + 1) + 1).trim();
  return { meta, body };
}

function slugify(s) {
  return String(s).toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// ─── Reading the authored tree ───────────────────────────────────────────

function readTree() {
  if (!fs.existsSync(CONTENT)) {
    throw new Error(
      `no content directory at ${CONTENT}\n` +
      'Create content/<subject-slug>/<topic-slug>/NN-name.md — see the header.'
    );
  }

  const out = [];
  const subjects = fs.readdirSync(CONTENT, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .filter((n) => !ONLY_SUBJECT || n === ONLY_SUBJECT)
    .sort();

  for (const subjectSlug of subjects) {
    const subjectDir = path.join(CONTENT, subjectSlug);
    const topics = fs.readdirSync(subjectDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .filter((n) => !ONLY_TOPIC || n === ONLY_TOPIC)
      .sort();

    for (const topicSlug of topics) {
      const topicDir = path.join(subjectDir, topicSlug);
      const files = fs.readdirSync(topicDir)
        .filter((f) => f.endsWith('.md'))
        .sort();

      const resources = [];
      for (const file of files) {
        const label = `${subjectSlug}/${topicSlug}/${file}`;
        const orderMatch = file.match(/^(\d+)[-_]/);
        if (!orderMatch) {
          throw new Error(`${label}: filename must start with a number, e.g. 10-intro.md`);
        }

        const { meta, body } = parseFrontmatter(
          fs.readFileSync(path.join(topicDir, file), 'utf8'), label,
        );

        const type = (meta.type || '').toLowerCase();
        if (!VALID_TYPES.includes(type)) {
          throw new Error(`${label}: type must be one of ${VALID_TYPES.join(', ')} (got "${meta.type}")`);
        }
        if (!meta.title) throw new Error(`${label}: title is required`);

        // An article with no body is a placeholder the app will render
        // disabled. That is legitimate for a video and never for an
        // article — an article IS its body, so an empty one is a mistake.
        if (type === 'article' && !body) {
          throw new Error(`${label}: an article needs a body below the frontmatter`);
        }
        if (type !== 'article' && body) {
          throw new Error(`${label}: only an article may have a body (this is a ${type})`);
        }

        const id = slugify(file.replace(/^\d+[-_]/, '').replace(/\.md$/, ''));
        if (!id) throw new Error(`${label}: filename yields an empty id`);
        if (resources.some((r) => r.id === id)) {
          throw new Error(`${label}: duplicate resource id "${id}" in this topic`);
        }

        resources.push({
          id,
          type,
          order: Number(orderMatch[1]),
          title: meta.title,
          // Deliberately not deduped on title: a video and an article
          // covering the same sub-concept legitimately share one.
          youtubeId: meta.youtubeId || null,
          durationSeconds: meta.durationSeconds ? Number(meta.durationSeconds) : null,
          description: meta.description || null,
          transcript: meta.transcript || null,
          body: type === 'article' ? body : '',
          questionCount: meta.questionCount ? Number(meta.questionCount) : 0,
          origin: meta.origin || 'authored',
          label,
        });
      }

      if (resources.length) out.push({ subjectSlug, topicSlug, resources });
    }
  }
  return out;
}

// ─── Resolving slugs to Firestore ids ────────────────────────────────────

// Subject and topic names are what exist in Firestore; the authored tree is
// keyed by slug. Resolve once per subject rather than per topic: one query
// for the subject, one for its topics, and every topic in that subject is
// then answered from memory.
async function resolveSubject(subjectSlug) {
  const subjects = await db.collection('subjects').get();
  const subject = subjects.docs.find((d) => slugify(d.data().name) === subjectSlug);
  if (!subject) {
    throw new Error(
      `no Firestore subject matches "${subjectSlug}" ` +
      `(have: ${subjects.docs.map((d) => slugify(d.data().name)).join(', ')})`
    );
  }

  const topics = await db.collection('topics')
    .where('subjectId', '==', subject.id).get();

  const bySlug = new Map();
  for (const t of topics.docs) {
    const slug = slugify(t.data().name);
    // A subject with two topics of the same name would make the mapping
    // ambiguous; say so rather than picking one.
    if (bySlug.has(slug)) bySlug.set(slug, 'AMBIGUOUS');
    else bySlug.set(slug, t.id);
  }

  return { subjectId: subject.id, subjectName: subject.data().name, bySlug };
}

// ─── Writing ─────────────────────────────────────────────────────────────

async function seedTopic(plan) {
  const { topicId, subjectId, resources } = plan;
  let written = 0;

  for (let i = 0; i < resources.length; i += BATCH) {
    const batch = db.batch();
    for (const r of resources.slice(i, i + BATCH)) {
      const ref = db.collection('topics').doc(topicId)
        .collection('resources').doc(r.id);
      // set() without merge: the authored file is the whole truth for a
      // resource, so a field deleted from the file must disappear from the
      // document rather than linger from a previous run.
      //
      // That includes `status`: seeded content goes live immediately, as it
      // always has, and a resource id that collides with an article written
      // in the in-app editor is overwritten and published. Editor ids are
      // slugs of the title, so keep file names distinct from those.
      batch.set(ref, {
        status: 'published',
        type: r.type,
        order: r.order,
        title: r.title,
        subjectId,
        topicId,
        origin: r.origin,
        youtubeId: r.youtubeId,
        durationSeconds: r.durationSeconds,
        description: r.description,
        transcript: r.transcript,
        body: r.body,
        questionCount: r.questionCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    written += Math.min(BATCH, resources.length - i);
  }

  Q.spend(written);
  return written;
}

// ─── Main ────────────────────────────────────────────────────────────────

(async () => {
  console.log(COMMIT
    ? '=== COMMIT MODE - writing to Firestore ==='
    : '=== DRY RUN - no writes (pass --commit) ===');

  const tree = readTree();
  if (!tree.length) {
    console.log('nothing to seed (no matching content directories)');
    return;
  }

  // Resolve each subject once, not once per topic.
  const resolved = new Map();
  const plans = [];
  for (const entry of tree) {
    if (!resolved.has(entry.subjectSlug)) {
      resolved.set(entry.subjectSlug, await resolveSubject(entry.subjectSlug));
    }
    const { subjectId, subjectName, bySlug } = resolved.get(entry.subjectSlug);
    const topicId = bySlug.get(entry.topicSlug);

    if (!topicId) {
      console.error(`  SKIP  ${entry.subjectSlug}/${entry.topicSlug}\n` +
                    '        no Firestore topic with a matching name');
      continue;
    }
    if (topicId === 'AMBIGUOUS') {
      console.error(`  SKIP  ${entry.subjectSlug}/${entry.topicSlug}\n` +
                    '        more than one topic in this subject has that name');
      continue;
    }

    plans.push({ ...entry, subjectId, subjectName, topicId });
  }

  let total = 0;
  for (const p of plans) {
    total += p.resources.length;
    const counts = VALID_TYPES
      .map((t) => `${p.resources.filter((r) => r.type === t).length} ${t}`)
      .join(', ');
    const placeholders = p.resources.filter(
      (r) => r.type === 'video' && !r.youtubeId,
    ).length;
    console.log(
      `SEED  ${p.subjectName} / ${p.topicSlug}  (${p.topicId})\n` +
      `        ${p.resources.length} resources: ${counts}` +
      (placeholders ? ` | ${placeholders} video(s) with no youtubeId yet` : '')
    );
  }

  console.log(`\nplanned: ${total} resources across ${plans.length} topics`);

  if (!COMMIT) {
    console.log('\nDry run only. Re-run with --commit to write.');
    return;
  }

  // Resources are a rounding error against the 20k/day write cap, but they
  // share the budget with the question seeders, which are not — so spend
  // from the same pot rather than writing behind their back.
  const budget = Q.remaining();
  if (total > budget) {
    console.log(`\nSTOP: ${total} writes needed, ${budget} left in today's budget.`);
    console.log(Q.summary());
    return;
  }

  let written = 0;
  for (const p of plans) {
    written += await seedTopic(p);
    process.stdout.write(`\r    writing... ${written}/${total}`);
  }
  process.stdout.write('\r');

  console.log(`\nwrote ${written} resources. ${Q.summary()}`);
})().catch((e) => {
  console.error(`\n${Q.explain(e)}`);
  process.exit(1);
});
