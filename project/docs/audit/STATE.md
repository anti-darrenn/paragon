# Project Paragon — State of the Codebase (Pass 1 Audit)

Generated 2026-09-17. Read-only pass. Source-of-truth hierarchy used throughout:
shipping code > `.cursorrules` (the real day-to-day plan) > `Spec_Current.docx` +
2.1/2.2/2.3 + `Firestore_Schema_Final.docx` (aspirational full-product intent) >
`type_specimen.docx` (visual law) > PRD v2 / Tech Stack / Execution Plan (**stale,
describes a different Next.js/Vercel product — not followed**).

Everything below is from reading the actual files in this repo on 2026-09-17
(`git log` HEAD `1c64b50`), not inferred from any document.

## Phase 0a result (recap)

`paragon_router.dart`, `router_redirect.dart`, `paragon_scaffold.dart` are **not
live source**. Commit `02de63a` (one commit before HEAD) moved them to
`paragon_plans/router_sketch_deferred/*.dart.txt` specifically because they
referenced nonexistent screens/APIs and were the cause of all 61 `flutter analyze`
errors at the time. CLAUDE.md already documents this. Every one of the 11
"known conflicts" that depends on those files is **void** — see `CONFLICTS.md`.

## Route inventory

Live router: `lib/core/router/app_router.dart:37-119`. One flat `GoRouter`, no
`StatefulShellRoute`, no shell, no bottom nav, no guest mode.

| Path | Screen | File | Status |
|---|---|---|---|
| `/welcome` | `WelcomeScreen` | `features/welcome_screen.dart` | ✅ implemented, recently rebuilt from Figma (commit `6c38a41`) |
| `/` | `SubjectListScreen` | `features/subject_list_screen.dart` | ✅ implemented |
| `/subject/:subjectId` | `UnitListScreen` | `features/unit_list_screen.dart` | ✅ implemented |
| `/subject/:subjectId/unit/:unitId` | `TopicListScreen` | `features/topic_list_screen.dart` | ✅ implemented |
| `/subject/:subjectId/unit/:unitId/topic/:topicId` | `DrillScreen` | `features/drill_screen.dart` | ✅ implemented, but ends by `Navigator.pop()` — no score summary screen (`.cursorrules:436`, explicitly deferred) |
| `/waec` | `WaecSubjectScreen` | `features/waec_subject_screen.dart` | ✅ implemented |
| `/waec/:subjectId/exam` | `WaecExamScreen` | `features/waec_exam_screen.dart` | ⚠️ implemented but **never writes to Firestore** — see below |
| `/dashboard` | `DashboardScreen` | `features/dashboard_screen.dart` | ✅ implemented; accuracy-by-topic section is an explicit, labeled placeholder (`dashboard_screen.dart:123-131`) |
| `/signin` | `SignInScreen` | `features/sign_in_screen.dart` | ✅ implemented, recently rebuilt as multi-step email flow (commit `6c38a41`, tap-recognizer disposal fixed in `1c64b50`) |
| `/about` | `AboutScreen` | `features/about_screen.dart` | Stub only — `.cursorrules:440` confirms this is intentional ("About screen content — placeholder only") |

No dead routes, no missing screens, no duplicate declarations. Every route resolves.

Routes that exist **only in the spec docs**, not in code: all of `/onboarding/*`,
`/exam/setup`, `/exam/active`, `/exam/results/:examId`, `/exam/review/:examId`,
`/exam/history`, `/profile*`, `/home`, `/units/*`, `/topics/*`, `/learn/*`,
`/sign-in-email`, `/splash`. These are Phase-3+ session targets per
`.cursorrules:484-494` (Sessions 9–16), not a current bug.

## Data layer inventory

**Repositories** (`lib/core/repositories/`):
- `LearningRepository` (`learning_repository.dart`) — `subjectsProvider`,
  `unitsProvider(subjectId)`, `topicsProvider(unitId)`,
  `drillQuestionsProvider(topicId)`, `waecQuestionsProvider(subjectId)`. All
  `FutureProvider`/`.family`, direct Firestore reads, no caching layer beyond
  Riverpod's default keep-alive.
- `AttemptRepository.record()` (`attempt_repository.dart:8-27`) — writes one
  document to `attempts` per question: `userId, questionId, topicId, subjectId,
  selectedIndex, isCorrect, source, timestamp`. Called only from
  `DrillScreen._submit` (`drill_screen.dart:34-44`) with `source: 'drill'`.
  **Never called from `WaecExamScreen`** — WAEC attempts are not recorded anywhere.
- `UserRepository` (`user_repository.dart`) — `createUserIfNew()` seeds
  `uid, email, displayName, createdAt, currentStreak, lastActiveDate`.
  `updateStreak()` does plain device-local-time date-string comparison, no
  timezone handling, no Cloud Function, no transaction.

**Models** (`lib/core/models/`) — `Subject`, `Unit`, `Topic`, `Question`. All use
non-null-safe casts (`d['name'] as String`, `d['text'] as String`, etc.) with no
`?? fallback` on required fields — this **violates CLAUDE.md's own stated rule**
("Every `fromFirestore` must stay fully null-safe"). Currently safe in practice
only because `tools/scraper/3_seed.js:145-150` always populates these fields.

**Actual Firestore field names** (from `3_seed.js:145-150`, cross-checked against
the model classes): `text`, `options`, `correctIndex`, `explanation`, `topicId`,
`subjectId`. These do **not** match `Firestore_Schema_Final.docx`'s
`questionText`/`workedSolution` naming — see `CONFLICTS.md`.

**Firestore rules** (`project/firestore.rules`) — 7 match blocks: `subjects`
(public read), `units`/`topics`/`questions` (any authenticated read),
`users/{uid}` (owner read/write, unrestricted field-level access),
`attempts/{id}` (create/read scoped to own `userId`, no update/delete rule so
both are implicitly denied), `usernames/{normalised}` (create-once, immutable).
This is a real file, actively deployed via `firebase.json`'s
`"firestore": {"rules": "firestore.rules"}` block — **CLAUDE.md is stale on this
point** (see `CONFLICTS.md`). No `firestore.indexes.json`, no `functions/`
directory anywhere in the repo — zero Cloud Functions exist.

## Feature completeness vs. `.cursorrules` session plan

`.cursorrules:472-494` is the actual roadmap (last updated "as of Session 7";
git history shows Session 8 has since shipped, plus unlabeled Figma-rebuild work
on sign-in/welcome — the session tracker itself is now behind, see `CONFLICTS.md`).

| Session | Scope | State |
|---|---|---|
| 1–7 | Scaffold, auth, 3-level data model, LaTeX, Mathematics seeded | ✅ Done |
| 8 | Physics + Further Maths seeded | ✅ Done (commit `ba54814`) |
| — | Sign-in/welcome Figma rebuild | ✅ Done, unplanned/out-of-sequence (commits `f240dcd`…`1c64b50`) |
| 9 | Learn mode (video + notes) | ❌ Not started — no `/learn/*` route, no video/notes fields wired |
| 10 | Proper exam mode (config, lockdown) | ❌ Not started — current WAEC screen is a fixed-question-set MVP with no config, no lockdown, no persistence |
| 11 | User profiles | ❌ Not started — no `/profile` route |
| 12 | Course tracking (accuracy by topic) | ❌ Not started — Dashboard's accuracy section is a static placeholder |
| 13 | Gamification (XP, streak freeze, achievements) | ❌ Not started — no XP field, no achievements collection |
| 14 | Android build | ❌ Not started — `google_sign_in` mobile wiring deferred per `.cursorrules:437` |
| 15–18 | Polish, About, performance, content expansion | ❌ Not started |

## Quality gates (run 2026-09-17)

- `flutter analyze` → **0 issues**.
- `flutter test` → **2/2 pass** (`widget_test.dart` smoke test, `latex_render_test.dart` light-parser unit test). No tests for `AttemptRepository`, `UserRepository.updateStreak`, router redirect logic, or drill/WAEC flows.
- `dart format --set-exit-if-changed lib test` → **fails; 24 of 29 files unformatted**. `dart format` has apparently never been run on this codebase (the two most recently Figma-rebuilt files, `sign_in_screen.dart` and `welcome_screen.dart`, are the only ones already conformant).
- `grep -rniE "TODO|FIXME|HACK|placeholder|hardcod"` → 19 hits, all in `lib/`, all either cosmetic (`PlaceholderAlignment` enum, `_PlaceholderAccuracyChart` class name) or explicitly-labeled, intentional deferrals with inline rationale (`welcome_screen.dart:288,323,327,416`). No unlabeled hacks, no secrets, no dead-man landmines found.

## Blunt summary

This is a genuinely small, clean MVP — 10 routes, ~15 screens/widgets, a flat
6-collection Firestore schema, zero Cloud Functions, zero build errors, passing
tests, no stray hacks — that implements roughly Sessions 1–8 of an 18-session plan.
It is **not** the guest-mode/dual-shell/XP/leaderboard/onboarding-funnel product
described in `Spec_Current.docx`, `Firestore_Schema_Final.docx`, or 2.1/2.2/2.3 —
those describe the Session 9–18 destination, not the current app, and `.cursorrules`
already says so. The one real functional gap that isn't already tracked as
"deferred" is that **WAEC exam results are computed in memory and never persisted**
— no `attempts` write, no history, nothing survives leaving the screen — which
contradicts CLAUDE.md's own claim that WAEC attempts are recorded with
`source: 'waec'`. Shippable-for-Learning-Mode-only, today, to a small trusted
group; not shippable as the product the docs describe.
