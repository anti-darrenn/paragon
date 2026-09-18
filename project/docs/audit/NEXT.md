# Project Paragon — Prioritized Backlog (Pass 1 Audit)

Rubric: P0 broken for users/data loss/security. P1 blocks the next shippable
slice. P2 spec drift. P3 polish. Ordered by (impact ÷ hours) within each
priority. "One-way door" = hard/costly to reverse later.

## P1 — blocks the next shippable slice

### 1. WAEC exam results are never persisted
- **Evidence:** `lib/features/waec_exam_screen.dart:35-44` (`_submitExam`) computes
  score purely in local `State`. Nothing in the file calls
  `AttemptRepository.record()` or writes to Firestore. Compare
  `drill_screen.dart:34-44`, which does call it with `source: 'drill'`.
- **Why it matters to a student:** a student sits a full timed-feeling WAEC
  practice set, gets a score, and the moment they leave the screen it's gone —
  no history, no accuracy tracking, nothing to show for the session. It also
  silently contradicts CLAUDE.md's documented architecture ("attempts recorded
  with `source: 'waec'`"), so anyone building on top of this later will assume
  data exists that doesn't.
- **Estimate:** 1–2 hours (loop over answered questions, call
  `AttemptRepository.record(..., source: 'waec')` per question on submit —
  the same call `DrillScreen` already makes; no new repository code needed).
- **One-way door:** No.

## P2 — spec drift / latent risk, worth fixing before it bites

### 2. Firestore model classes are not null-safe
- **Evidence:** `question.dart:26-39`, `subject.dart:14-21`, `unit.dart:16-24`,
  `topic.dart:20-30` all do direct non-nullable casts (`d['text'] as String`,
  `d['name'] as String`, `List<String>.from(d['options'] as List)`) with no
  fallback.
- **Why it matters:** CLAUDE.md states this exact rule ("Every `fromFirestore`
  must stay fully null-safe") and it's currently violated everywhere. Safe today
  only because the seeder always populates these fields — but the classifier
  has a documented ~15% misclassification rate and content editing happens by
  hand in the Firebase Console, so a missing field is a realistic future event,
  and when it happens the failure mode is a hard crash on the whole screen, not
  a graceful gap.
- **Estimate:** 30–45 minutes across the four files.
- **One-way door:** No.

### 3. `users/{uid}` write access is unrestricted at the field level
- **Evidence:** `project/firestore.rules:10-12` — `allow read, write: if
  request.auth != null && request.auth.uid == uid;` with no field restrictions.
  `Firestore_Schema_Final.docx`'s entire security model assumes `currentStreak`,
  `totalXP`, `level`, etc. are Cloud-Function-only once they exist.
- **Why it matters:** today, a user can only inflate their own `currentStreak` —
  low stakes with no leaderboard or rewards tied to it yet. But Session 13
  (Gamification, per `.cursorrules:489`) will add XP/achievements on top of this
  same document with these same rules unless it's revisited first. Flagging now
  so the Session 13 estimate includes rules work, not just feature work.
- **Estimate:** No code change needed now; ~1 hour of design work before Session
  13 starts (decide which fields move to Cloud-Function-only rules).
- **One-way door:** No.

## P3 — polish / hygiene

### 7. `docs/LATEX_RENDERING.md` describes a renderer the app doesn't use
- **Evidence:** doc describes `flutter_tex`/MathJax; `pubspec.yaml` has no
  `flutter_tex` dependency; the real renderer is `flutter_math_fork` via
  `FullLatexView`. CLAUDE.md already flags this as stale — the doc itself hasn't
  been fixed.
- **Estimate:** 15–20 minutes to rewrite to match `FullLatexView`'s actual
  scanner-based implementation, or delete it if not worth maintaining.

### 9. Retire three stale strategy docs
- **Evidence:** see `CONFLICTS.md` section B — `Project_Paragon_PRD_v2.md`,
  `Paragon_Tech_Stack_and_Platform_Strategy.md`,
  `Project_Paragon_Execution_Plan.md` all describe a Next.js/Vercel product
  that was never built.
- **Estimate:** 10 minutes to move them to an `archive/` folder with a note, or
  delete outright.

## Cheap wins (under 30 minutes each — do these in one sitting)

- ~~Run `dart format lib test` and commit~~ — done (`91421cf`, `544f8c0`).
- ~~Fix CLAUDE.md's Firestore-rules claim~~ — done (`chore: audit hygiene fixes`).
- ~~Update `.cursorrules` §12 header~~ — done (`chore: audit hygiene fixes`).
- ~~Fix `SignInScreen`'s generic error message~~ — done, both `_submitPassword`
  and `_sendPasswordReset` (`chore: audit hygiene fixes`).
- ~~Clean the stray `// ✅ CORRECT` comment at `app_router.dart:90`~~ — done
  (`chore: audit hygiene fixes`).
- **Missing Firestore composite index for `weeklyAttemptsCountProvider` —
  partially done.** `project/firestore.indexes.json` now declares the
  `attempts` (`userId` ASC + `timestamp` ASC) index and `firebase.json` wires
  it in, but the actual `firebase deploy --only firestore:indexes` failed:
  the CLI's cached login is stale (`401` on `serviceusage.googleapis.com`
  even though `firebase login:list` shows a logged-in account). Needs a human
  to run `firebase login --reauth` (interactive OAuth) and then
  `firebase deploy --only firestore:indexes` from `project/` — until that
  runs, the index is declared in the repo but not live, and
  `weeklyAttemptsCountProvider` will keep failing exactly as before.

## Session 9 follow-ups (Learn mode shell shipped; these were deliberately deferred)

- **No content-authoring path for `Topic.hasNotes`/`notesMarkdown`.** Nothing
  in `tools/scraper` or Firebase Console workflow sets these — the fields
  exist on the model and render correctly if populated, but there's no script
  or admin UI to populate them. Needs its own small session (or a one-off
  script) once actual notes copy exists to author.
- **`FullLatexView` doesn't render real Markdown**, only LaTeX delimiters plus
  `\textbf`/`\textit`/`\emph`/`\vspace`. If `notesMarkdown` content ever uses
  headings or bullet lists, they'll render as literal text, not structure.
  Fine for now (no notes exist), but flag before anyone authors notes with
  real Markdown syntax expecting it to render.
- **Worked Examples section (spec §2.2.6) omitted entirely** — depends on
  `questions.explanation`, which is empty for all 4,286 seeded questions (see
  item #1's sibling finding). Add it back once `explanation` has real content;
  don't build an empty accordion in the meantime.
- **No real video embedding** — no `youtube_player`/`webview_flutter`
  dependency added, since no topic has a `videoId` to point one at. Add the
  package and the field together, when video content actually exists.

## Explicitly not on this list (already tracked, not new findings)

Proper exam config/lockdown, user profiles, gamification/XP, onboarding
funnel, guest mode, Android build, Chemistry/Economics/Biology content — all
correctly deferred per `.cursorrules:430-495` (Sessions 10-18). Re-auditing
these would just restate the existing roadmap.
