# Repo facts for PLAN.md (Phase 0)

PLAN.md was written from the live site without seeing the code, so its file, collection
and class names were guesses. This file records what the code actually does, with
evidence, so later phases use real names. For the stack, schema and conventions, read
`../../CLAUDE.md`, the authoritative and current description. That covers Flutter 3.47,
Riverpod 3, go_router 18, Firebase v4 on the Spark plan, Node admin and scraper tools,
and no Cloud Functions.

Audited 2026-10-14 on `feat/launch-safety` (PR #29).

## The findings, checked against the code

| # | Finding | What the code does |
|---|---|---|
| F1 | `test2` and `test_article` live | Student queries already filter `status == 'published'` (`learn_repository.dart:44`), so the two items really were published. They are in Mathematics topic `sGeqO2FDw79otnkz3tz6`, which `content_lint.js` confirms. Nothing checked titles before publishing. |
| F2 | 300–420 "questions" per topic | `topics.questionCount` counted every question: 300 generated (`origin: 'ai_generated'`, `source: 'drill'`) plus scraped past questions (`source: 'waec'`, with a `year`). Mathematics holds 1,702 past and 12,900 practice questions. WAEC Prep's 485 is the 2015–2024 slice of the past questions. |
| F3 | 14,602 vs 14,616 | The welcome ticker reads `subjects.questionCount`, which counts only `hasAnswer: true` and is recounted nightly. The course page summed `topics.questionCount`, which was written at seed time with no `hasAnswer` filter and never recounted. |
| F4 | Guest wording contradicts itself | The copy lived in `guest_limits.dart` and the drill refusal in `drillAccessFor`. The topic page still offered drill to guests, and the WAEC Maths-only lock was applied only on the subject list. |
| F5 | Reload shows welcome | `initialLocation: '/welcome'`, plus a redirect that lets guests stay on welcome. |
| F6 | No deep links | Hash URL strategy. `context.push` does not update the address bar (go_router default). A signed-out redirect drops the target, and routes use Firestore ids. |
| F7 | Not indexable | There is no robots.txt, sitemap or static HTML; `index.html` has OG tags and a plain-HTML splash. |
| F8 | Heavy first load | `docs/audit/PERF.md`: about 3.5 MB gzipped, engine-bound. The logo is 149 KB, and about 20 KaTeX TTFs are in `FontManifest`. |
| F9 | Accessibility | `FullLatexView` has no `Semantics`. `speakText` (read aloud) can label maths. The exam options are bare `GestureDetector`s, and `onLow` text fails AA. |
| F10 | Exam defaults | 40 questions in 60 minutes, set in `waec_exam_setup_screen.dart:31-44`. There is no preset, keyboard support, flagging or autosave. |
| F11 | Positioning | A copy decision for the owner (Wave J). |

## The P0.0.3 questions

1. **Per-topic counts.** Stored fields. `topics.questionCount`, `pastQuestionCount` and
   `practiceQuestionCount` are written by `tools/admin/jobs.js --job=counts` from
   `count()` aggregates. Before 2026-10-14 the only field was `questionCount`, written by
   the seeders.
2. **The ticker.** `subjects.questionCount` and its split, written by the same job as the
   sum of the subject's topics. `tools/admin/check_counts.js` asserts that they agree.
3. **Where the extra Mathematics questions come from.** `tools/scraper/gen/` generates
   them; every one carries `origin: 'ai_generated'`. Past questions carry
   `source: 'waec'` and a `year`. There is no `paper` or `questionNumber` field.
4. **Guest state.** Firebase anonymous auth, persisted by the browser. Attempts, `progress`
   and `learn` are stored under the anonymous uid. Notes, cards and lesson ticks are kept
   on the device. Linking an account keeps all of it (`guest_upgrade.dart`).
5. **Gating.** It was scattered across the router, `GuestLimits`, `drillAccessFor` and
   inline `isGuestProvider` checks. It is now one table, `canUse` in
   `lib/core/auth/feature_access.dart`. The router still decides signed-out access.
6. **Other placeholders.** `node tools/admin/content_lint.js` checks every published Learn
   item, read-only. On 2026-10-14 it found only `test2` and `test_article`.

## PLAN.md against reality

| PLAN item | Status | Why |
|---|---|---|
| P1.1.1–1.1.4 status field, published-only queries, rules, claims scripts | **Exists** | `topics/{id}/resources` with `draft → in_review → published`, the rules, `verify_rules.js`, `set_role.js`. Questions are Admin-SDK-only writes. |
| P1.2.1 new provenance fields | **Adapted** | `source`, `year` and `origin` already carry the facts, so `Question.provenanceLabel` reads them instead of adding fields. |
| P1.2.3 hide `unverified` | **Decided** | Generated questions are shown as "Paragon practice" (owner, 2026-10-14). |
| P1.3 `stats` collection plus Cloud Function | **Adapted** | Spark has no Functions. The counts live on the topic and subject documents, kept by the nightly `jobs.js`. |
| P1.4.2 `mergeGuestProgress` function | **Declined** | Spark. Linking already keeps a guest's progress; merging into an existing account stays unsupported. |
| P1.4.4 guest table | **Adopted**, two rows changed | Exam history and offline saving already worked for guests, so they stay open. |
| P2.1.1 slugs in URLs | **Adapted** (Wave B) | App routes keep ids; the static pages use slugs. |
| P3.1 app moved to `/app` | **Declined** (owner) | The app stays at `/`, and `/past-questions/**` is added beside it. |
| P4.4 / P4.5 deferred imports, wasm | **Declined** | `PERF.md` measured about 50 KB and about 5%. |
| P5.2.4 autosave to Firestore | **Adapted** (Wave E) | It saves to the device instead; a write per answer is unaffordable on Spark. |
| P6.1 emulator rules tests | **Adapted** (Wave F) | They run in CI only (this machine has no Java), with `verify_rules.js` kept. |
| P6.5 Sentry | **Declined** | `ErrorReporter` already reports through Analytics, with no new vendor. |
| P7.2.2 EWMA mastery | **Adapted** (Wave G) | It reuses `MasteryLevel`. |
| P7.2.6 streak | **Declined** | Streaks were removed by decision; the weekly goal replaces them. |
| P7.7 teachers and classes | **Deferred** | It needs safeguarding work for minors and a server. |
| P8.2 l10n/ARB | **Deferred** | Large churn, with no second language planned. |

---

# Plan v2 (2026-10-16)

`PLAN_v2.md` at the root was also written from the live site, not the code. This section
is its Phase 0. Audited 2026-10-16 on `main` (`36831b1`). The live `main.dart.js`
(last modified 2026-10-16 18:48 UTC) is 4,762,249 bytes, the same size as a local build
of that commit.

## 0.1 Routes and the static generator

- **Router.** `lib/core/router/app_router.dart`:
  - **Shell branches:** Home (`/`, `/plan`); Courses (`/courses`,
    `/subject/:s/course[/topic/:t]`, `/learn/topic/:t/:r`, `/search`); WAEC (`/waec`,
    `/waec/:s/setup`, `/waec/review/:examId`); Review (`/review`, `/mistakes`, `/saved`,
    `/cards/:s`, `/settings/offline`); Me (`/me`, `/settings/*`).
  - **Focus routes:** drill, topic and unit tests, the challenge, `/waec/:s/exam` and
    `/theory`, `/join`, `/rooms/*`, `/try`, `/c/:id`, `/support`, sign-in, legal and
    account, and `/admin/*`.
  - **No route sets a browser title.** The only one is `MaterialApp.router(title: 'Paragon')`
    (`lib/app.dart:35`).
- **Static generator.** `tools/site/build_static_site.js`, Node CommonJS, with
  `render.js` (KaTeX) and `trim_fonts.js`.
  - **When it runs:** after `flutter build web`, by hand, and in `ci.yml` (L83–94) when
    the service-account secret or `.cache/data.json` exists. It writes into `build/web`.
  - **Question URLs** are `/past-questions/waec/{subject}/{year}/{first 10 chars of id}/`
    (L268). Titles are `WAEC {year} {Subject}: {stem…} | Paragon`, de-duplicated at build
    time.
  - **The sitemap** `lastmod` changes only when a page's HTML hash does
    (`.cache/lastmod.json`). Only `404.html` is noindex.
  - **KaTeX** is `output: "htmlAndMathml"` (`render.js:18-23`), so v2 4.9 is already true.
  - **There is no** per-page size budget, "similar questions" block or frequency block on
    question pages.

## 0.2 The question schema

| | Past question | Practice question |
|---|---|---|
| Marker | `source: 'waec'`, no `origin` | `origin: 'ai_generated'`, `source: 'drill'` |
| Year | `year` | `year: null` |
| Written by | `archive/3_seed.js:144-153`, `5_match_answers.js:320-328` | `gen/lib.js:159-168` via `6_seed_generated.js` / `7_create_subject.js` |
| Extra fields | `sourceId` (myschool id), `hasAnswer`, `imageId`, `explanationImageId` | `unitId`, `createdAt`, `hasAnswer: true` |

- **Shared fields:** `subjectId`, `topicId` (**one** topic id, never a list), `text`,
  `options` (no letter prefix), `correctIndex`, `explanation` (plain text, one field).
- **The trail of changes, set by scripts or the reviewer:**
  - `previousCorrectIndex`, `reviewedAt`, `reviewedBy` (the `/admin/flag` resolver,
    the only client write: `firestore.rules:25-40`);
  - `previousTopicId`, `reclassifiedAt` (`8_apply_reclass.js`);
  - `reviewNote`, `duplicateOf`, `needsDiagram`, `contentCorrectedAt`
    (`apply_corrections.js`);
  - `hasInsight` (`jobs.js --job=insights`).
- **No such field exists:** `paper`, `sitting`, `questionNumber`, `verified`,
  `reportCount`, `spokenText`, `difficulty`. There is no `questions/{id}/history`. Changes
  are traced by the fields above and the local `tools/admin/.backups/`.
- **Admin imports** (`tools/admin/import_questions.js:131-142`) default `origin` to
  `'authored'`.
- **"Report a problem"** writes to `flags`: `{questionId, userId, reason, createdAt}` with
  `reason` one of `wrong_answer | unclear_question | rendering | other`
  (`flag_repository.dart:42-47`). Lesson reports carry `resourceId` and `topicId` instead.
  Reviewers add `status`, `resolvedAt` and `resolvedBy`.

## 0.3 Where the past questions came from

- **Every past question was scraped from myschool.ng**, never schoolngr.com: that name
  appears nowhere in the repo or its history.
- **The evidence:**
  - `tools/scraper/myschool.js:7-11` (`BASE = 'https://myschool.ng/classroom'`, plus its
    image folders);
  - `4_scrape_answers.js:100,156` (the listing and detail URLs);
  - `archive/1_scrape.js:14` and `archive/README.md`;
  - `docs/ARCHITECTURE.md:64`;
  - `docs/WAEC_OUTREACH.md:3` ("collected from a public archive (myschool.ng)… that is
    not permission");
  - commit `1af8eb5`.
- **The raw source is in the repo,** so v2 2.2.1 needs no scraping:
  `tools/scraper/data/answers_<subject>.json` holds `questionHtml`, `options[].isCorrect`
  and `explanationHtml` per record.

| Subject | Records | With an explanation | Years |
|---|---|---|---|
| Mathematics | 1766 | 1623 | 1990–2025 |
| Physics | 1819 | 1079 | 1990–2025 |
| Further Mathematics | 801 | 752 | 2006–2025 |

- **The 2018 "0.612" question** is myschool `sourceId` 49425. The source itself:
  - says "Expression 0.612";
  - marks A (153/250) correct, with an explanation treating 0.612 as terminating.

  So both the typo and the possibly wrong answer (if the paper had recurring dots,
  68/111 is right) came in from the source. It is a reviewer's call at
  `/admin/flag/:questionId`, not a script's.
- **If schoolngr has the same text,** both sites probably copied a common origin. Paragon
  copied from myschool.ng.
- **Sittings and numbers.** The source records no sitting (May/June or Nov/Dec) and no
  question number (`docs/audit/CONTENT_REVIEW_2026-10-15.md:322`). Oversized papers
  (Maths 2007 holds 67) are the visible symptom.

## 0.4 How practice questions are generated

- **Where:** `tools/scraper/gen/`. `run.js` writes `data/generated_<subject>_<topic>.json`
  with 300 unique stems per topic (`lib.js` `buildTopic`), from unseeded `Math.random()`.
  `verify.js` re-solves each one independently.
- **How many templates:** Mathematics Indices has 9 generators (`math_num_a.js:16-136`).
  Concept topics (`concept.js:85-93`) get 3 statement templates plus an optional Q&A bank.
- **Distractors** are hand-picked per template (for example `a*b`, `|a-b|` and `a+b±1`
  for xᵃ·xᵇ), plus `numericDistractors` (±15%, ×2, ÷2, ±1, ±3). `buildOptions` removes
  duplicates and shuffles.
- **No difficulty field and no misconception labels** exist.
- **Variety already exists** (v2 5.8): `lib/core/content/session_mix.dart` caps each
  template (the stem with its numbers replaced by `#`) per session and keeps repeats
  apart.

## 0.5 How mastery is computed

- **The formula.** `lib/core/progress/mastery.dart:109-115` counts the cumulative
  `answered` and `correct` per topic in `progress/{uid}`:

| Level | Answered | Accuracy |
|---|---|---|
| mastered | 40 or more | 90% or more |
| proficient | 20 or more | 70% or more |
| familiar | 10 or more | 50% or more |
| attempted | any other count | any |

- **What counts:**
  - Only `source: 'drill'` answers.
  - **Past and practice questions are weighted the same.**
  - A right answer after a hint counts as answered, not correct (`lib/core/learn/hints.dart`).
- **Access depends on it.** Reaching proficient also unlocks drill on its own
  (`drillAccessFor`, grandfathered), so any weighting change touches access, not just the
  display.

## 0.6 Hosting

- **`firebase.json`:**
  - one Hosting site, no `site` or `target`, and no `redirects`;
  - one regex SPA rewrite of the app's route segments to `/index.html`;
  - security headers and the CSP on every path except `/__/`;
  - `no-cache` on app routes, HTML and the bootstrap;
  - `/past-questions/img/**` immutable and sandboxed.
- **`.firebaserc`** has only `default: paragon-hq`.
- **The origin** is one constant, `kSiteOrigin` (`lib/core/config/site_config.dart`),
  read by `build_static_site.js` (L47–52, and it rewrites the built `index.html`) and
  `browser_other.dart`.
- **Still hard-coded:**
  - `web/index.html` (canonical, `og:url`, `og:image`: rewritten at build);
  - `tools/site/render.js:309` (the default `og:image`);
  - `tools/admin/notify_drafts.js` (two links in emails);
  - `render.test.js`.

  `paragon-hq.firebaseapp.com` in the CSP and `firebase_options.dart` is the Auth domain
  and stays.
- **Contact email:** two Gmail addresses in `lib/core/legal/legal_documents.dart:43,48`.
  There is no separate support-email constant.

## Plan v2 against reality

| v2 item | Status | Why |
|---|---|---|
| Rule 4 (`gcloud firestore export`) | **Wrong for Spark** | Managed export needs billing (Blaze). The repo's pattern is a JSON backup per write in `tools/admin/.backups/`, with `--revert`. |
| Paths `scripts/`, `reports/`, `data/*.yaml`, `lib/a11y/` | **Adapted** | Scripts go in `tools/admin/` (rules in `question_rules.js`), Dart in `lib/core/a11y/`, reports in a gitignored folder. |
| 1.3 one origin value | **Exists** | `kSiteOrigin`. Four places still hard-code it (0.6). |
| 1.4 redirect the old domain | **Needs a second Hosting site** | Only one site exists. `LAUNCH_CHECKLIST.md` L86–96 already lists the domain steps. |
| 1.5 support email | **Different place** | `legal_documents.dart` `contactEmail` / `contactEmailCc`, used by About, Support and the legal pages. |
| 2.1.1–2.1.2 provenance | **Partly done** | The source is myschool.ng (0.3). `WAEC_OUTREACH.md` already drafts the permission request to WAEC. |
| 2.1.3 `importedFrom` | **Derivable, not stored** | `source: 'waec'` with no `origin` *is* "imported from myschool", and `sourceId` is set. Backfilling ~4,400 documents spends a day's Spark writes on a fact the data already says. Store only `answerVerified`/`textVerified` when a human verifies. |
| 2.2.1 compare with the source | **Possible offline** | The raw data is committed (0.3). |
| 2.3 the linter | **Mostly exists** | `question_rules.js` / `content_audit.js` already check duplicate and too few options, raw LaTeX, lost negative powers, missing diagrams, typos, duplicates and near duplicates (Jaccard 0.8) in a paper, the same question in two years, and paper sizes outside 35–50. **New work:** a recurring-decimal suspect, a conservative numeric answer check, `Expression <number>` → "Express", exactly-one-correct, and a "significant figures" control for the diagram rule. Add them as rules there, not as a new script. |
| 2.3 `flags: []` on each question | **Conflicts** | `flags` is already the reports collection, and it is a write per question. The audit already publishes to `_meta/contentAudit`, which the studio shows. |
| 2.3.8 sittings | **Not knowable from the data** | The source has no sitting (0.3). It needs the original papers. |
| 2.4 review queue | **Partial** | `/admin/flag/:questionId` changes the answer, retires or dismisses. Stems and options are Admin-SDK-only by rule; edits go through `corrections/` files and `apply_corrections.js`. A studio editor for stems is a rules change: an owner decision. |
| 3 topic tags | **Partly done** | 2,246 reassignments applied, 290 low-confidence left (`CLAUDE.md`, "Topic classification"). Keyword-based suggestions are new. `topicId` is single; multiple topics would mean a schema change. |
| 4 accessibility | **Mostly built** | See below. |
| 4.2 `texToSpeech` | **Exists** | `speakText` / `speakMath` in `lib/core/a11y/speech_text.dart`, with about 73 tests (`test/speech_text_test.dart`, `test/math_semantics_test.dart`). It covers fractions, powers, roots, bases, operators, Greek, degrees, log and trig. **Gaps:** `\dot`/`\overline` say "dot"/"bar", not "recurring"; matrices come out as a flat list of numbers. |
| 4.4 / 4.5 stem and options | **Built** | `mathSemantics()` labels every maths line in `FullLatexView` and `MathText`. Drill uses `FullLatexView` for the stem, hint and explanation. Options are `AnswerOption`, and the verdict is a live region (4.8). Plain-text lines are ordinary `Text`. **The reviewer's missing stem and frequency line are both plain `Text`,** and the live bundle has the semantics code, so this needs a repro in a browser with a screen reader before any rebuild. |
| 4.6 image alt text | **Gap** | `QuestionImage` reads only "Figure". |
| 5.1–5.7 difficulty, weighting, misconceptions | **Absent** | 0.4 and 0.5. |
| 5.8 template variety | **Done** | `mixSession`. |
| 6.1 noindex policy | **Absent** | Every question page is indexed. |
| 6.2 question numbers | **Not possible** | No field, and none in the source. |
| 6.3 value blocks, 6.4 `?from&to`, 6.6 size budget | **Absent** | Setup always defaults to the last 10 years. |
| 6.7 landing block | **Exists** | `#splash` in `web/index.html`. Only the title is lost (7.1). |
| 6.8 `lastmod` | **Adapted** | Questions have no `updatedAt`; the HTML hash is the honest date. |
| 7.1 per-route titles | **Absent** | 0.1. |
| 7.2 empty left column | **Check in a browser** | Two columns from 820 px, with Continue and Your subjects on the left (`dashboard_screen.dart:102-127`). Shortest path is only on the course page. |
| 7.3 stats flash | **Real** | `dashboard_screen.dart:509` and `plan_widgets.dart:45` fall back to 0 while loading. |
| 7.4 topic CTAs | **Mostly fine** | "Practise now" shows only in the no-lessons notice. |
| 7.5 join link | **Absent** | No share button and no `?code=`. Code validation already exists (`normaliseRoomCode`, `room.dart:108-115`). |
| 7.7 Notify me in WAEC | **Absent** | `NotifyMeButton` is used only on coming-soon courses. |
| 8.1 deferred loading | **Done** | 31 `deferred as` imports in the router. The reviewer's "no part.js" reading is out of date. v1 measured further splitting at about 50 KB gzipped (`docs/audit/PERF.md`); the framework and engine dominate, so "30% smaller" is not reachable this way. |
| 8.2 Roboto | **Unexplained** | Worth measuring. |
| 8.3 Space Grotesk weights | **Open** | Five are bundled (Light to Bold). |
| 8.5 wasm | **Declined in v1** | About 5% (PERF.md). |
| 8.8 service worker | **Stub** | Flutter's worker unregisters itself; there is no offline shell. |
| 9.3 CI | **Mostly exists** | Analyze, test, the bundle budget, node, rules, content and preview jobs. Missing: Lighthouse and the static page budget. |

## Decisions for the owner

Two of v2's questions are answered by the data: there are **no sittings and no question
numbers** to show. These are still open:

1. **Domain and contact address** (Phase 1).
2. **Permission for the myschool.ng text and explanations:** (a) rewrite explanations
   and verify text, (b) ask for permission, or (c) rebuild from original papers (2.1.2).
3. **A studio editor for stems and options** (a rules change and a new write path), or
   keep the `corrections/` file path (2.4).
4. **More than one topic per question** (3.4).
5. **Who signs off template difficulty** (5.2). Weighting mastery also changes who
   reaches drill, through grandfathering.
6. **The indexing policy:** noindex question pages without an original explanation
   (6.1).
7. **A service worker** (8.8).
