# Project Paragon — Conflicts (Pass 1 Audit)

Every item below was checked against the live file, not assumed. Confidence tags
per the brief.

## A. Your 11 "known conflicts" — verified

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | Duplicate shell paths (`/home`, `/dashboard`, `/exam/setup`, `/profile` in two `StatefulShellRoute`s) | **Void [high]** | `router_redirect.dart`/`paragon_scaffold.dart` are not in `lib/` (moved to `paragon_plans/router_sketch_deferred/*.txt` by commit `02de63a`). Live `app_router.dart:37-119` has one flat route list, no `StatefulShellRoute` at all. |
| 2 | Guest mode defined two incompatible ways | **Void [high]** | No guest implementation exists in code at all. `welcome_screen.dart:288-289` has an explicit `TODO(design)` stating guest was deliberately omitted this pass. `Firestore_Schema_Final.docx` describes Anonymous Auth guest mode as pure intent (Session 9+ territory, not scheduled in `.cursorrules`). |
| 3 | Redirect breaks on query strings | **Void [high]** | The dead file did this; the live redirect (`app_router.dart:44-64`) compares `state.matchedLocation` (path only) against `/signin`/`/welcome`, a different and much simpler implementation not vulnerable to the described bug. |
| 4 | `_checkSubjects` stub always returns true | **Void [high]** | Symbol does not exist anywhere in `lib/` (`grep -r "_checkSubjects" lib/` → 0 hits). |
| 5 | Nav visibility contradicts §2.3.2 | **Void [high]** | No scaffold/shell/nav-bar widget exists anywhere in the live app to have a visibility rule at all. |
| 6 | Routes specified but absent (`/exam/review/:examId`, `/exam/history`, `/onboarding/*`, `/profile`) | **Confirmed [high], not from the dead files** | These are genuinely absent from `app_router.dart`'s 10-route list. This is real spec-vs-code drift, but it's tracked, not a bug: `.cursorrules:484-494` schedules onboarding/profile/proper-exam-mode as Sessions 10-11, still to come. |
| 7 | Version drift (router header claims go_router ^14/Riverpod ^2.5; tech-stack doc says ^13; Spec says v17/3.3.1) | **Partially void, partially confirmed [high]** | The "router header" claim was inside the dead `router_redirect.dart` — void. Live `pubspec.lock` resolves `go_router: 17.2.3`, `flutter_riverpod: 3.3.1` — matching `Spec_Current.docx` and `.cursorrules:3`, contradicting `Paragon_Tech_Stack_and_Platform_Strategy.md:70` (`^13.0.0`) and PRD v2 (implicitly, via its Next.js stack). The doc-vs-doc drift here is real; see section B. |
| 8 | `PopScope.onPopInvoked` deprecated API; `canPop: false` swallowing pops | **Void [high]** | Zero matches for `PopScope`, `onPopInvoked`, `canPop` anywhere in `lib/`. No shell exists to swallow pops from depth-4/5 screens. |
| 9 | Typography conflict (PRD v2: Montserrat vs type_specimen/app: Space Grotesk); off-grid spacing | **Confirmed [high]** | `app_theme.dart:15,40,58-116` uses `GoogleFonts.spaceGroteskTextTheme`/`GoogleFonts.spaceGrotesk` exclusively. `Project_Paragon_PRD_v2.md:105` says Montserrat — PRD v2 is simply wrong/stale here. Off-grid spacing: not audited line-by-line in this pass; `dashboard_screen.dart` and `waec_exam_screen.dart` use several non-8px values (e.g. `18`, `14`, `10`, `22`) — flag for a follow-up design-QA pass, not confirmed as a violation of intent since these predate the Figma rebuild. |
| 10 | Schema conflict (PRD v2 flat `attempts/{uid}_{questionId}` + `topicAccuracy` vs Schema-Final's `topicStats`/XP/leaderboards) | **Confirmed [high], and both are aspirational** | `AttemptRepository.record()` (`attempt_repository.dart:8-27`) writes auto-ID docs to a flat `attempts` collection with `{userId, questionId, topicId, subjectId, selectedIndex, isCorrect, source, timestamp}` — matching **neither** doc. No `topicAccuracy`, no `topicStats`, no XP field, no leaderboard collection, no Cloud Function anywhere in the repo. |
| 11 | Scope conflict (Maths/Physics/Further Maths seeded vs PRD v2's "Mathematics only") | **Confirmed [high]** | `Project_Paragon_PRD_v2.md:66`: "Start with Mathematics only." Actual: Mathematics (1716), Physics (~400-600), Further Maths (~300-400) all seeded per `.cursorrules:456-459` and commit `ba54814`. PRD v2 is stale; `.cursorrules` is the real scope authority. |

## B. Doc-vs-doc conflicts not in your list

- **Stack identity, not just versions.** PRD v2 and `Project_Paragon_Execution_Plan.md` describe a **Next.js + Vercel + Tailwind + static-JSON** product (`PRD_v2.md:177,178,186,100`; `Execution_Plan.md:114,116`). The shipping app is Flutter + Firebase + Firestore. This isn't version drift, it's a different product on a different stack — these two documents describe something that was never built and, per `.cursorrules`, never will be. **[high]**
- **`google_fonts` version.** `Spec_Current.docx:38` pins `google_fonts: ^6.2.1`; `Paragon_Tech_Stack_and_Platform_Strategy.md:78` pins `^6.1.0`; live `pubspec.yaml:43` uses `^8.1.0` (resolved `8.1.0`). Both docs are stale. **[high]**
- **`.cursorrules` session tracker is itself stale.** §12 (`.cursorrules:472-482`) says "current as of Session 7, Session 8 is next." Git history (`ba54814`) shows Session 8 already shipped, plus a further, unplanned Figma-rebuild pass on sign-in/welcome (commits `f240dcd` through `1c64b50`) that doesn't map to any numbered session. `.cursorrules` is the most-trusted doc in this repo and it's already one dated section behind reality. **[high]**

## C. Doc-vs-code conflicts found in this pass, not on your list

- **CLAUDE.md claims no Firestore rules file exists** ("There are no Firestore rules/indexes files in the repo — `firebase.json` only configures hosting"). False as of commit `f240dcd`: `project/firestore.rules` exists and `project/firebase.json` has a `"firestore": {"rules": "firestore.rules"}` block. CLAUDE.md was written in commit `02de63a`, one commit before `f240dcd` added the rules file — it's simply out of date. **[high]**
- **`docs/LATEX_RENDERING.md` claims `FullLatexView` uses `flutter_tex`/MathJax.** `pubspec.yaml` has no `flutter_tex` dependency at all, and CLAUDE.md itself already flags this doc as stale, correctly. Confirmed: `flutter_math_fork` is the only LaTeX package present. **[high]**
- **`Firestore_Schema_Final.docx` field names don't match what's actually seeded/read.** Doc specifies `questionText` and `workedSolution`; the seeder (`3_seed.js:145-150`) and `Question.fromFirestore` (`question.dart:26-39`) both use `text` and `explanation`. This is intent-vs-reality, not a bug — the code is internally consistent — but anyone implementing against the schema doc literally will write a broken query. **[high]**
- **CLAUDE.md's routing description overstates WAEC persistence.** CLAUDE.md says WAEC attempts are "recorded with `source: 'waec'`." `WaecExamScreen._submitExam` (`waec_exam_screen.dart:35-44`) computes score entirely in memory and never calls `AttemptRepository.record()` or writes anything to Firestore. No WAEC attempt has ever been persisted by this screen. **[high]** — see `NEXT.md` P1.

## Recommended resolutions

| Artifact | Recommendation |
|---|---|
| CLAUDE.md | Fix the Firestore-rules claim (§ "Commands"/architecture section). One-line edit. |
| `docs/LATEX_RENDERING.md` | Already correctly flagged stale by CLAUDE.md; rewrite or delete — it currently misdescribes the only LaTeX renderer in the app. |
| `.cursorrules` §12 | Update the session-tracker header from "current as of Session 7" to reflect Session 8 + the sign-in/welcome rebuild, so the next session doesn't inherit a stale "what's done" picture. |
| `Project_Paragon_PRD_v2.md` | **Retire.** Describes a different stack (Next.js/Vercel/Tailwind), different scope (Mathematics-only), different font (Montserrat), different schema (`topicAccuracy`). Nothing in it reflects the shipping app. Keep only as historical record if desired, but stop treating it as a stack/scope reference. |
| `Paragon_Tech_Stack_and_Platform_Strategy.md` | **Retire.** Pins `go_router ^13`, `google_fonts ^6.1.0`, describes the Next.js stack — same problem as PRD v2. |
| `Project_Paragon_Execution_Plan.md` | **Retire.** Sequencing ("no code until 10 videos ship") and stack (Next.js/Vercel) both contradict reality; `.cursorrules`'s session plan has already superseded it. |
| `Firestore_Schema_Final.docx` / `Spec_Current.docx` / 2.1 / 2.2 / 2.3 | **Keep as Phase-3+ target/intent**, but stop treating any of it as "what exists." Consider adding a one-line header to each noting "target state for Sessions 9-18+; see `.cursorrules` for what's actually built." |
| `type_specimen.docx` | Keep as visual law — confirmed the app actually follows it (Space Grotesk, dark palette, orange/violet accents all match). |

**Documents to retire:** `Project_Paragon_PRD_v2.md`, `Paragon_Tech_Stack_and_Platform_Strategy.md`, `Project_Paragon_Execution_Plan.md`. All three describe a product on a different stack that was never built and, per the currently-trusted `.cursorrules`, isn't planned to be.

> **Done (2026-09-20).** All three moved to `paragon_plans/archive/`, with a README naming what to read instead. Archived rather than deleted — they record why some early decisions were made, and the citations throughout this file still need to resolve. The filenames above are unchanged; only the directory moved.
