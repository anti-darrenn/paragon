# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
flutter build web --release; firebase deploy --only hosting        # deploy (project paragon-hq)
```

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
node reclassify.js                        # propose topic reassignments (dispatch-only in CI)
node check_linkage.js                     # verify topicId linkage after seeding or reclassifying
```

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
78 checks. The denials are the content: a write that succeeds only proves something
allowed it. The emulator would be the usual answer but needs Java, which this machine
does not have.

`project/firestore.rules` and `project/firestore.indexes.json` are both tracked in the repo, and `firebase.json`'s `firestore` block points at each — `firebase deploy --only firestore:rules` and `firebase deploy --only firestore:indexes` deploy these files directly, as `.cursorrules` describes.

## Architecture

Flutter web app (Riverpod v3 + go_router v17 + Firebase v4) over a Firestore content tree seeded by Node scrapers.

**Two parallel product modes that must never merge:**

- Learning Mode — `/` → `/subject/:subjectId` → `.../unit/:unitId` → `.../topic/:topicId` (SubjectList → UnitList → TopicList → Drill). Immediate per-question feedback, attempts recorded with `source: 'drill'`.
- WAEC Prep Mode — `/waec` → `/waec/:subjectId/exam` (WaecSubjectScreen → WaecExamScreen). Full exam run, results at the end, `source: 'waec'`.

Never add WAEC questions to drill providers without filtering by `source`, and never add drill-style instant feedback to the exam flow.

**The drill gate.** `lib/core/learn/topic_test.dart` is the pure model —
scoring, the 80% pass mark (`kTopicTestPassPercent`), and `drillAccessFor`,
which is the *only* place the gate is decided. Drill for a topic opens when
its topic test is passed, or — grandfathered — when drill mastery already
reached proficient before the gate shipped. Guests get no drill at all, and
are refused before proficiency is considered, since a guest's pass dies
with the session. Learn content is never gated.

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
- `writer` and `reviewer`, set by `tools/admin/set_role.js --email=… --role=writer|reviewer|none`;
- `admin`, set by `set_admin_claim.js` / `create_admin_user.js`.

The rules check them with `isWriter()` ⊃ `isReviewer()` ⊃ `isAdmin()`.
`staffRoleProvider` reads them for the UI only. The contract is
`docs/CONTENT_ROLES.md`:
- **Statuses:** `draft → in_review → published`, with `changes_requested`
  sending an item back. Only the exact string `published` is ever
  student-visible.
- **Writers** create and edit only unpublished items, submit them, and
  delete their own drafts.
- **Reviewers** publish, request changes (the reason becomes a comment),
  unpublish, delete, reorder, and handle all problem reports.
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
always opens at `/welcome`, and the router deliberately lets guests stay
there, so a returning Android guest sees the welcome screen rather than
their dashboard — a known, unfixed product question, not a lost session.

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

**Analytics.** `analytics_provider.dart` defines the events; `analytics_binding.dart`
wires the two app-wide ones (screen views, `is_guest`) and is watched by `app.dart` for
its side effects. Screen names are **route patterns** (`/subject/:subjectId/...`), never
concrete URLs — no document ids in screen names, and no thousand-row reports. `Analytics`
reads the opt-out flag at call time and resolves `FirebaseAnalytics.instance` lazily, so
an instance is safe to hold in a `State` field (Riverpod 3 forbids `ref` in `dispose()`,
which is where `DrillScreen` ends its session). **`legal_documents.dart` must change with
this file** — it describes to users exactly what is collected, and the policy previously
claimed an `is_guest` property that nothing ever set.

**Data flow.** Screens are `ConsumerWidget`s that watch providers in `lib/core/repositories/learning_repository.dart` (`subjectsProvider`, `unitsProvider`, `topicsProvider`, `drillQuestionsProvider(topicId)`, `waecQuestionsProvider(subjectId)` — all `FutureProvider`/`.family` reading Firestore directly). Writes go through `AttemptRepository.record()` and `ProgressRepository.addSession()`. Auth/user streams live in `lib/core/providers/auth_provider.dart` (`authStateProvider`, `currentUserProvider`, `userDataProvider`, `weeklyAttemptsCountProvider`).

**Routing.** `lib/core/router/app_router.dart` is the live router: `appRouterProvider` builds the `GoRouter`, and a private `_RouterNotifier` listening to `authStateProvider` drives `refreshListenable`. The redirect gates every route except `/signin` behind auth, and returns `null` while auth is loading. Do not duplicate redirect logic elsewhere.

`app_router.dart` is the only file in `lib/core/router/`. The old route-tree sketches
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
articles. A student gets the glossary, formula sheet and card deck for one
read. It is rebuilt per topic on publish, unpublish and delete, and per
subject by "Rebuild glossary & cards". Card ids are `topic:resource:key`
with dots replaced, because they are map keys in `study/{uid}.cards`.

**Study tools** go through `StudyDock`, which wraps the lesson, drill,
topic test and WAEC exam screens. Tools implement `StudyTool` and add one
line to `study_tool_registry.dart`.
- **Availability** comes from `subject_tools.dart`. Exams narrow to
  `examAllowedTools`: calculator, four-figure tables and scratchpad. The
  periodic table stays **off in exams** until WAEC's rule is checked.
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

**`web/index.html` must not load MathJax.** Maths is drawn on the canvas by
`flutter_math_fork`; a MathJax `<script>` sat in the page head until 2026-09-25,
1.2 MB of render-blocking download that nothing used. The page now carries only
an inline-CSS loading splash, removed on Flutter's `flutter-first-frame` event.
`web/icons/` and `favicon.png` are still Flutter's logo, which is why the page
has no `og:image` yet.

Until 2026-09-25 `FullLatexView` returned the **raw source** for any line with no equation on it, so `\textbf{..}`, `\textit{..}`, `\vspace{..}` and `\$` showed literally unless the same line also held math; `latex_render_test.dart` now pins both cases. Inline math is also wrapped in a horizontal scroll view, so an expression wider than a phone screen scrolls instead of overflowing. Article quotes: consecutive `>` lines are one quote block (a blank line separates two).

`\emph` is **not** supported (use `\textit`), and a lone `$` is a literal dollar sign, **not** an inline-math delimiter. Inline math is `\(...\)` — the format the scrapers and all 216 generator modules emit. `$...$` was removed because every `$` in the corpus is currency and none is math, and treating it as a delimiter parsed the text between two prices as an expression. See `docs/LATEX_RENDERING.md`, which is now accurate.

**Theme.** `AppColors` is the only color source — no raw `Color()` literals in widgets; `AppColors.forSubject(name)` maps subject names to their card colors. Dark theme is enforced (`ThemeMode.dark` in `app.dart`); the light theme exists but is not selectable.

## Firestore conventions

Collections: `subjects`, `units` (`subjectId`, `order`), `topics` (`subjectId`, `unitId`, `questionCount`, `order`), `topics/{id}/resources/{id}` (Learn content — the only subcollection in the app), `questions`, `users/{uid}`, `attempts`, `flags`, `usernames/{key}`, `progress/{uid}`, `learn/{uid}`, `notes`, `study/{uid}`, `lessonAssets`, `subjectIndex/{subjectId}`, `_meta/notify` (the report digest's cursor; no rule matches `_meta`, so it is Admin-SDK-only).

- `flags` are `{questionId, userId, reason, createdAt}` — or, for a lesson report, `{resourceId, topicId, …}` with no `questionId` — plus, once reviewed, `status` (`open | fixed | dismissed`), `resolvedAt`, `resolvedBy`. **A missing `status` means open**: reports from before review existed, or from a cached build, carry none, and nothing backfills them. A student may file one only without a status or as `open`; only a reviewer may change those three fields, and nothing else on a report is ever rewritten.
- `questions` take exactly one client write: a reviewer resolving a report may change `correctIndex` (bounded by the option count), `previousCorrectIndex`, `hasAnswer`, `reviewedAt` and `reviewedBy`. Stem, options and topic stay Admin-SDK-only. `verify_rules.js` asserts a student can do none of it.

- `questions.options` stores option text **without** the A/B/C/D prefix — the UI adds labels.
- `questions.correctIndex` is 0-based. It is `-1` on the **scraped** corpus (answers were never scraped) and a real index on the **generated** corpus, so both cases are live in production at once — never assume either. `-1` is the app's "no verified answer" value and is the required fallback; a `0` fallback silently marks option A correct.
- `topics/{id}/resources/{id}.status` is `draft | in_review | changes_requested | published` (see `docs/CONTENT_ROLES.md`) and **must be present** — only the exact string `published` is student-visible, in the rule and in `ResourceStatus.parse` alike. **Rules are not filters**: students may only list resources with `where('status', '==', 'published')` (served by the `status + order` index), and an unfiltered list is refused. Drop that filter and every Learn screen becomes a permission error. Never add a "missing status counts as published" clause to the rule: it was tried, and because list evaluation models `resource.data` from the query's filters, it let an unfiltered list return drafts to any student (caught by `verify_rules.js`, which now checks against a real seeded draft). `9_seed_resources.js` writes `published` and overwrites on id collision, including an editor draft with the same slug.
- `questions.subjectId` is required on every document — drill queries use `topicId`, WAEC queries use `subjectId` + `source` + `year`.
- Every `fromFirestore` must stay fully null-safe, and does so via the helpers in `lib/core/models/firestore_parsing.dart` (`docData`, `asString`, `asInt`/`asIntOrNull`, `asBool`, `asStringList`) — use those rather than writing fresh casts. They coerce instead of throwing, because these run inside provider mapping: a throw on one document takes down the whole screen, not just that row. `asStringList` stringifies bad entries rather than dropping them, since `correctIndex` indexes into the list. `test/model_null_safety_test.dart` covers this and carries a control group; if you change the helpers, that control group is what proves the tests still mean something.
- `topics.lessonCount` is the number of published, openable Learn items, the denominator of "2 of 6 lessons" on the course index. **Zero means "not known"**, like `topicCount`. Written by the editor on every save and delete (`AdminResourceRepository.refreshLessonCount`), by `9_seed_resources.js`, and recomputed nightly by `jobs.js --job=counts`. It is the **only** topic field a client may update, and only a reviewer; `verify_rules.js` asserts a student cannot. "Openable" is `LearnResource.isAvailable`, mirrored in JS in `jobs.js` and the seeder, so change all three together.
- **Resources the editor created or edited carry `createdBy` or `editedInApp`, and `9_seed_resources.js` skips them** unless run with `--force`. The seeder writes each file as the whole truth, so without this, re-seeding would wipe a YouTube link added in the editor and republish a draft.
- `subjects.topicCount` is the denominator for a subject-level progress ring. Written by the seeders, recomputed nightly by `tools/admin/jobs.js --job=counts`. **Zero means "not known", never "no topics"** — a subject seeded before the field existed reads zero until the job next runs, so callers must suppress the ring rather than draw an empty one.
- `subjects.questionCount` counts the subject's `hasAnswer: true` questions, the ones a student can be served, and is shown on the welcome screen. Also written by `jobs.js --job=counts`, with the same "zero means not known, hide it" rule. It drifts when an admin retires a question, until the next nightly run.
- `progress/{uid}` is one document per student: `{userId, updatedAt, topics: {<topicId>: {answered, correct, subjectId}}}`. Owner-only in both directions, closed top-level field set, `updatedAt` pinned to the `serverTimestamp()` sentinel. The `subjectId` stamp is what lets the dashboard group by subject without loading any course outlines.
- `learn/{uid}` holds topic-test results **and lesson completion**: `{userId, updatedAt, topics: {<topicId>: {passed, bestScore, attempts, subjectId, lastAttemptAt, completed: {<resourceId>: true}, lastCompletedId, lastCompletedAt}}}`. The rules pin only the top-level field set, so the nested completion fields need no rules change; each parser ignores the other's keys, and a completion-only entry reads as "no test taken" (pinned by `lesson_progress_test.dart`). **Deliberately not merged into `progress/{uid}`** — that document is described everywhere as a cache recomputable from `attempts`, and a test pass is not recomputable (nothing records which ten answers were one sitting). One document, not a subcollection: drawing padlocks on a forty-row topic list must cost one read, not forty.
- `attempts.source` is now one of `drill | waec | test | exercise`. Drill and WAEC queries filter on it; **only drill feeds the mastery counters** — test and exercise answers must never call `ProgressRepository.addSession`, because mastery at proficient opens drill on its own (`drillAccessFor` has no date check; the "grandfathering" is permanent), so either would be a way around the topic test. `exercise_pane_test.dart` asserts nothing reaches `progress`. Exercises, like the topic test, draw from the topic's whole bank including WAEC-sourced questions; the "filter by source" rule above is about drill providers.
- **Anything keyed by uid must be added to `AccountRepository.deleteOwnedDocuments`.** Forgetting leaves a student who asked to be deleted, and mostly was.

## Riverpod v3 gotchas

`.valueOrNull` does not exist in v3.3.1 — read `AsyncValue` with `.asData?.value`. `weeklyAttemptsCountProvider` is a `StreamProvider`; keep it one. Use `StreamProvider` for Firestore streams, `FutureProvider` for one-shots, plain `Provider` for derived state.

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
- The suite is 713 tests, not the 2 this file used to claim. `test/generated_latex_test.dart`
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
  `profile` map (school, class, age, gender, country, state) still has **no reader
  anywhere in `lib/`** — collected, editable and deletable, but consumed by nothing.
  The owner's standing decision is to keep collecting and decide later; it is data
  about minors, so revisit it before any public launch rather than letting it settle.
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