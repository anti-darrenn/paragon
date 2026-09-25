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
59 checks. The denials are the content: a write that succeeds only proves something
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

**Admin / content editor.** The only privileged role is the `admin` custom
claim on the Auth token — set by `tools/admin/set_admin_claim.js` (or
`create_admin_user.js`, which also provisions or `--upgrade`s an account),
never a field on `users/{uid}`, since anything a client can write there it
can grant itself. `firestore.rules` checks it with `isAdmin()`;
`isAdminProvider` reads it for the UI only. `/admin` (reached from Settings
→ Content editor) lists drafts across every topic and edits **articles**;
videos and exercises are still seeder-only. Editor articles are written as
`status: 'draft'` and go live on Publish. `notify_drafts.js`, run every 15
minutes by `.github/workflows/notify-drafts.yml`, emails the reviewers via
Resend (`RESEND_API_KEY` secret) and stamps `notifiedAt` so it sends once.
The workflow skips cleanly while that secret is unset — Resend is not set up
yet (the account was held for review on 2026-09-24).

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

**LaTeX.** `flutter_math_fork` only — `flutter_tex` is banned and breaks builds. `FullLatexView` (`lib/core/widgets/full_latex_view.dart`) is the real renderer: a hand-written scanner over mixed text + math supporting `\(...\)`, `\[...\]`, `$$...$$`, `\textbf`, `\textit`, `\vspace{Ncm}`, with a red monospace fallback on parse errors. `MathText` delegates to it by default; `useLightRenderer: true` selects its own lighter inline parser — the two must agree, since they are chosen by a flag on the same widget.

Until 2026-09-25 `FullLatexView` returned the **raw source** for any line with no equation on it, so `\textbf{..}`, `\textit{..}`, `\vspace{..}` and `\$` showed literally unless the same line also held math; `latex_render_test.dart` now pins both cases. Inline math is also wrapped in a horizontal scroll view, so an expression wider than a phone screen scrolls instead of overflowing. Article quotes: consecutive `>` lines are one quote block (a blank line separates two).

`\emph` is **not** supported (use `\textit`), and a lone `$` is a literal dollar sign, **not** an inline-math delimiter. Inline math is `\(...\)` — the format the scrapers and all 216 generator modules emit. `$...$` was removed because every `$` in the corpus is currency and none is math, and treating it as a delimiter parsed the text between two prices as an expression. See `docs/LATEX_RENDERING.md`, which is now accurate.

**Theme.** `AppColors` is the only color source — no raw `Color()` literals in widgets; `AppColors.forSubject(name)` maps subject names to their card colors. Dark theme is enforced (`ThemeMode.dark` in `app.dart`); the light theme exists but is not selectable.

## Firestore conventions

Collections: `subjects`, `units` (`subjectId`, `order`), `topics` (`subjectId`, `unitId`, `questionCount`, `order`), `topics/{id}/resources/{id}` (Learn content — the only subcollection in the app), `questions`, `users/{uid}`, `attempts`, `flags`, `usernames/{key}`, `progress/{uid}`, `learn/{uid}`.

- `questions.options` stores option text **without** the A/B/C/D prefix — the UI adds labels.
- `questions.correctIndex` is 0-based. It is `-1` on the **scraped** corpus (answers were never scraped) and a real index on the **generated** corpus, so both cases are live in production at once — never assume either. `-1` is the app's "no verified answer" value and is the required fallback; a `0` fallback silently marks option A correct.
- `topics/{id}/resources/{id}.status` is `draft | published` and **must be present** — only the exact string `published` is student-visible, in the rule and in `ResourceStatus.parse` alike. **Rules are not filters**: students may only list resources with `where('status', '==', 'published')` (served by the `status + order` index), and an unfiltered list is refused. Drop that filter and every Learn screen becomes a permission error. Never add a "missing status counts as published" clause to the rule: it was tried, and because list evaluation models `resource.data` from the query's filters, it let an unfiltered list return drafts to any student (caught by `verify_rules.js`, which now checks against a real seeded draft). `9_seed_resources.js` writes `published` and overwrites on id collision, including an editor draft with the same slug.
- `questions.subjectId` is required on every document — drill queries use `topicId`, WAEC queries use `subjectId` + `source` + `year`.
- Every `fromFirestore` must stay fully null-safe, and does so via the helpers in `lib/core/models/firestore_parsing.dart` (`docData`, `asString`, `asInt`/`asIntOrNull`, `asBool`, `asStringList`) — use those rather than writing fresh casts. They coerce instead of throwing, because these run inside provider mapping: a throw on one document takes down the whole screen, not just that row. `asStringList` stringifies bad entries rather than dropping them, since `correctIndex` indexes into the list. `test/model_null_safety_test.dart` covers this and carries a control group; if you change the helpers, that control group is what proves the tests still mean something.
- `topics.lessonCount` is the number of published, openable Learn items, the denominator of "2 of 6 lessons" on the course index. **Zero means "not known"**, like `topicCount`. Written by the editor on every save and delete (`AdminResourceRepository.refreshLessonCount`), by `9_seed_resources.js`, and recomputed nightly by `jobs.js --job=counts`. It is the **only** topic field a client may update, and only with the `admin` claim; `verify_rules.js` asserts a student cannot. "Openable" is `LearnResource.isAvailable`, mirrored in JS in `jobs.js` and the seeder, so change all three together.
- **Resources the editor created or edited carry `createdBy` or `editedInApp`, and `9_seed_resources.js` skips them** unless run with `--force`. The seeder writes each file as the whole truth, so without this, re-seeding would wipe a YouTube link added in the editor and republish a draft.
- `subjects.topicCount` is the denominator for a subject-level progress ring. Written by the seeders, recomputed nightly by `tools/admin/jobs.js --job=counts`. **Zero means "not known", never "no topics"** — a subject seeded before the field existed reads zero until the job next runs, so callers must suppress the ring rather than draw an empty one.
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
- The suite is 296 tests, not the 2 this file used to claim. `test/generated_latex_test.dart`
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