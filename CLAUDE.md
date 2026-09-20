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

Content pipeline (`project/tools/scraper`, Node CommonJS, no npm scripts — invoke files directly):

```powershell
node 1_scrape.js          # myschool.ng -> data/raw_<subject>.json
node 2_classify.js        # Groq llama-3.1-8b-instant -> data/classified_<subject>.json
node fix_misclassified.js # MUST run after classify — see the note below on misclassification
node 3_seed.js            # subject -> units -> topics -> questions into Firestore
node check_linkage.js     # verify topicId linkage after seeding
```

Each script hardcodes `const SUBJECT = '...'` near the top — **edit that constant in every script before a run**; they currently disagree with each other (`1_scrape/2_classify/3_seed` = `further-mathematics`, `fix_misclassified` = `physics`). Requires `tools/scraper/.env` (`GROQ_API_KEY`) and `tools/scraper/data/serviceAccountKey.json` (gitignored, never commit). `raw_*.json` is `{ questions: [...] }`, not a bare array; `classified_*.json` **is** a bare array.

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

**Never use `3_seed.js` on a subject that already exists** — it always creates a fresh
subject document and would duplicate it. That is the whole reason `6_seed_generated.js`
exists.

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

`project/firestore.rules` and `project/firestore.indexes.json` are both tracked in the repo, and `firebase.json`'s `firestore` block points at each — `firebase deploy --only firestore:rules` and `firebase deploy --only firestore:indexes` deploy these files directly, as `.cursorrules` describes.

## Architecture

Flutter web app (Riverpod v3 + go_router v17 + Firebase v4) over a Firestore content tree seeded by Node scrapers.

**Two parallel product modes that must never merge:**

- Learning Mode — `/` → `/subject/:subjectId` → `.../unit/:unitId` → `.../topic/:topicId` (SubjectList → UnitList → TopicList → Drill). Immediate per-question feedback, attempts recorded with `source: 'drill'`.
- WAEC Prep Mode — `/waec` → `/waec/:subjectId/exam` (WaecSubjectScreen → WaecExamScreen). Full exam run, results at the end, `source: 'waec'`.

Never add WAEC questions to drill providers without filtering by `source`, and never add drill-style instant feedback to the exam flow.

**Progress and mastery.** `lib/core/progress/mastery.dart` is the pure model —
`MasteryLevel` (notStarted/attempted/familiar/proficient/mastered), the thresholds,
and the roll-up maths. Per-topic progress is a **level**, not a percentage, and only
module/course aggregates become percentages; `course_progress.dart` joins a `Course`
outline to a student's counters. `MasteryCircle`/`MasteryRing`
(`lib/core/widgets/mastery_indicator.dart`) are the only things that draw them.

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

**Data flow.** Screens are `ConsumerWidget`s that watch providers in `lib/core/repositories/learning_repository.dart` (`subjectsProvider`, `unitsProvider`, `topicsProvider`, `drillQuestionsProvider(topicId)`, `waecQuestionsProvider(subjectId)` — all `FutureProvider`/`.family` reading Firestore directly). Writes go through `AttemptRepository.record()` and `UserRepository.updateStreak()`. Auth/user streams live in `lib/core/providers/auth_provider.dart` (`authStateProvider`, `currentUserProvider`, `userDataProvider`, `weeklyAttemptsCountProvider`).

**Routing.** `lib/core/router/app_router.dart` is the live router: `appRouterProvider` builds the `GoRouter`, and a private `_RouterNotifier` listening to `authStateProvider` drives `refreshListenable`. The redirect gates every route except `/signin` behind auth, and returns `null` while auth is loading. Do not duplicate redirect logic elsewhere.

**Dead spec files — do not wire these in.** `lib/core/router/paragon_router.dart`, `router_redirect.dart` and `paragon_scaffold.dart` are unreferenced design sketches for a future route tree (guest mode, splash/welcome, profile shell). They assume go_router ^14 / Riverpod ^2.5 and screens that do not exist. Edit `app_router.dart` instead.

**LaTeX.** `flutter_math_fork` only — `flutter_tex` is banned and breaks builds. `FullLatexView` (`lib/core/widgets/full_latex_view.dart`) is the real renderer: a hand-written scanner over mixed text + math supporting `\(...\)`, `\[...\]`, `$$...$$`, `\textbf`, `\textit`, `\vspace{Ncm}`, with a red monospace fallback on parse errors. `MathText` delegates to it by default; `useLightRenderer: true` selects its own lighter inline parser — the two must agree, since they are chosen by a flag on the same widget.

`\emph` is **not** supported (use `\textit`), and a lone `$` is a literal dollar sign, **not** an inline-math delimiter. Inline math is `\(...\)` — the format the scrapers and all 216 generator modules emit. `$...$` was removed because every `$` in the corpus is currency and none is math, and treating it as a delimiter parsed the text between two prices as an expression. See `docs/LATEX_RENDERING.md`, which is now accurate.

**Theme.** `AppColors` is the only color source — no raw `Color()` literals in widgets; `AppColors.forSubject(name)` maps subject names to their card colors. Dark theme is enforced (`ThemeMode.dark` in `app.dart`); the light theme exists but is not selectable.

## Firestore conventions

Collections: `subjects`, `units` (`subjectId`, `order`), `topics` (`subjectId`, `unitId`, `questionCount`, `order`), `questions`, `users/{uid}`, `attempts`, `flags`, `usernames/{key}`, `progress/{uid}`.

- `questions.options` stores option text **without** the A/B/C/D prefix — the UI adds labels.
- `questions.correctIndex` is 0-based. It is `-1` on the **scraped** corpus (answers were never scraped) and a real index on the **generated** corpus, so both cases are live in production at once — never assume either. `-1` is the app's "no verified answer" value and is the required fallback; a `0` fallback silently marks option A correct.
- `questions.subjectId` is required on every document — drill queries use `topicId`, WAEC queries use `subjectId` + `source` + `year`.
- Every `fromFirestore` must stay fully null-safe, and does so via the helpers in `lib/core/models/firestore_parsing.dart` (`docData`, `asString`, `asInt`/`asIntOrNull`, `asBool`, `asStringList`) — use those rather than writing fresh casts. They coerce instead of throwing, because these run inside provider mapping: a throw on one document takes down the whole screen, not just that row. `asStringList` stringifies bad entries rather than dropping them, since `correctIndex` indexes into the list. `test/model_null_safety_test.dart` covers this and carries a control group; if you change the helpers, that control group is what proves the tests still mean something.
- `progress/{uid}` is one document per student: `{userId, updatedAt, topics: {<topicId>: {answered, correct, subjectId}}}`. Owner-only in both directions, closed top-level field set, `updatedAt` pinned to the `serverTimestamp()` sentinel. The `subjectId` stamp is what lets the dashboard group by subject without loading any course outlines.
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
- The suite is 125 tests, not the 2 this file used to claim. `test/generated_latex_test.dart`
  is the one with real reach: it parses every LaTeX expression in the generated corpus
  through the actual flutter_math_fork parser and renders a sample through FullLatexView.
  It carries a deliberate control case, so if you change it, keep that — without it the
  suite passes no matter how broken the content is. Still: a green suite is not evidence
  that content is *correct*, only that it parses and renders.
- Client-writable `users/{uid}` streak/xp/topicStats is a hard blocker on any leaderboard or
  gamification work. Do not ship those sessions until writes are server-controlled. The
  `progress/{uid}` mastery cache does not change this and is not an exception to it —
  it is private, display-only, and recomputable from `attempts`. The moment anything
  competitive reads it, that read is the bug.
- Onboarding must not ask for data nothing uses. `selectedSubjects` sat unread for
  everything except one sort order; the optional `profile` map (school, class, age,
  gender, country, state) still has **no reader anywhere in `lib/`**. Either give a
  field a consumer or stop collecting it — this is data about minors.
- If a screen tells a student they can change something later, there must be a route
  that lets them. `/settings/subjects` exists because onboarding had been saying so
  since it shipped.

  - Content correctness is a defect class, not a content task. Before shipping any feature that
  reads a field, verify the field actually has values in production data — not that the code
  reads it correctly.