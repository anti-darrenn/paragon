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
node fix_misclassified.js # MUST run after classify — ~15% misclassification rate
node 3_seed.js            # subject -> units -> topics -> questions into Firestore
node check_linkage.js     # verify topicId linkage after seeding
```

Each script hardcodes `const SUBJECT = '...'` near the top — **edit that constant in every script before a run**; they currently disagree with each other (`1_scrape/2_classify/3_seed` = `further-mathematics`, `fix_misclassified` = `physics`). Requires `tools/scraper/.env` (`GROQ_API_KEY`) and `tools/scraper/data/serviceAccountKey.json` (gitignored, never commit). `raw_*.json` is `{ questions: [...] }`, not a bare array; `classified_*.json` **is** a bare array.

`project/firestore.rules` and `project/firestore.indexes.json` are both tracked in the repo, and `firebase.json`'s `firestore` block points at each — `firebase deploy --only firestore:rules` and `firebase deploy --only firestore:indexes` deploy these files directly, as `.cursorrules` describes.

## Architecture

Flutter web app (Riverpod v3 + go_router v17 + Firebase v4) over a Firestore content tree seeded by Node scrapers.

**Two parallel product modes that must never merge:**

- Learning Mode — `/` → `/subject/:subjectId` → `.../unit/:unitId` → `.../topic/:topicId` (SubjectList → UnitList → TopicList → Drill). Immediate per-question feedback, attempts recorded with `source: 'drill'`.
- WAEC Prep Mode — `/waec` → `/waec/:subjectId/exam` (WaecSubjectScreen → WaecExamScreen). Full exam run, results at the end, `source: 'waec'`.

Never add WAEC questions to drill providers without filtering by `source`, and never add drill-style instant feedback to the exam flow.

**Data flow.** Screens are `ConsumerWidget`s that watch providers in `lib/core/repositories/learning_repository.dart` (`subjectsProvider`, `unitsProvider`, `topicsProvider`, `drillQuestionsProvider(topicId)`, `waecQuestionsProvider(subjectId)` — all `FutureProvider`/`.family` reading Firestore directly). Writes go through `AttemptRepository.record()` and `UserRepository.updateStreak()`. Auth/user streams live in `lib/core/providers/auth_provider.dart` (`authStateProvider`, `currentUserProvider`, `userDataProvider`, `weeklyAttemptsCountProvider`).

**Routing.** `lib/core/router/app_router.dart` is the live router: `appRouterProvider` builds the `GoRouter`, and a private `_RouterNotifier` listening to `authStateProvider` drives `refreshListenable`. The redirect gates every route except `/signin` behind auth, and returns `null` while auth is loading. Do not duplicate redirect logic elsewhere.

**Dead spec files — do not wire these in.** `lib/core/router/paragon_router.dart`, `router_redirect.dart` and `paragon_scaffold.dart` are unreferenced design sketches for a future route tree (guest mode, splash/welcome, profile shell). They assume go_router ^14 / Riverpod ^2.5 and screens that do not exist. Edit `app_router.dart` instead.

**LaTeX.** `flutter_math_fork` only — `flutter_tex` is banned and breaks builds. `FullLatexView` (`lib/core/widgets/full_latex_view.dart`) is the real renderer: a hand-written scanner over mixed text + math supporting `\(...\)`, `\[...\]`, `$...$`, `$$...$$`, `\textbf`/`\textit`/`\emph`, `\vspace`, with escape-aware delimiter matching and a red monospace fallback on parse errors. `MathText` delegates to it by default; `useLightRenderer: true` selects its own lighter inline parser. Scraped content is `\(...\)` format exclusively. Note `docs/LATEX_RENDERING.md` is stale where it claims `FullLatexView` uses `flutter_tex`/MathJax.

**Theme.** `AppColors` is the only color source — no raw `Color()` literals in widgets; `AppColors.forSubject(name)` maps subject names to their card colors. Dark theme is enforced (`ThemeMode.dark` in `app.dart`); the light theme exists but is not selectable.

## Firestore conventions

Collections: `subjects`, `units` (`subjectId`, `order`), `topics` (`subjectId`, `unitId`, `questionCount`, `order`), `questions`, `users/{uid}`, `attempts`.

- `questions.options` stores option text **without** the A/B/C/D prefix — the UI adds labels.
- `questions.correctIndex` is 0-based but is `-1` for all currently seeded questions (answers not scraped yet). Always null-check: `(data['correctIndex'] as num?)?.toInt() ?? -1`.
- `questions.subjectId` is required on every document — drill queries use `topicId`, WAEC queries use `subjectId` + `source` + `year`.
- Every `fromFirestore` must stay fully null-safe (`(d['x'] as T?) ?? fallback`).

## Riverpod v3 gotchas

`.valueOrNull` does not exist in v3.3.1 — read `AsyncValue` with `.asData?.value`. `weeklyAttemptsCountProvider` is a `StreamProvider`; keep it one. Use `StreamProvider` for Firestore streams, `FutureProvider` for one-shots, plain `Provider` for derived state.

## Commits

Conventional commits, with project-specific types/scopes from `.cursorrules`: types `feat|fix|chore|content|refactor|style|docs`; scopes `drill, waec, auth, dashboard, router, theme, models, providers, scraper, seeder, classifier, firestore, latex, android, deploy`. Example: `content(physics): seed 412 physics WAEC questions 1990-2024`.
