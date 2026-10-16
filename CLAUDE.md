# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**New here?** `project/docs/ARCHITECTURE.md` is the full map of the system: every
service, route, collection, job and script. This file is the rulebook.

**Launching?** Read `project/docs/LAUNCH_CHECKLIST.md` first: the PR merge order,
the deploy and data steps, the decisions still open, and the browser click-through
nobody has done yet. `PLAN.md` at the root records what was built for each review
finding, and why the rest was declined. `PLAN_v2.md` (the 2026-10-16 review) holds the
open work; read `project/docs/REPO_FACTS.md` § "Plan v2" before acting on any of it.

## Repo layout

Git root is `C:\Users\user\Desktop\paragon`. The Flutter app is one level down in `project/` — **all flutter/firebase/node commands run from `project/`**, not from the git root. `paragon_plans/` holds the PRD, tech-stack strategy, execution plan and Firestore schema docs (`.docx` + `.md`).

`project/.cursorrules` is the long-form project brief (architecture rules, Firestore schema, scraper pipeline, session roadmap, deferred work). It is the source of truth for product rules, but its `cd C:\Users\user\Desktop\paragon` command examples predate the move into `project/` — append `\project`.

## Commands

All from `C:\Users\user\Desktop\paragon\project` (PowerShell):

```powershell
flutter run -d chrome              # run the app (web is the primary target)
flutter analyze                    # lint (flutter_lints via analysis_options.yaml)
flutter test                       # all tests
flutter test test/latex_render_test.dart                          # single file
flutter test test/latex_render_test.dart --plain-name "MathText"  # single test
flutter build web --release; node tools/site/build_static_site.js; firebase deploy --only hosting   # deploy (project paragon-hq)
```

**KaTeX fonts are trimmed after the build.** `tools/site/trim_fonts.js` (run by the
post-build step) drops Caligraphic, Fraktur, SansSerif, Script and Typewriter from the
built `FontManifest.json`, because Flutter web downloads every manifest font at startup:
9 requests and 140 KB gzipped. The editor and `content_lint.js` warn on `\mathcal`,
`\mathfrak`, `\mathscr`, `\mathsf`, `\textsf`, `\texttt` and `\mathtt`, which would
fall back to the main font. If content needs one of these, drop it from the trim list.

**The WAEC exam** (`waec_exam_screen.dart`) has:
- keyboard control: A–E answer, ←/→ move, F flags, Enter submits from the summary;
- flag-for-review, and a pre-submit summary of answered, unanswered and flagged;
- a 48 dp question strip that speaks each number's state.

It is **kept on the device** while it runs (`SavedExam`, shared_preferences, questions
included). Setup offers "Resume", restoring answers, flags, place and the clock. It is
never kept in Firestore, which would mean a write per tap on Spark. Submit or exit clears
it, and it goes stale after a day.

Setup defaults to the **"Full paper" preset** from `lib/core/exam/exam_formats.dart`. Those
formats were checked on 2026-10-16 against the WAEC syllabuses (question counts) and WAEC's
2026 timetables (times), and are `verified: true`. A subject not listed falls back to
`kDefaultExamFormat`, which is unverified, so the screen says "approximately".

**Plan, goal and challenges** (Wave G):
- **Pure models.** `lib/core/plan/` holds:
  - `weekly_goal.dart`: weeks run Monday to Sunday in Lagos, whatever the device zone,
    and `weeklyAttemptsCountProvider` counts the same week. No run of weeks is kept, so
    streaks stay gone.
  - `study_plan.dart`: topic weights are each topic's share of the real past questions
    (`pastQuestionCount`), uniform where there are none, and the UI says which. It also
    gives the shortest path (weight × what is left) and a **grade estimate from
    practice**.
- **The grade estimate.** It is a range until 50 drill answers in the subject, hidden
  below 20, and always shown beside `kGradeEstimateNote`. It reads `progress` for display
  only, which is allowed because it is private and nothing competitive uses it.
- **Screens.** `/plan`, Home's "This week" card and the course page's plan panel cost no
  reads of their own: the outlines and progress are already loaded.
- **Challenge links.** `/c/:id` (`ChallengeLinkScreen`) records a friend's answers as
  `source: 'challenge_link'`, which **never** reaches `progress`
  (`challenge_link_test.dart` asserts it).
- **The taster.** `/try` gives five instant-feedback questions from a subject's
  most-examined topic, straight from the welcome screen, and records nothing.
- **`QuestionRunner`** (`lib/core/widgets/question_runner.dart`) is the shared
  instant-feedback runner for both.

**Live quiz rooms** (`lib/core/rooms/`, `features/rooms/`):
- **Routes.** `/join`, `/rooms/new`, `/rooms/:code/host` (the projector) and
  `/rooms/:code` (a phone).
- **Scoring** is the pure model `room.dart`: one point per right answer, no speed bonus.
  The host's client totals the score at the podium.
- **Reads.** A player listens to the room and nothing else, so a 30-player game is about
  2,600 reads. The figures are in `docs/audit/QUOTA.md`.
- **Never** `attempts` or `progress`.
- **The answer rule** reads the room with `get()`. An answer is accepted only when the
  room's `state` is `question` at that index, once, from a joined player. The emulator
  suite walks through a whole game.

**Content structure** (Wave I):
- **Examiner insights.** Shown as "What examiners saw" under a worked answer in drill
  and exam review, and as "Where students lose marks" on a topic page. They are always
  in Paragon's own words, with a citation. The studio editor (`/admin/insight/:id`)
  refuses to publish text with 20 or more consecutive words shared with the pasted
  report (`longestSharedRun`). Flags are refreshed nightly, so a newly published insight
  appears the next day.
- **Bylines.** Lessons show "By Name · credential" only when `contributors/{uid}`
  exists.
- **Theory.** Self-marked against the scheme; nothing is stored.
- **Exam results** sit beside the practice grade estimate (`PracticeComparison`).
- **Importing questions.** `tools/admin/import_questions.js` validates (4–5 distinct
  options, one right answer, maths that parses, a year on past questions, no duplicate
  stems) before it writes. It is the import path, because question stems are
  Admin-SDK-only.

**Trust and support** (Wave J):
- **Support.** `/support` is readable signed out, like `/about`. Its donate card
  (`features/support/donate_card.dart`, Khan-style: one-time or monthly, amounts and
  "Other") opens Paystack payment pages listed in `kDonateLinks`
  (`lib/core/config/support_config.dart`). A tier with a null link is hidden, and the
  card is hidden while every link is null. Paying happens on Paystack, so nothing in
  the app or the CSP changes; the privacy policy says so.
- **About.** It thanks the names in `kAcknowledgements` and explains the provenance
  labels.
- **The privacy policy** has a "legal basis" section. It is still a draft for a
  lawyer's review.
- **The terms** are at `kLegalVersion` `2026-10-15`, so every account re-accepts once.
- **Taglines.** `docs/COPY.md` holds five options for the owner to choose from.

**Static past-question pages.** `tools/site/build_static_site.js` (run `npm install` there
once) writes `/past-questions/**`, `sitemap.xml`, `robots.txt` and `404.html` into `build/web`
after the Flutter build, so one hosting deploy ships both. Hosting serves a real file before the SPA
rewrite.

**The SPA rewrite lists the app's top-level route segments** (`firebase.json`), so a missing
static page, a stray file or an unknown path gets `404.html` with a real 404 instead of the
app with a 200. Hosting's `regex` is RE2, with no lookahead, so the list is spelled out.
**A new top-level route must be added there**: `hosting_rewrite_test.dart` walks the router
and fails until it is. Inside the app, an unknown path under a known segment shows
`NotFoundScreen` (`GoRouter.errorBuilder`). The local Hosting emulator cannot check regex
rewrites on Windows, because superstatic's `glob-slasher` turns `/courses` into `\courses`
first. These pages are the only part of Paragon a search engine can read. Only past
questions are published (`source == 'waec'`, `hasAnswer`, a real `correctIndex`), never
generated practice. Titles carry no question number, because Paragon doesn't have the
paper's own numbering. The first run reads about 4,500 documents; the result is cached in
`tools/site/.cache/`, and only `--refresh` reads again. Maths is rendered server-side by
KaTeX (`render.js` mirrors `FullLatexView`'s dialect; change both together). Wherever text
must be plain (titles, descriptions, list previews, JSON-LD), `plainMath()` turns the maths
into readable text (`\frac{2x-1}{x+3}` → `(2x-1)/(x+3)`), never TeX source. Question titles are
de-duplicated at build time, and the build fails if two are still the same. Sitemap `lastmod`
is the day a page's HTML last changed (hashes in `.cache/lastmod.json`).
Each question page also says how often its topic is examined ("about 1 in 34 WAEC
Mathematics questions": `frequencyPhrase` in `render.js`, which mirrors the app's
`study_plan.dart`, so change both together) and links three similar questions, nearest
in year. A year page's "Sit this paper" opens `/waec/<subject>/setup?from=<year>&to=<year>`.
The build lists question pages over 60 KB and fails on one over 128 KB: the median is
11 KB, and a few dense worked answers reach 97 KB.

**`/privacy/`, `/terms/` and `/about/` are static pages too**, so that crawlers and Google's
OAuth review can read them. They are generated from the app's own text:
`build_static_site.js` runs `dart run tool/export_legal.dart` on every build, never from a
cache. That exporter reads `legal_documents.dart` and `about_content.dart`, which must stay
pure Dart (no Flutter imports). In-app navigation still shows the Flutter screens.

**Hosting headers** (`firebase.json`):
- `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `nosniff`, a referrer policy and a
  permissions policy on every path except `/__/`. Firebase Auth frames `/__/auth/iframe`.
- **Hosting matches a header `regex` against the whole path.** Until 2026-10-16 the
  pattern matched only `/` and one-letter paths, so no other path had these headers;
  the test used a partial match and passed. `hosting_rewrite_test.dart` now matches the
  whole path. Check with `curl -sI …/welcome` after a hosting deploy.
- A full **Content-Security-Policy** is enforced, after a clean report-only run on the
  preview (2026-10-16) through sign-in, video and an exam. It allows the hosts the app
  uses: gstatic (CanvasKit, Firebase JS), googleapis, Analytics, Auth's firebaseapp.com
  iframe, and youtube-nocookie. **A new third-party host needs adding there first**, or
  the browser blocks it.
  - `www.youtube.com` is in `script-src` because `youtube_player_iframe` draws the
    player in a `srcdoc` iframe. That iframe inherits this policy and loads
    `iframe_api`; without it every video is a grey box.
  - The same page's inline script differs per player, which is why `'unsafe-inline'`
    cannot be swapped for hashes.
  - The reCAPTCHA hosts are there for App Check.
- App routes are `no-cache`, using the same regex as the rewrite.
- `/past-questions/img/**` is immutable, because asset ids never change. It also gets
  `default-src 'none'; sandbox`, since an SVG opened directly is a page on this origin.
  `build_static_site.js` refuses unsafe SVGs (`tools/admin/svg_safety.js`, mirrored by
  `svgProblem` in the studio's `image_upload.dart`; change both together).

**App Check** (`lib/core/config/app_check_config.dart`) is the guard against a
script spending the day's Spark quota as a guest. It is off while
`kRecaptchaEnterpriseSiteKey` is empty, then monitor-only until enforced in the
console (LAUNCH_CHECKLIST.md, "Security"). It is web only.

**Security record:** `docs/audit/SECURITY_2026-10-16.md`. Run
`node tools/admin/security_audit.js` (read-only) before a deploy.

**After adding or removing any plugin, run `flutter clean` before the next release
build.** The release build reuses a cached `web_plugin_registrant.dart` under
`.dart_tool/flutter_build/<hash>/`, and it was not regenerated when
`youtube_player_iframe` was added: production shipped without the YouTube web plugin
(every video lesson was a grey box) *and* without `SharedPreferencesPlugin`, missing
since 2026-09-17. Debug and profile builds were unaffected, so local testing passed.
Check: `grep -c WebYoutubePlayer .dart_tool/flutter_build/*/web_plugin_registrant.dart`
should be non-zero for every copy.

Content pipeline (`project/tools/scraper`, Node CommonJS, no npm scripts — invoke files directly):

```powershell
node 4_scrape_answers.js <subject>        # answers + explanations from myschool.ng's __NUXT_DATA__
node 5_match_answers.js <subject> --apply # join them onto existing questions (dry run without --apply)
node 6_seed_generated.js --all            # generated questions into existing topics (see below)
node 7_create_subject.js --subject=<id>   # a whole new subject from generated content
node 8_apply_reclass.js                   # apply a reviewed topic reclassification
node 9_seed_resources.js --subject=<id>   # Learn articles/videos/exercises (dry run without --commit)
node 10_fetch_question_images.js --all    # diagrams for scraped past questions (dry run without --commit)
node reclassify.js                        # propose topic reassignments (dispatch-only in CI)
node check_linkage.js                     # verify topicId linkage after seeding or reclassifying
node ../admin/content_lint.js             # published Learn items with placeholder titles or broken maths
node ../admin/check_counts.js             # subject counts == sum of topic counts
node ../admin/content_audit.js --cache    # past questions vs the content rules (no reads; --list=<rule>, --csv, --publish)
node ../admin/explanation_report.js       # which explanations are the source's, rewritten or missing (no reads; --csv)
node ../admin/fix_questions.js            # mechanical fixes (dry run; --commit, --revert=.backups/…)
node ../admin/apply_corrections.js --file=corrections/<file>.js   # reviewed hand corrections (dry run; --commit)
```

**Past-question content rules** live in `tools/admin/question_rules.js`, which is pure and
tested.
- **The rules:** the audit's checks (broken or stray LaTeX, duplicate options, lost negative
  powers, missing diagrams, duplicates in a paper, and the rest), and the mechanical fixes:
  `10-3` to `10^{-3}`, flat units, `30o` to `30°`, naira, OCR's `lf`/`ln`, typos.
- **Level S, the suspects** (Plan v2): a decimal that may have been recurring
  (`recurring-decimal-suspect`), and a rounding or standard-form stem worked out that
  disagrees with the marked option (`answer-mismatch-suspect`). They only flag. The
  evaluator skips any stem with arithmetic in it, and it agrees with all 14 stems it
  reads today, so a hit is worth a reviewer's look. `--publish` lists them first in the
  studio's Content quality panel, linked to `/admin/flag/:id`.
- **Fixes touch only text outside maths.** They turn notation into maths that says the
  same thing.
- **Anything needing judgement** goes into a `corrections/` file, reviewed, then applied by
  `apply_corrections.js`. That covers retiring a duplicate (`hasAnswer: false` with a
  `reviewNote` and `duplicateOf`), rewording a stem, or a retag (which records
  `previousTopicId`).
- **Safety.** Every write keeps a backup in `tools/admin/.backups/` (gitignored), and
  `--revert` restores it.
- **Imports.** `import_questions.js` refuses the level-A rules.
- **The studio.** Its Content quality panel reads the summary that
  `content_audit.js --publish` writes to `_meta/contentAudit`.
- **The record.** `docs/audit/CONTENT_REVIEW_2026-10-15.md` is what was decided and done.

Generated practice comes from a few templates per topic. Indices has 300 questions from
nine. `mixSession` (`lib/core/content/session_mix.dart`) caps each template in a drill or
topic-test session and keeps repeats apart.

The original chain — `1_scrape`, `2_classify`, `fix_misclassified`, `3_seed` — is retired
in `tools/scraper/archive/` (see its README): the scrape selectors match nothing since
myschool.ng became a Nuxt app, the classifier was mostly wrong, and `3_seed.js` duplicates
any subject that already exists. Requires `tools/scraper/.env` (`GROQ_API_KEY`, for
`reclassify.js`) and `tools/scraper/data/serviceAccountKey.json` (gitignored, never commit).

### Generated content, seeding, and the Spark quota

A second content source now sits alongside the scraper. `tools/scraper/gen/` generates
WAEC-style questions procedurally — each answer computed in code, not authored by hand —
into `data/generated_<subject>_<topic>.json`, 300 per topic, 216 topics, ~64,800 questions
across Mathematics, Physics, Further Maths, Chemistry and Government. Every document is
marked `origin: 'ai_generated'`, which is how you filter or audit synthetic content, and
how a rollback would find it.

**The generators use unseeded `Math.random()`.** Re-running `run.js` produces a *different*
corpus; it does not reproduce the committed one. That is why ~44MB of JSON is committed
rather than regenerated, and why `run.js` carries a warning header. Do not re-run it
casually — it overwrites.

Three seeders, all dry-run unless `--commit`:

```powershell
node 6_seed_generated.js --all              # additive: existing subjects, by topicId
node 7_create_subject.js --subject=chemistry # creates subject -> units -> topics -> questions
node 8_apply_reclass.js                      # applies a reviewed reclassification mapping
```

**Never revive the archived `3_seed.js` for a subject that already exists** — it always
creates a fresh subject document and would duplicate it. That is the whole reason
`6_seed_generated.js` exists.

Questions must be written with Firestore **auto-IDs**: `drillQuestionsProvider` rotates its
session window with a random cursor over `FieldPath.documentId`, so sequential IDs would
cluster and break rotation. They also need `hasAnswer: true` or the drill query filters
them out entirely.

**Firestore is on the free Spark plan: 20k writes and 50k reads per day.** Seeding the full
corpus needs four to five days. An attempt to do it in one run exhausted both quotas and
completed nothing. The seeders now share a daily budget via `data/_seed_budget.json` (keyed
to the *Pacific* quota day), stop cleanly when spent, and resume next run;
`.github/workflows/seed-content.yml` drives them daily. Counting uses `count()` aggregation
— billed per 1000 index entries, not per document. Fetching whole topics just to size them
is what drained the read quota the first time. Staying on Spark is deliberate: the hard
ceiling is the cost guarantee until there's revenue.

### Topic classification

The `llama-3.1-8b` labels were wrong far more often than this file used to claim, and the
rate differed sharply by subject — measured on a random sample, then on the full corpus:
**Mathematics 81%, Physics 61%, Further Mathematics 8%**. So the "all subjects" framing in
`a0606fa` was wrong; Further Maths was largely fine. 2,246 high-confidence reassignments
have been applied, each recording `previousTopicId` so it is reversible. 290 low-confidence
rows — diagram-dependent stems, genuinely dual-fit questions — were deliberately left alone
rather than guessed at, and are still suspect.

`reclassify.yml` is **dispatch-only now**. It was scheduled every two hours with `--apply`,
which meant two systems writing `topicId` to the same documents. Do not re-enable the
schedule without first deciding which pass is authoritative.

Reclassification moves questions *out* of topics as well as in. Twelve Mathematics topics
and twenty-two Physics topics were left below the 20 questions a drill session serves — two
at literally zero — until generated content was seeded into them. **If you reclassify again,
re-check topic counts afterwards and seed the thin ones**, or you will empty a topic a
student is using.

**After changing `firestore.rules`, deploy then run `node tools/admin/verify_rules.js`.**
It exercises the whole file against the live project as a real client (anonymous ID
token, Firestore REST, no Admin SDK — that bypasses rules and would pass regardless).
159 checks; the username suite signs up two throwaway `example.com` password
accounts, because reservations refuse guests. The denials are the content: a write that succeeds only proves something
allowed it. The emulator would be the usual answer but needs Java, which this machine
does not have. **CI does**: `.github/workflows/ci.yml` runs `tools/rules-test/rules.test.js`
on the emulator for every pull request (`npm test` there; seeded fixtures, about 30 allow
and deny cases). Add a case there and a check to `verify_rules.js` with every rules
change.

**CI** (`.github/workflows/ci.yml`, every pull request and push to main) runs these jobs:
- `app`: `flutter analyze`, `flutter test`, the release build with the plugin-registrant
  check, and the post-build step;
- `node`: the scripts' own tests;
- `rules`: the emulator tests above;
- `content`: `content_lint.js` and `check_counts.js` against production, read-only;
- `preview`: a 7-day Hosting preview channel commented on the PR. It needs the service
  account to hold Firebase Hosting Admin; until then it fails without blocking.

Live deploys stay manual, by the owner.

`project/firestore.rules` and `project/firestore.indexes.json` are both tracked in the repo, and `firebase.json`'s `firestore` block points at each — `firebase deploy --only firestore:rules` and `firebase deploy --only firestore:indexes` deploy these files directly, as `.cursorrules` describes.

## Architecture

Flutter web app (Flutter 3.47 / Dart 3.12+, Riverpod v3 + go_router v18 + Firebase v4) over a Firestore content tree seeded by Node scrapers.

**google_fonts is held at 8 on purpose.** Version 9 is built on the separate `material_ui`
package, and its `TextTheme` is not `flutter/material`'s, so `AppTheme` stops compiling.
Moving to it means migrating the whole app onto `material_ui`, not bumping a version.

**Two parallel product modes that must never merge:**

- Learning Mode — `/courses` → `/subject/:subjectId/course` → `.../course/topic/:topicId` (CourseCatalog → CourseIndex → TopicOverview), then drill at `/subject/:s/unit/:u/topic/:t`. Immediate per-question feedback, attempts recorded with `source: 'drill'`. The old SubjectList/UnitList/TopicList screens are deleted; `/subjects`, `/subject/:id` and `/subject/:id/unit/:u` redirect to the course pages.
- WAEC Prep Mode — `/waec` → `/waec/:subjectId/exam` (WaecSubjectScreen → WaecExamScreen). Full exam run, results at the end, `source: 'waec'`.

Never add WAEC questions to drill providers without filtering by `source`, and never add drill-style instant feedback to the exam flow. The review at `/waec/review/:examId` comes after submission and locks every answer; its grade is always labelled an estimate from objective questions only (`lib/core/exam/waec_grade.dart` — the bands are not official).

**The drill gate.** `lib/core/learn/topic_test.dart` is the pure model —
scoring, the 80% pass mark (`kTopicTestPassPercent`), and `drillAccessFor`,
which is the *only* place the gate is decided. Drill for a topic opens when
its topic test is passed, or — grandfathered — when drill mastery already
reached proficient before the gate shipped. A **unit test**
(`lib/core/learn/challenge.dart`, owner's decision) also counts as passing
a topic's test when it drew at least 4 of that topic's questions and 80% were
right; it writes `passed` with `passedVia: 'unit_test'` and no `attempts`
increment. The course challenge never unlocks. Both record `source: 'challenge'`
and add to `progress` only for topics open once marked
(`challenge_screen_test.dart` has the control). Learn content is never gated.

**Guests** are decided by one table, `canUse(Feature, isGuest:)` in
`lib/core/auth/feature_access.dart` (PLAN.md P1.4.4, adopted 2026-10-14).
Every guest gate asks it — `drillAccessFor`, `GuestLimits.locks`, the
challenge screen; never add an inline `isGuest` gate. Guests drill (behind
the same topic test, stored under their anonymous uid), take unit tests
and sit untimed WAEC Prep in every subject; timed exams and a future study
plan ask for an account. The words guests see live in `guest_limits.dart`.

**The gate is client-enforced and cannot be otherwise**: rules see one
document write, not the ten answers behind it. That is a bounded,
deliberate acceptance — drill is practice, not a reward. Put anything of
value behind it and it needs a server first. Grandfathering is the one
place `progress/{uid}` touches *access*; it stays honest only because it is
one-way — it can grant access, never withhold it — so a missing or stale
progress document can never cost a student anything.

**Content team and the studio.** Three roles, all custom claims on the
Auth token and never fields on `users/{uid}` (anything a client can write
there, a client can grant itself):
- `writer` and `reviewer`, optionally limited to some subjects by a
  `subjects` claim (no claim = every subject);
- `admin`, set by `set_admin_claim.js` / `create_admin_user.js`, never
  limited.

**Giving someone a role:** they sign up normally, then an admin uses
**Content studio → Team**. The page writes `staffInvites/{email}`
(admin-only), and `tools/admin/apply_roles.js`, a step in the 15-minute
notify-drafts workflow, sets the claims; the person signs out and in.
`set_role.js --email=… --role=… [--subjects=Mathematics,Physics]` does the
same at once from a terminal. **Every grant needs a verified email**
(`grantRefusal` in `apply_roles.js`, used by all four claim scripts). Password
sign-up never proves an address, so whoever registered an invited email first
would otherwise get the role; the invite waits as `unverified` instead.

The rules check roles with `isWriter()` ⊃ `isReviewer()` ⊃ `isAdmin()`,
and subjects with `writes(subjectId)` / `reviews(subjectId)` on every
content write (both old and new `subjectId` on updates). Outside its
subjects an account reads the studio but the editor is read-only.
`staffAccessProvider` (`StaffAccess.roleIn(subjectId)`) reads claims for
the UI only. The contract is `docs/CONTENT_ROLES.md`:
- **Statuses:** `draft → in_review → published`, with `changes_requested`
  sending an item back. Only the exact string `published` is ever
  student-visible.
- **Writers** create and edit only unpublished items, submit them, and
  delete their own drafts.
- **Reviewers** publish, request changes (the reason becomes a comment),
  unpublish, delete (published items too, from the editor or the topic
  planner's row menu), reorder, and handle all problem reports.
- **Revisions.** A published item is never edited in place. "Start a
  revision" makes a draft with `revisionOf`, and approving it copies the
  content into the original, which keeps its id and therefore every
  student's completion tick.
- **History.** Every save writes the previous content to
  `…/resources/{id}/versions`, which is append-only and restorable. Review
  threads live in `…/comments`.
- `LessonWorkflow` makes each transition one batch.

`/admin` (Settings → Content studio) shows, in order:
- the review queue (for reviewers) and the "sent back" list;
- question reports and lesson reports (for reviewers);
- a course map: every topic of a subject, showing its lesson's state, fed
  by one collection-group query per subject.

`/admin/topic/:topicId` is the topic planner: items in order, drag to
reorder (reviewers only, since it moves published items), and "Preview as
student". The editor has:
- the insert toolbar, keyboard shortcuts and a bank-question picker;
- the problems panel (`checkLesson`) and copy/paste of blocks between
  lessons;
- image upload (`lessonAssets`, compressed in the browser; the `file_picker`
  and `image` packages are **deferred-imported**, so students never
  download them);
- history, comments, and an autosave backup kept **on the device only**.
  Autosaving to Firestore would write a history version every few seconds.

A reviewer's publish, unpublish or delete also rebuilds that topic's entry
in `subjectIndex`.

**Problem reports.** Students file `flags` from `ReportProblemButton`
(questions) and `ReportLessonButton` (articles and videos: `resourceId` and
`topicId` instead of `questionId`, with their own `LessonReportReason`).
The question queue groups the 200 most recent reports by question, open
first. `/admin/flag/:questionId` resolves one question three ways, each a
single batch that also closes its open reports:
- mark a different answer, keeping the old one in `previousCorrectIndex`;
  the screen offers to revert;
- retire it (`hasAnswer: false`), which removes it from drill, WAEC, tests
  and exercises;
- dismiss the reports because the answer is right.

Answers already in `attempts` keep their grading. A generated question is
labelled: its fix belongs in `tools/scraper/gen` too. Lesson reports are
closed as fixed or dismissed from the studio home.

**Emails.** `notify_drafts.js` runs every 15 minutes
(`.github/workflows/notify-drafts.yml`) and emails on workflow transitions,
never on saves. The studio sets `pendingNotice` on each transition, and the
job clears it after a successful send, querying it through the
collection-group `pendingNotice` override:
- **Submitted items** go to the reviewers, together with new question and
  lesson reports (tracked by the `_meta/notify.flagsNotifiedThrough`
  cursor; stamping every report would cost ~19k reads a day).
- **Verdicts** (changes requested, published) go to the writer.

Resend's shared sender only reaches the account's own address. While
`NOTIFY_FROM` is unset, writer emails go to `NOTIFY_TO`, labelled with who
they are for. The workflow skips cleanly while `RESEND_API_KEY` is unset.

**The lesson page.** `/learn/topic/:topicId/:resourceId` (`lib/features/lesson/`)
plays one published item beside the topic's sequence, Khan-style, with
"Up next" ending at the topic test. `LessonVideoPlayer` is the only file that
imports `youtube_player_iframe` (web iframe, Android webview, privacy-enhanced
host). Completion rules: a video when `WatchTracker` counts ~90% actually
played (seeking earns nothing), an article when its end is on screen, an
exercise when a set is finished. Exercise rules live in `ExerciseSession`
(first try scored, one retry, then reveal); a signed-in student's first
tries are recorded once per finished set as `source: 'exercise'`. Guests
get in-memory checkmarks and nothing stored.

Things that were measured in a browser, not assumed — keep them true:
- **One tree shape for every layout.** `LessonScreen` collapses the sidebar
  to zero width instead of swapping a Row for a Column; moving the player to
  a new parent moves its iframe in the DOM and the browser restarts the
  video.
- **An article completes on scrolling to its end** (`ScrollUpdateNotification`
  with `pixels > 0` — not `dragDetails`, which a mouse wheel never sets) or,
  for one that fits on screen, 1.5s after layout (the maths fonts load late
  and briefly make every article look short).
- A browser tab that is **hidden** paints nothing and YouTube will not play:
  screenshots of a hidden window show stale frames. Check
  `document.visibilityState` before trusting one.

Android: `flutter build apk --debug` works (the first build installs the NDK
and takes ~45 min); an emulator AVD, `Test-_-`, exists in the SDK. The app
always opens at `/welcome` (`initialLocation`, also the bare web root). The
first redirect that knows the auth state sends a returning guest from
welcome to `/`; after that a guest may visit welcome freely
(`guest_landing_test.dart`).

A claim change reaches a signed-in session only after a token refresh
(up to an hour) or a fresh sign-in.

**Progress and mastery.** `lib/core/progress/mastery.dart` is the pure model —
`MasteryLevel` (notStarted/attempted/familiar/proficient/mastered), the thresholds,
and the roll-up maths. Per-topic progress is a **level**, not a percentage, and only
module/course aggregates become percentages; `course_progress.dart` joins a `Course`
outline to a student's counters. `MasteryCircle`/`MasteryRing`
(`lib/core/widgets/mastery_indicator.dart`) are the only things that draw them.

**Streaks are gone.** `currentStreak`/`lastActiveDate`, `UserRepository.updateStreak`,
the dashboard card, the `streakWriteIsPlausible` rules and `jobs.js --job=streaks` were
all removed — the number was computed from the device clock and nothing of value hung
off it. The rules no longer accept either field (`verify_rules.js` asserts both are
refused), and as of 2026-09-25 no user document carries them. `jobs.js --job=dropstreak`
stays as a one-shot for restoring an old backup. Do not reintroduce streaks as part of
Learn mode.

Counters live in `progress/{uid}` — **not** on `users/{uid}`, and this is load-bearing.
That document's rules allow-list keeps stats fields server-only so a future leaderboard
cannot be client-fed, and nothing here weakens it. The rule that keeps the two
compatible is a product rule the rules file cannot express: **nothing competitive or
rewarding may read `progress`.** XP, achievements and leaderboards must recompute from
`attempts` server-side first. `attempts` remains the source of truth; `progress` is a
cache of a per-topic count query the free tier cannot afford (Firestore has no GROUP BY,
so the honest version is one aggregate per topic — 40 to 64 per course page).

Written once per drill *session*, not per question, so a 20-question drill still costs
the 20 attempt writes it always did. WAEC exams deliberately do not feed it: the modes
must not merge, and one exam would fan across up to 40 topics' worth of writes.

**Analytics.** `analytics_provider.dart` defines the events (including the first-visit funnel: `guest_start`, `signup_start`/`signup_complete{method}`, `topic_open`, `drill_start`, `exam_start{preset}`, `waitlist_join`; the welcome view is the `/welcome` screen view); `analytics_binding.dart`
wires the two app-wide ones (screen views, `is_guest`) and is watched by `app.dart` for
its side effects. Screen names are **route patterns** (`/subject/:subjectId/...`), never
concrete URLs — no document ids in screen names, and no thousand-row reports. `Analytics`
reads the opt-out flag at call time and resolves `FirebaseAnalytics.instance` lazily, so
an instance is safe to hold in a `State` field (Riverpod 3 forbids `ref` in `dispose()`,
which is where `DrillScreen` ends its session). **`legal_documents.dart` must change with
this file** — it describes to users exactly what is collected, and the policy previously
claimed an `is_guest` property that nothing ever set.

**Data flow.** Screens are `ConsumerWidget`s that watch providers in `lib/core/repositories/learning_repository.dart` (`subjectsProvider`, `unitsProvider`, `topicsProvider`, `drillQuestionsProvider(topicId)`, `waecQuestionsProvider(subjectId)` — all `FutureProvider`/`.family` reading Firestore directly). Writes go through `AttemptRepository.record()` and `ProgressRepository.addSession()`. Auth/user streams live in `lib/core/providers/auth_provider.dart` (`authStateProvider`, `currentUserProvider`, `userDataProvider`, `weeklyAttemptsCountProvider`).

**Navigation shell.** Every screen a student browses sits in one
`StatefulShellRoute.indexedStack` (`AppShell`, `lib/core/widgets/nav/`): a top bar at
≥760px and bottom tabs below it (Home, Courses, WAEC, Review, Me). The top bar pins the
logo left and the account corner right ("Continue" / guest "Save progress", an offline
chip, the avatar menu), with a centred island of Home, Courses ▾ (a dropdown of every
subject), WAEC Prep, Review and Search. It is slightly translucent and floats over the
pages: `AppShell` adds `kTopBarHeight` to the pages' top `MediaQuery` padding, which app
bars respect and `ParagonPage` turns into scroll padding so its content scrolls under
the bar. Branch order **is** `NavTab` order. Focus
sessions — drill, topic test, unit test/challenge, WAEC exam, mistakes practice — and
onboarding, sign-in, `/legal/accept`, `/account/*`, `/about` and the studio are outside
the shell, full-window. `AppShell` keeps one tree shape across the breakpoint (the pages are always the
stack's first child, and the top bar's slot is a positioned zero-size box on a phone —
an unpositioned one would size the stack to nothing): re-parenting the branch navigators would
rebuild every page and restart a lesson video. Pages with no app bar of their own use
`ParagonPage`/`CompactPageBar` (`page_layout.dart`), which draws a phone header and
nothing when wide. `context.push` to a route in another branch shows it inside the
current tab; use `go` to switch tabs. `analytics_binding.dart` reads the deepest leaf
(`currentConfiguration.last`) — `matches.last` is the shell itself and logs nothing.

**Back navigation and page building blocks.** Every screen's app bar is
`ParagonAppBar` (`lib/core/widgets/nav/back_navigation.dart`), never a bare `AppBar`:
its back arrow pops when there is history and otherwise goes to the page's parent from
`parentPathFor(uri)`, so a page opened from a link, reload or search is never a dead end
(`back_navigation_test.dart` walks every route). "Done"/"Back" buttons use
`context.popOrGo()`, not `pop()`, which throws when there is nothing to pop. A new
route needs a parent in `parentPathFor`. Tab roots pass `collapseWhenWide: true` and
lead with a `PageIntro(wideOnly: true)`. Lay pages out with `lib/core/widgets/ui/ui.dart`
(`PageBody`, `SectionHeader`, `SurfaceCard`, `ListRow`, `RowGroup`, `EmptyState`…) at
`kPageMaxWidth`; component styling (buttons, fields, dialogs, snackbars, chips) comes
from `AppTheme`, so don't restyle them inline.

**Search** (`lib/core/search/search.dart`, pure; `features/search/`) covers courses,
topics and lessons from the course catalog plus each live subject's `subjectIndex`
document — one cached read per subject, never a collection scan. The top bar's Search
opens a palette over the page (also Ctrl/⌘+K from anywhere; arrows, Enter, Esc); `/search?q=` is the full page and
the phone's way in. Nothing about searches is stored or logged.

**Routing.** `lib/core/router/app_router.dart` is the live router: `appRouterProvider` builds the `GoRouter`, and a private `_RouterNotifier` listening to `authStateProvider` drives `refreshListenable`. The redirect gates every route except `/signin` behind auth, and returns `null` while auth is loading. Do not duplicate redirect logic elsewhere.

**Real URLs.** Since 2026-10-14 the app uses path URLs (`usePathUrlStrategy()` in `main.dart`), and `GoRouter.optionURLReflectsImperativeAPIs = true` makes `context.push` update the address bar, so every screen's URL can be copied and shared. An inline script in `web/index.html` rewrites old `/#/…` links before Flutter starts; `firebase.json`'s SPA rewrite serves deep paths. A signed-out visitor bounced to welcome carries the target as `/welcome?next=…` (`return_to.dart`: `safeNextPath` allows in-app paths only — no open redirect), and signing in, finishing onboarding or "Browse as guest" goes there instead of `/`. `ShareLinkButton` shares a page (Web Share API on phones, else copy). `lib/core/web/browser.dart` holds the few browser APIs used (`setLeaveGuard` — "Leave site?" while a WAEC exam or a topic test with answers is open — `shareLink`, `appOrigin`), with no-op stand-ins off the web.

**Readable URLs.** Links are built from slugs:
- `/subject/mathematics/course/topic/indices`, with `/drill` and `/test` after it;
- `/waec/mathematics/setup`.

Build them with `Course.topicPath`, `drillPath`, `testPath` and `pathForTopicId`, never
by hand from ids. `Course.findTopic` and `subjectIdForKeyProvider` accept an id or a slug,
ids first, so old links keep working. `SubjectKeyRoute` and `CourseTopicRoute`
(`features/route_keys.dart`) resolve a route's key from data already cached.

**Deferred screens.** The router imports rarely used screens `deferred as` and builds
them through `DeferredScreen`. That covers the studio, rooms, the WAEC exam, challenges,
theory, settings, account and onboarding.
- **The bundle budget.** `main.dart.js` is about 4.75 MB unpacked; CI fails above 5 MB.
- **Split only by the router.** A deferred library must not be imported eagerly
  anywhere else, or it is pulled back into the main bundle.
- **No deferred types in `is` checks.** Put a route builder in the library instead, as
  `waecExamRoute` does.
- **Shared helpers stay eager.** Move them out first; the studio's paths live in
  `admin_paths.dart` for this reason.

**Search over past questions.** `build_static_site.js` writes
`/past-questions/search.json`, with rows of subject, year, stem and id. Search fetches it
only for queries of three characters or more, so it costs no reads. Results open the
static pages (`openSearchPath`).

**Fonts.** Space Grotesk and Atkinson Hyperlegible (the reading font) are bundled in
`assets/google_fonts/`, and `GoogleFonts.config.allowRuntimeFetching` is false: nothing is
fetched from fonts.gstatic.com except Flutter's own Roboto. A new weight or font family
needs its file added, named as google_fonts expects (`Family-Variant.ttf`), or that text
silently falls back. `bundled_fonts_test.dart` checks every `GoogleFonts.*` call in `lib/`.

**`lib/core/config/site_config.dart`** holds `kSiteOrigin` and `kTagline`. Changing the
origin is the code side of a domain move; `build_static_site.js` reads it.

`app_router.dart` and `return_to.dart` are the only files in `lib/core/router/`. The top nav that used to
live in `app_top_nav.dart` is now the shell's `TopBar`; that file is `page_layout.dart`. The old route-tree sketches
(`paragon_router.dart`, `router_redirect.dart`, `paragon_scaffold.dart`) are deleted; if an
older doc mentions them, it is out of date.

**The lesson format.** `docs/LESSON_FORMAT.md` is the spec.
`parseLessonDoc` (`lib/core/lessons/lesson_doc.dart`) is the **one** parser:
the renderer, the problems panel, the subject index, read-aloud and the
glossary all use it.
- **Blocks.** Fenced blocks (`::: kind` … `:::`) add callouts (definition,
  formula, remember, mistake, exam, and the rest), worked examples with
  `--- step`s, try-it, quick checks (`- [x]`; instant feedback, **never
  recorded**), `::: check q:<id>` / `::: waec q:<id>` bank questions,
  revision cards, figures (`![caption](asset:<id>)`), pipe tables,
  `::: more`, `::: video` and `::: todo` (editor-only).
- **Old articles are untouched.** Plain text between fences still goes
  through `parseArticleBlocks`; a control test proves every old article
  parses exactly as before. Malformed input never throws or drops text, and
  is reported as a `LessonIssue` with a line number.
- **Block keys.** Every top-level block has a stable `key`: type, FNV-1a of
  its normalised text, and occurrence. The hash is split so it matches on
  web, where ints are doubles. Notes and cards anchor to these keys.
- **Hooks.** `ArticleView` takes a `BlockDecorator`. `ArticlePane` composes
  the glossary, notes and read-aloud decorators and header controls from
  their hook files (`lib/features/study/*/…_hooks.dart`), so none of those
  features edits the renderer.

**`subjectIndex/{subjectId}`** is one document per subject holding the
definitions, formulas and revision cards extracted from **published**
articles, and — for search — an entry for **every** topic (name-only when
nothing is published) with `lessons: [{id, title, type}]` for its openable
published items. A student gets the glossary, formula sheet and card deck
for one read. It is rebuilt per topic on publish, unpublish and delete, per
subject by "Rebuild search, glossary & cards", and for every subject by
"Rebuild all subjects" — run that once after the search change deploys, then
check a production document actually has `lessons`. Card ids are `topic:resource:key`
with dots replaced, because they are map keys in `study/{uid}.cards`.

**Study tools** go through `StudyDock`, which wraps the lesson, drill,
topic test and WAEC exam screens. Tools implement `StudyTool` and add one
line to `study_tool_registry.dart`.
- **Availability** comes from `subject_tools.dart`. Exams narrow to
  `examAllowedTools`: calculator, four-figure tables and scratchpad. The
  periodic table is **off in exams by decision** (nothing official says
  WAEC supplies one; papers give the atomic masses they need) and
  available everywhere students learn.
- **The tools:** calculator (hand-written fx-82-style engine), scratchpad,
  periodic table (CIAAW 2024 data, cited in the asset), four-figure tables
  (computed, never typed), units and constants (CODATA 2018), glossary and
  formula sheet.
- **State.** Tool state for one screen visit lives in `StudySession`, which
  the dock owns: rough work never follows the student to the next screen.
  State that should persist, like calculator memory, lives in a provider.

**Student study data** is **notes, highlights, bookmarks and revision
cards**:
- `notes/{id}`: one per annotated block, with a snapshot so a reworded
  lesson shows the note as "from an earlier version" instead of losing it.
- `study/{uid}`: `bookmarks` plus the Leitner `cards` schedule, written
  **once per review session**, always as a merge. The rule names both
  fields: a merge is checked against the merged document.
- **Guests** keep all of this on the device only; anonymous accounts cannot
  write either path.
- Both are in `deleteOwnedDocuments` and in `legal_documents.dart`. Cards
  never touch `progress` or `attempts`.

**Other student features:**
- **Read aloud:** `flutter_tts`, with a LaTeX-to-speech converter that
  never speaks hidden answers.
- **Save for offline:** prefetches a topic into the 100 MB Firestore cache;
  videos can't be cached.
- **Reading settings:** text size is applied app-wide; line spacing and the
  Atkinson Hyperlegible font apply to articles.
- **Low-data mode:** images and videos load only on tap.
- **Lesson nudge:** shown above the topic test. It is never a gate.
- **AI tutor:** "Ask (soon)" is greyed out. `AiTutor` in `lib/core/ai/` is
  the seam, and nothing is sent anywhere.

**Plugins added in this work:** `flutter_tts` and `file_picker`. Run
`flutter clean` before the next release build (see the top of this file).

**LaTeX.** `flutter_math_fork` only — `flutter_tex` is banned and breaks builds. `FullLatexView` (`lib/core/widgets/full_latex_view.dart`) is the real renderer: a hand-written scanner over mixed text + math supporting `\(...\)`, `\[...\]`, `$$...$$`, `\textbf`, `\textit`, `\vspace{Ncm}`, with a red monospace fallback on parse errors. `MathText` delegates to it by default; `useLightRenderer: true` selects its own lighter inline parser — the two must agree, since they are chosen by a flag on the same widget.

**Answer options.** Every multiple-choice option a student answers is `AnswerOption`
(`lib/core/widgets/answer_option.dart`): drill, the topic test, exercises, the taster,
mistakes practice, the unit test and every review. Only the WAEC exam keeps its own tile, and
it has the same semantics. A screen reader hears "Option B: 4, selected", then "…, incorrect":
one node, in a mutually exclusive group, with its own tap action. The verdict under a marked
question is `AnswerVerdict`, in words and an icon, in a live region. Don't build a new
option tile inline; drill's had no accessible name at all (audit D1–D4).

**"Practised" topics** (Home's count, a course's "N of M topics started") are
`practisedTopicIds`: drill answers in `progress` or a topic test in `learn`. It is display
only.

**Maths is spoken.** Any line with maths, in either renderer, is one semantics node
labelled by `speakText` (`lib/core/a11y/speech_text.dart`, the read-aloud converter), via
`mathSemantics()`. `flutter_math_fork` exposes nothing, so before this a screen reader
heard "If F = " then "C + 32". When you add `excludeSemantics` to a tappable thing, give
the `Semantics` its own `onTap`, or the action disappears with the children
(`exam_ux_test.dart` caught exactly that on the exam options).

**`web/index.html` must not load MathJax.** Maths is drawn on the canvas by
`flutter_math_fork`; a MathJax `<script>` sat in the page head until 2026-09-25,
1.2 MB of render-blocking download that nothing used. The page now carries only
an inline-CSS loading splash, removed on Flutter's `flutter-first-frame` event.
The icons, `favicon.png`, `og-image.jpg` and the app's own `assets/images/paragon_logo*.png`
(128 px tall, 2x their largest drawn size) are generated from the full-size sources in
`tool/logo_source/` by `dart run tool/make_icons.dart`; re-run it if the logo changes,
and never put a full-size image in `assets/` (the 149 KB logo was the largest thing on
the first screen after the engine). The logo itself is drawn only by `ParagonLogo`
(`lib/core/widgets/paragon_logo.dart`), which picks `paragon_logo.png` (white letters) on
dark and `paragon_logo_light.png` (black letters) on light — the white wordmark vanishes on
the light background. Change both files together. `og:image` is an absolute URL, as link-preview crawlers require.

Until 2026-09-25 `FullLatexView` returned the **raw source** for any line with no equation on it, so `\textbf{..}`, `\textit{..}`, `\vspace{..}` and `\$` showed literally unless the same line also held math; `latex_render_test.dart` now pins both cases. Inline math is also wrapped in a horizontal scroll view, so an expression wider than a phone screen scrolls instead of overflowing. Article quotes: consecutive `>` lines are one quote block (a blank line separates two).

`\emph` is **not** supported (use `\textit`), and a lone `$` is a literal dollar sign, **not** an inline-math delimiter. Inline math is `\(...\)` — the format the scrapers and all 216 generator modules emit. `$...$` was removed because every `$` in the corpus is currency and none is math, and treating it as a delimiter parsed the text between two prices as an expression. See `docs/LATEX_RENDERING.md`, which is now accurate.

**Theme.** `AppColors` is the only place a colour is *defined* — no raw `Color()` literals in widgets; `AppColors.forSubject(name)` maps subject names to their card colors. Colours that differ between themes are read from **`context.palette`** (`AppPalette`, a `ThemeExtension` in `lib/core/theme/app_palette.dart`): background, surface, border, track, text primary/secondary, and `textStrong`/`onHigh`/`onMedium`/`onLow`/`outline`/`outlineFaint`, which reproduce the old `Colors.white`/`white70`…`white12` in dark — except `onLow`, raised from `white38`/`black38` to 50% white / 56% black so small text passes WCAG AA (4.5:1). **Never use `AppColors.*Dark` or translucent white in a widget** — it will be wrong in light. White stays correct only on a solid brand colour (a button label on orange). Dark is the default; students choose Dark / Light / Match device in Settings → Reading and display (`appearanceProvider`). **`kAppearanceChoiceEnabled` is `true`** since 2026-10-03, after an audit left no dark-only colour in any widget; turning it off hides the choice and forces dark. Where there is no `BuildContext` (a canvas outline, a fallback swatch) use `AppColors.neutral`, a mid grey that reads on both. The logo has a light version too (see `ParagonLogo`).

## Firestore conventions

Collections: `subjects`, `units` (`subjectId`, `order`), `topics` (`subjectId`, `unitId`, `questionCount`, `order`), `topics/{id}/resources/{id}` (Learn content — the only subcollection in the app), `questions`, `users/{uid}`, `attempts`, `flags`, `usernames/{key}`, `progress/{uid}`, `learn/{uid}`, `notes`, `study/{uid}`, `lessonAssets`, `subjectIndex/{subjectId}`, `staffInvites/{email}` (Team page requests; admin-only), `examResults/{id}` (one per finished WAEC exam: its items and score, for `/waec/review/:examId` and the subject's history; owner-only, never updated), `accountRequests/{uid}` ("sign out everywhere", applied by `apply_account_requests.js` in the 15-minute workflow), `staffProfiles/{uid}` (a team member's name and avatar for the studio; team-readable), `plan/{uid}` (weekly goal from `kWeeklyGoals` and exam date only; accounts only, owner-only), `insights/{id}` (examiner insights: per question by its id, per topic as `topic_<topicId>`; writers draft, reviewers publish, students *get* published ones only when `questions.hasInsight` / `topics.hasExaminerThemes` say one exists — stamped by `jobs.js --job=insights`), `contributors/{uid}` (public bylines `{displayName, role, credential}`; Admin-SDK-only via `tools/admin/set_contributor.js`, after consent and a credential check), `theoryQuestions/{id}` (Paper 2, Admin-SDK-written, published-only for students, hidden until a subject has `kTheoryMinQuestions` = 20; `subjects.theoryCount` from the counts job), `rooms/{code}` (live quiz: host-written `{hostUid, subjectId, topicId, topicName, questionIds ≤20, state, index, createdAt, results}`, plus `players/{uid}` nicknames and `answers/{uid_index}` accepted only while that question is live; guests join, accounts host; a day long, then `jobs.js --job=rooms`), `challenges/{id}` ("Challenge a friend": `{userId, name, subjectId, topicId, topicName, questionIds ≤10, score, total, createdAt}`; written once, *get* by anyone signed in, *list* and delete by the creator; deleted after 30 days by `jobs.js --job=challenges`), `waitlist/{uid}` ("Notify me" on a coming-soon subject: `{userId, subjects: [catalog slug], updatedAt}`; accounts only, owner-written, reviewer-readable so the studio can `count()` per subject), `feedback/{id}` ("Send feedback" from Settings/About: `{userId, kind, message, screen, createdAt}`, guests allowed, same access shape as `flags`, triaged in the studio), `metrics/{day}` (daily aggregate counts from `jobs.js --job=metrics`, Lagos day; admins read them in the studio's Traction panel; no uid or name), `_meta/notify` (the digest's cursors, `flagsNotifiedThrough` and `feedbackNotifiedThrough`; Admin-SDK-only), `_meta/usage` (daily Firestore read/write counts from `tools/admin/usage.js`; the only `_meta` document a client may read, and only a reviewer).

- `flags` are `{questionId, userId, reason, createdAt}` — or, for a lesson report, `{resourceId, topicId, …}` with no `questionId` — plus, once reviewed, `status` (`open | fixed | dismissed`), `resolvedAt`, `resolvedBy`. **A missing `status` means open**: reports from before review existed, or from a cached build, carry none, and nothing backfills them. A student may file one only without a status or as `open`; only a reviewer may change those three fields, and nothing else on a report is ever rewritten. The create rule is a closed field set with `createdAt == request.time`. `notify_drafts.js` pages through reports by `createdAt`, so one report dated in the future would silence every report email after it; the job also ignores a cursor set in the future.
- `questions` take exactly one client write: a reviewer resolving a report may change `correctIndex` (bounded by the option count), `previousCorrectIndex`, `hasAnswer`, `reviewedAt` and `reviewedBy`. Stem, options and topic stay Admin-SDK-only. `verify_rules.js` asserts a student can do none of it.

- `attempts` accepts exactly `AttemptRepository._attemptData`'s fields, with `source` from the seven values and `timestamp == request.time`. A new attempt field needs the rule first.
- `usernames` refuses guests and names that pass as Paragon. The reserved list is in three places, kept in step: the rule, `UsernameRules.isReserved` and `security_audit.js`.
- `questions.options` stores option text **without** the A/B/C/D prefix — the UI adds labels.
- `questions.imageId` / `explanationImageId` are `lessonAssets` ids for a diagram the question depends on and a worked-answer picture. Only scraped past questions have them, set by `10_fetch_question_images.js`; `QuestionImage` renders them everywhere a question appears. A question whose diagram the source no longer serves is retired with `hasAnswer: false, needsDiagram: true` — to restore one, attach an image and flip `hasAnswer` back.
- `questions.correctIndex` is 0-based. It is `-1` on the **scraped** corpus (answers were never scraped) and a real index on the **generated** corpus, so both cases are live in production at once — never assume either. `-1` is the app's "no verified answer" value and is the required fallback; a `0` fallback silently marks option A correct.
- `topics/{id}/resources/{id}.status` is `draft | in_review | changes_requested | published` (see `docs/CONTENT_ROLES.md`) and **must be present** — only the exact string `published` is student-visible, in the rule and in `ResourceStatus.parse` alike. **Rules are not filters**: students may only list resources with `where('status', '==', 'published')` (served by the `status + order` index), and an unfiltered list is refused. Drop that filter and every Learn screen becomes a permission error. Never add a "missing status counts as published" clause to the rule: it was tried, and because list evaluation models `resource.data` from the query's filters, it let an unfiltered list return drafts to any student (caught by `verify_rules.js`, which now checks against a real seeded draft). `9_seed_resources.js` writes `published` and overwrites on id collision, including an editor draft with the same slug. A client write must carry the **parent topic's** `subjectId` (the rule `get()`s it), or a subject-limited role could file items under another subject's topic. A writer's `createdBy` is their own uid and never changes, because the delete rule trusts it.
- `questions.subjectId` is required on every document — drill queries use `topicId`, WAEC queries use `subjectId` + `source` + `year`.
- Every `fromFirestore` must stay fully null-safe, and does so via the helpers in `lib/core/models/firestore_parsing.dart` (`docData`, `asString`, `asInt`/`asIntOrNull`, `asBool`, `asStringList`) — use those rather than writing fresh casts. They coerce instead of throwing, because these run inside provider mapping: a throw on one document takes down the whole screen, not just that row. `asStringList` stringifies bad entries rather than dropping them, since `correctIndex` indexes into the list. `test/model_null_safety_test.dart` covers this and carries a control group; if you change the helpers, that control group is what proves the tests still mean something.
- `topics.lessonCount` is the number of published, openable Learn items, the denominator of "2 of 6 lessons" on the course index. **Zero means "not known"**, like `topicCount`. Written by the editor on every save and delete (`AdminResourceRepository.refreshLessonCount`), by `9_seed_resources.js`, and recomputed nightly by `jobs.js --job=counts`. It is the **only** topic field a client may update, and only a reviewer; `verify_rules.js` asserts a student cannot. "Openable" is `LearnResource.isAvailable`, mirrored in JS in `jobs.js` and the seeder, so change all three together.
- **Resources the editor created or edited carry `createdBy` or `editedInApp`, and `9_seed_resources.js` skips them** unless run with `--force`. The seeder writes each file as the whole truth, so without this, re-seeding would wipe a YouTube link added in the editor and republish a draft.
- `subjects.topicCount` is the denominator for a subject-level progress ring. Written by the seeders, recomputed nightly by `tools/admin/jobs.js --job=counts`. **Zero means "not known", never "no topics"** — a subject seeded before the field existed reads zero until the job next runs, so callers must suppress the ring rather than draw an empty one.
- **Question counts** are never one number that reads as "past questions". `jobs.js --job=counts` writes every topic's `questionCount` (`hasAnswer: true`), `pastQuestionCount` (`source == 'waec'`) and `practiceQuestionCount` (`origin == 'ai_generated'`) with `count()` aggregates, and each **subject's** three fields as the **sum of its topics'** — so the welcome ticker and the course page cannot disagree again (they did: 14,602 vs 14,616). Every surface shows `QuestionCounts.label` ("51 past · 300 practice"); both split fields zero means "not split yet", and the old single total is shown. `tools/admin/check_counts.js` asserts subject == sum of topics. Counts drift when an admin retires a question, until the next nightly run.
- **Provenance.** `Question.origin` is read in the app; `provenanceLabel` gives "WAEC 2018" for a past question and "Paragon practice" for a generated one (origin wins over `source`), shown by `QuestionSourceBadge` wherever a question is. A WAEC subject with no past questions shows "No past questions yet" and does not open.
- **Placeholders.** `checkPublishable` (`lesson_check.dart`) refuses to publish a placeholder title (`test2`, `test_article`, `Sample`…), an empty article or a linkless video; a reviewer can override with a reason kept as a comment. `tools/admin/content_lint.js` applies the same rules to what is live, read-only, exiting non-zero — keep the two regexes in step.
- `progress/{uid}` is one document per student: `{userId, updatedAt, topics: {<topicId>: {answered, correct, subjectId}}}`. Owner-only in both directions, closed top-level field set, `updatedAt` pinned to the `serverTimestamp()` sentinel. The `subjectId` stamp is what lets the dashboard group by subject without loading any course outlines.
- `learn/{uid}` holds topic-test results **and lesson completion**: `{userId, updatedAt, topics: {<topicId>: {passed, bestScore, attempts, subjectId, lastAttemptAt, completed: {<resourceId>: true}, lastCompletedId, lastCompletedAt}}}`. The rules pin only the top-level field set, so the nested completion fields need no rules change; each parser ignores the other's keys, and a completion-only entry reads as "no test taken" (pinned by `lesson_progress_test.dart`). **Deliberately not merged into `progress/{uid}`** — that document is described everywhere as a cache recomputable from `attempts`, and a test pass is not recomputable (nothing records which ten answers were one sitting). One document, not a subcollection: drawing padlocks on a forty-row topic list must cost one read, not forty.
- `attempts.source` is now one of `drill | waec | test | exercise | review | challenge | challenge_link` (`review` is practice from the mistakes notebook; `challenge` a unit test or course challenge). Drill and WAEC queries filter on it; **only drill feeds the mastery counters** — test and exercise answers must never call `ProgressRepository.addSession`, because mastery at proficient opens drill on its own (`drillAccessFor` has no date check; the "grandfathering" is permanent), so either would be a way around the topic test. `exercise_pane_test.dart` asserts nothing reaches `progress`. Review answers follow the same rule (`mistakes_notebook_test.dart`). **Hints** (`lib/core/learn/hints.dart`) are the explanation's steps minus the last, offered in drill and exercises and never in the topic test or WAEC exam; an attempt records `hintsUsed` when non-zero, and a right answer after a hint never counts toward mastery or an exercise score (`drill_hints_test.dart`). The notebook itself stores nothing: a question is in it while its latest attempt, among the student's last 200, was wrong (`lib/core/progress/mistakes.dart`), read with the `userId ASC, timestamp DESC` index. Exercises, like the topic test, draw from the topic's whole bank including WAEC-sourced questions; the "filter by source" rule above is about drill providers.
- **Anything keyed by uid must be added to `AccountRepository.deleteOwnedDocuments`** — and to `_ownedById`/`_ownedByQuery` (the export) and `OWNED` in `tools/admin/jobs.js` (guest cleanup, scheduled deletions, orphans). `export_test.dart` checks export and deletion cover the same set. Forgetting leaves a student who asked to be deleted, and mostly was.
- **The account system** (`lib/features/account/`, `lib/features/profile/`). `users/{uid}` also carries `avatar` (`preset:<id>` or `initials:<colour>`), `bio` (≤160, private), `usernameChangedAt`, `deletionRequestedAt`, `legalVersion`/`legalAcceptedAt` and `prefs`; every one is allow-listed and shape-checked in `clientFieldsAreValid()`, and every timestamp must be the server's clock.
  - **Profiles are private.** `/me` and the bio are seen only by their owner; nothing social reads `users/{uid}`. A future public profile must be a separate opt-in document.
  - **Guests link, not replace.** `/account/upgrade` links Google or email to the anonymous uid, so everything already stored stays; device-only notes/cards and in-memory lesson ticks are copied up (`guest_upgrade.dart`). An existing account cannot be merged: the student is told their guest progress stays behind. `jobs.js --job=guests` deletes guests idle 30+ days with everything they own.
  - **Usernames change once every 90 days** (rules and `UsernameRules.changeCooldown`); old reservations are never released.
  - **Deleting schedules** (30 days, `/account/deleting`, `jobs.js --job=deletions`) with "delete now" always offered; guests are deleted at once.
  - **"Delete now" order:** first check that the sign-in is recent (`auth_time`), then delete the documents, then the Auth user.
    - Deleting Auth first signs the client out, so every owner-only delete is refused; that is how it worked until 2026-10-16.
    - `account_test.dart` pins the order.
  - **Terms:** bump `kLegalVersion` (and rewrite `kLegalChanges`) only for a significant change — every account is sent to `/legal/accept`.
  - `authStateProvider` is `userChanges()` filtered to account-level changes (uid, anonymous, email, verified, providers); unfiltered it would rebuild everything on the hourly token refresh.
  - Settings that follow an account: `account_prefs_sync.dart`. An analytics opt-out spreads to every device; an opt-in never does.

## Reads, the quota, and errors

- **Every Firestore read in `lib/` ends in `.metered()`** (`lib/core/data/read_meter.dart`),
  new ones included. Debug builds count billed reads per route pattern: a corner
  pill shows them, a tap copies a table for `docs/audit/QUOTA.md`, a long-press
  resets. In every build it is also how a spent quota is noticed.
- **A spent quota.** `resource-exhausted` sets `QuotaStatus`. `QuotaBanner` (above
  the navigator, same tree shape either way) and `LoadError` then say Paragon is
  busy until midnight Pacific, and the next server answer clears it.
- **Cache-first content.** `subjects`, `units` and `topics` go through
  `getCacheFirst` (`cache_first.dart`): 12 hours from the device cache after a
  server fetch, and only while the cache still holds every document. Never use it
  for questions, attempts, progress or anything a student writes.
- **Production errors.** `ErrorReporter` sends `app_error` analytics with the error
  type or Firebase code and the route pattern only, never the message. The same
  key is sent once, and at most ten per session.
- **Usage.** `tools/admin/usage.js` runs in the 15-minute workflow. It needs the
  service account to hold **Monitoring Viewer**; until it does, it logs a notice and
  skips.
- `docs/audit/PERF.md` and `QUOTA.md` hold the measured numbers.

## Riverpod v3 gotchas

`.valueOrNull` does not exist in v3 (still absent in 3.4.3) — read `AsyncValue` with `.asData?.value`. `weeklyAttemptsCountProvider` is a `StreamProvider`; keep it one. Use `StreamProvider` for Firestore streams, `FutureProvider` for one-shots, plain `Provider` for derived state.

## Commits

Conventional commits, with project-specific types/scopes from `.cursorrules`: types `feat|fix|chore|content|refactor|style|docs`; scopes `drill, waec, auth, dashboard, router, theme, models, providers, scraper, seeder, classifier, firestore, latex, android, deploy`. Example: `content(physics): seed 412 physics WAEC questions 1990-2024`.

- A roadmap session number is not a severity rating. Before deferring anything, ask: is this
  absent functionality, or live breakage in code that already ships? Breakage is P0/P1
  regardless of which future session it's filed under.
- "Performance" and similar generic future buckets must not absorb specific known defects.

## Working agreements
- `.cursorrules` is the roadmap. `Spec_Current.docx` and §2.1–2.3 are aspirational intent.
  `PRD_v2.md`, `Tech_Stack.md` and `Execution_Plan.md` are stale (Next.js-era) — do not follow.
  They now live in `paragon_plans/archive/`, kept as history only; see the README there.
- `paragon_plans/router_sketch_deferred/*` is dead. Never wire it in, never cite it as evidence.
- Formatting commits never mix with logic commits.
- The suite is 1024 tests, not the 2 this file once claimed. `test/generated_latex_test.dart`
  is the one with real reach: it parses every LaTeX expression in the generated corpus
  through the actual flutter_math_fork parser and renders a sample through FullLatexView.
  It carries a deliberate control case, so if you change it, keep that — without it the
  suite passes no matter how broken the content is. Still: a green suite is not evidence
  that content is *correct*, only that it parses and renders.
- Client-writable `users/{uid}` xp/topicStats is a hard blocker on any leaderboard or
  gamification work. Do not ship those sessions until writes are server-controlled. The
  `progress/{uid}` mastery cache does not change this and is not an exception to it —
  it is private, display-only, and recomputable from `attempts`. The moment anything
  competitive reads it, that read is the bug.
- Onboarding must not ask for data nothing uses. `selectedSubjects` sat unread for
  everything except one sort order until the dashboard started using it. The optional
  `profile` map is **school and class only** since 2026-10-15 (owner's decision).
  - **Purpose.** The privacy policy says they tell the team which schools and classes
    use Paragon. Nothing in the app is gated on them.
  - **Age, gender, country and state** are no longer asked. `ProfileFormController`
    lists them as `retiredFields`, which an editor save deletes, and
    `jobs.js --job=dropprofile`, a one-shot that is not in `all`, removes them from
    every user.
  - **The rules** accept only `school` (a string of up to 100 characters) and
    `classYear` (one of `ProfileFormController.classYears`) in `profile`, through
    `profileIsValid`. They were tightened on 2026-10-16, once the one-shot found no
    user holding a retired key. A new profile field needs the rule changed first.
- If a screen tells a student they can change something later, there must be a route
  that lets them. `/settings/subjects`, `/settings/name` and `/settings/profile` all
  exist because onboarding had been promising them since it shipped.
- Two writers touch `users/{uid}.profile` and they are deliberate opposites.
  `setProfile` (onboarding) ignores blanks, so skipping a step with one box filled
  cannot wipe the others. `updateProfile` (settings) treats a cleared box as a
  deletion, because on an editor holding data about minors an emptied field is a
  request to remove it. `test/profile_edit_test.dart` pins each as the other's
  control.

  - Content correctness is a defect class, not a content task. Before shipping any feature that
  reads a field, verify the field actually has values in production data — not that the code
  reads it correctly.