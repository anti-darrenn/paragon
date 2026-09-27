// Attaches diagrams to scraped past questions that depend on one.
//
//   node 10_fetch_question_images.js --subject=physics            # dry run
//   node 10_fetch_question_images.js --all --commit
//   node 10_fetch_question_images.js --subject=mathematics --limit=20
//
// ~750 scraped questions refer to "the diagram above", and until now the app
// could not show one: 4_scrape_answers.js saw the image in myschool.ng's
// payload but kept only a `hasImage` boolean. This re-reads those questions'
// pages, downloads the images, shrinks them to WebP and stores each as a
// `lessonAssets` document (base64 in Firestore — the Spark plan has no
// Storage bucket, and lesson figures already work this way). The question
// gets `imageId`, and `explanationImageId` when the worked answer has one.
//
// A question whose own image cannot be had (the file is gone at source) is
// retired with `hasAnswer: false, needsDiagram: true` rather than left in
// circulation unanswerable. That is reversible: flip `hasAnswer` back once a
// diagram is supplied.
//
// Dry run by default: reads Firestore, fetches and compresses the images into
// data/question_images/ (gitignored), and reports — but writes nothing to
// Firestore. --commit writes, within the shared daily budget
// (data/_seed_budget.json), and is safe to re-run: done questions are skipped.

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { admin, loadCredential, remaining, spend, summary, explain } = require('./seed_quota');
const { BASE, IMAGE_BASE, ANSWER_IMAGE_BASE, DELAY_MS, sleep, fetchHtml, fetchBytes, parseNuxt, questionRecords } =
  require('./myschool');

// url slug -> subjects/{id}.name, as in 5_match_answers.js
const SUBJECT_NAMES = {
  mathematics: 'Mathematics',
  physics: 'Physics',
  'further-mathematics': 'Further Mathematics',
};

const args = process.argv.slice(2);
const flag = (name) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
};
const COMMIT = args.includes('--commit');
const LIMIT = Number(flag('limit')) || Infinity;
const SUBJECTS = args.includes('--all')
  ? Object.keys(SUBJECT_NAMES)
  : [flag('subject')].filter(Boolean);

const DATA_DIR = path.join(__dirname, 'data');
const CACHE_DIR = path.join(DATA_DIR, 'question_images');
const MAX_WIDTH = 1000;
// a Firestore document holds 1 MiB; leave room for the other fields
const MAX_BASE64 = 700000;

const progressFile = (slug) => path.join(DATA_DIR, `question_images_${slug}.json`);
const loadJson = (file, fallback) => {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
};

// the first <img src> in a piece of question html — a dozen questions embed
// their diagram inline instead of in the `image` field
function inlineImage(html) {
  const m = typeof html === 'string' && html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return m ? m[1] : null;
}

// question and answer images live in different folders at source
const toUrl = (ref, base) => (/^https?:\/\//.test(ref) ? ref : base + ref.replace(/^\/+/, ''));

// what the question's own page says its images are
async function imagesFor(slug, record) {
  const url = `${BASE}/${slug}/${record.sourceId}?exam_type=waec&exam_year=${record.year}&type=obj`;
  const arr = parseNuxt(await fetchHtml(url));
  if (!arr) throw new Error(`no __NUXT_DATA__ at ${url}`);
  const hit = questionRecords(arr).find(({ raw, resolve }) => resolve(raw.id) === record.sourceId);
  if (!hit) throw new Error(`question ${record.sourceId} not in its own page`);
  const { raw, resolve } = hit;

  const options = resolve(raw.options) || [];
  const question =
    resolve(raw.image) ||
    inlineImage(resolve(raw.question)) ||
    options.map((o) => inlineImage(o && o.description)).find(Boolean) ||
    null;
  const answer = resolve(raw.answer_image) || inlineImage(resolve(raw.explanation)) || null;
  return {
    question: question && toUrl(question, IMAGE_BASE),
    answer: answer && toUrl(answer, ANSWER_IMAGE_BASE),
  };
}

const cacheFile = (name) => path.join(CACHE_DIR, `${name}.webp`);

// downloads [url] as WebP no wider than MAX_WIDTH into the cache, so a dry
// run's work is reused by the commit that follows
async function download(url, cacheName) {
  const file = cacheFile(cacheName);
  if (!fs.existsSync(file)) {
    const bytes = await fetchBytes(url);
    await sharp(bytes)
      .flatten({ background: '#ffffff' }) // diagrams are drawn on white
      .resize({ width: MAX_WIDTH, withoutEnlargement: true })
      .webp({ quality: 85 })
      .toFile(file);
  }
  return loadCached(cacheName);
}

// a downloaded image, ready to store
async function loadCached(cacheName) {
  const file = cacheFile(cacheName);
  const meta = await sharp(file).metadata();
  const data = fs.readFileSync(file).toString('base64');
  if (data.length > MAX_BASE64) throw new Error(`${cacheName} too large (${data.length} base64 chars)`);
  return { data, width: meta.width, height: meta.height };
}

async function runSubject(db, slug) {
  const subjectName = SUBJECT_NAMES[slug];
  if (!subjectName) throw new Error(`unknown subject ${slug}`);

  const answers = loadJson(path.join(DATA_DIR, `answers_${slug}.json`), []);
  const bySource = new Map(answers.map((a) => [a.sourceId, a]));
  const progress = loadJson(progressFile(slug), {});
  const save = () => fs.writeFileSync(progressFile(slug), JSON.stringify(progress, null, 1));

  const subjSnap = await db.collection('subjects').where('name', '==', subjectName).get();
  if (subjSnap.empty) throw new Error(`no subjects doc named ${subjectName}`);
  const subjectId = subjSnap.docs[0].id;

  // every scraped question of the subject, one read each (~1.8k at most)
  const qSnap = await db
    .collection('questions')
    .where('subjectId', '==', subjectId)
    .where('source', '==', 'waec')
    .get();
  const targets = qSnap.docs.filter((d) => {
    const x = d.data();
    const rec = bySource.get(x.sourceId);
    return rec && rec.hasImage && !x.imageId && !x.explanationImageId && !x.needsDiagram;
  });

  console.log(`\n=== ${subjectName} ===`);
  console.log(`scraped questions in firestore: ${qSnap.size}`);
  console.log(`flagged with an image, not yet done: ${targets.length}`);

  const tally = { nothing: 0, attached: 0, explanationOnly: 0, retired: 0, skipped: 0, writes: 0 };
  let n = 0;
  for (const doc of targets) {
    if (n++ >= LIMIT) break;
    const rec = bySource.get(doc.data().sourceId);
    const key = String(rec.sourceId);
    if (progress[key] && progress[key].committed) continue;

    // 1. find and download (network only; cached in progress + data/question_images)
    let p = progress[key];
    if (!p || p.status === 'error') {
      try {
        const urls = await imagesFor(slug, rec);
        p = { status: 'found', ...urls };
        if (urls.question) {
          try {
            const q = await download(urls.question, `${key}-q`);
            p.questionSize = q.data.length;
          } catch (e) {
            // the page names an image the site cannot serve: nothing to show
            p.status = 'image_missing';
            p.error = e.message;
          }
        }
        if (urls.answer) {
          try {
            await download(urls.answer, `${key}-a`);
          } catch (e) {
            p.answer = null; // an explanation without its picture still reads
            p.answerError = e.message;
          }
        }
      } catch (e) {
        // page fetch failed: transient until proven otherwise, retry next run
        p = { status: 'error', error: e.message };
        console.warn(`  ${key}: ${e.message}`);
      }
      progress[key] = p;
      save();
      await sleep(DELAY_MS);
    }
    process.stdout.write(`\r  ${n}/${Math.min(targets.length, LIMIT)} ${key} ${p.status}      `);

    if (p.status === 'error') {
      tally.skipped++;
      continue;
    }

    // 2. write (commit only)
    // flagged, but the page names no image at all: nothing to write
    if (p.status !== 'image_missing' && !p.question && !p.answer) {
      tally.nothing++;
      if (COMMIT) {
        p.committed = true;
        save();
      }
      continue;
    }
    const retire = p.status === 'image_missing';
    const needed = retire ? 1 : (p.question ? 1 : 0) + (p.answer ? 1 : 0) + 1;
    if (!COMMIT) {
      if (retire) tally.retired++;
      else if (p.question) tally.attached++;
      else tally.explanationOnly++;
      continue;
    }
    if (remaining() < needed) {
      console.log(`\n  daily write budget spent — stopping. ${summary()}`);
      break;
    }

    const batch = db.batch();
    const update = {};
    if (retire) {
      // the page names a diagram the site can no longer serve
      update.hasAnswer = false;
      update.needsDiagram = true;
    } else {
      const asset = async (suffix) => {
        const img = await loadCached(`${key}-${suffix}`);
        const ref = db.collection('lessonAssets').doc();
        batch.set(ref, {
          mime: 'image/webp',
          data: img.data,
          width: img.width,
          height: img.height,
          createdBy: 'pipeline',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return ref.id;
      };
      if (p.question) update.imageId = await asset('q');
      if (p.answer) update.explanationImageId = await asset('a');
    }
    batch.update(doc.ref, update);
    await batch.commit();
    spend(needed);
    tally.writes += needed;
    if (update.needsDiagram === true) tally.retired++;
    else if (update.imageId) tally.attached++;
    else if (update.explanationImageId) tally.explanationOnly++;
    p.committed = true;
    save();
  }
  process.stdout.write('\n');

  console.log(`  ${COMMIT ? '' : '(dry run) '}question image attached: ${tally.attached}`);
  console.log(`  explanation image only:        ${tally.explanationOnly}`);
  console.log(`  retired, diagram missing:      ${tally.retired}`);
  console.log(`  flagged, but no image found:   ${tally.nothing}`);
  console.log(`  skipped, page fetch failed:    ${tally.skipped}  (re-run to retry)`);
  if (COMMIT) console.log(`  writes: ${tally.writes}. ${summary()}`);
}

async function main() {
  if (!SUBJECTS.length) {
    console.log('usage: node 10_fetch_question_images.js --subject=<slug>|--all [--commit] [--limit=N]');
    console.log(`subjects: ${Object.keys(SUBJECT_NAMES).join(', ')}`);
    process.exit(1);
  }
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  admin.initializeApp({ credential: loadCredential() });
  const db = admin.firestore();
  console.log(COMMIT ? `COMMIT — ${summary()}` : 'dry run — nothing is written to Firestore');
  for (const slug of SUBJECTS) await runSubject(db, slug);
}

main().catch((e) => {
  console.error(`\n${explain(e)}`);
  process.exit(1);
});
