# Project Paragon — Prioritized Backlog (Pass 1 Audit)

Rubric: P0 broken for users/data loss/security. P1 blocks the next shippable
slice. P2 spec drift. P3 polish. Ordered by (impact ÷ hours) within each
priority. "One-way door" = hard/costly to reverse later.

**Re-ranking rule, applied to every deferred item below:** is this *absent
functionality*, or *live breakage in something already shipped*? A roadmap
session number is not a severity rating. Absent functionality stays on the
existing session/phase plan. Live breakage in shipped code is P0/P1
regardless of which future session it happened to get filed under.

## What this pass changed, and why

- **`waecQuestionsProvider` had no `.limit()`** — every WAEC exam loaded the
  subject's entire bank (Physics 1769, Mathematics 1716, Further Maths 801).
  This was noted as a caveat inside item #1 during the persistence fix, then
  implicitly filed under "Session 10 — Proper exam mode — configurable
  settings, lockdown" — i.e. treated as absent functionality. Wrong: the
  *configuration UI* (year range, timer, count slider) is legitimately
  absent and belongs in Session 10; the *uncapped load* is a defect in code
  that ships today, independent of whether that UI ever exists. **Fixed this
  session** — capped to 40, randomized pivot year, no new index needed. Made
  worse by an interaction I should have caught at the time: the WAEC
  persistence fix (same session, earlier) turned the pre-existing read
  problem into a write-amplification problem too, since an uncapped exam
  also means an uncapped number of Firestore writes on submit.
- **`weeklyAttemptsCountProvider`'s missing index moves from "cheap win" to
  P0.** DashboardScreen is shipped and live; its "This week" stat is
  permanently stuck (reproduced: the query throws `FAILED_PRECONDITION`).
  That's live breakage in shipped code, not hygiene. Code is done; only a
  human running `firebase login --reauth` then
  `firebase deploy --only firestore:indexes` is left — see item #0.
- **New finding: `drillQuestionsProvider` has the identical defect**, smaller
  magnitude. See item #1a.
- **Pattern check on the rest of the roadmap:** see below. Verdict: not an
  isolated misranking — the same shape (unbounded Firestore query in a
  shipped, actively-used screen) recurs, laundered into "future work" by two
  different mechanisms. Everything else deferred in this codebase really is
  absent functionality, not disguised breakage — see the full pass at the
  bottom of this file.

## P0 — broken for users, data loss, or security

### 0. `weeklyAttemptsCountProvider` — permanently broken, missing index
- **Evidence:** `lib/core/providers/auth_provider.dart:46-59` queries
  `attempts` filtered by `userId` (equality) and `timestamp` (range) with no
  composite index for that combination. Reproduced directly: an Admin SDK
  query with the same shape throws
  `FAILED_PRECONDITION: The query requires an index`. `.cursorrules:448-449`
  already documented this as known; it was never actually fixed.
- **Why it matters to a student:** the Dashboard's "This week" stat shows
  "—" forever for every user, always — not a loading flash, a permanent
  dead stat on a screen every signed-in user sees.
- **Status:** code-complete, deploy-blocked. `project/firestore.indexes.json`
  declares the index and `firebase.json` wires it in (done in `chore: audit
  hygiene fixes`). `firebase deploy --only firestore:indexes` fails with a
  `401` from stale Firebase CLI auth that needs an interactive
  `firebase login --reauth` — I can't complete this myself.
- **Estimate:** 5 minutes, human-only (`firebase login --reauth`, then
  `firebase deploy --only firestore:indexes` from `project/`).
- **One-way door:** No.

## P1 — blocks the next shippable slice

### 1. WAEC exam results are never persisted — done
- Fixed: `8b355cc`, refactored in `c3b5cf1`. Kept here as the historical
  record; see `attempt_repository.dart`/`waec_exam_screen.dart`.

### 1a. `drillQuestionsProvider` has no cap either
- **Evidence:** `lib/core/repositories/learning_repository.dart:49-59` —
  same unbounded-query shape as the WAEC provider had: no `.limit()`, loads
  every question for a topic. Spec §2.2.7 explicitly specifies a 20-question
  cap for drill sessions ("If more than 20: cap at 20 per session") — the
  app doesn't do this.
- **Why it matters:** DrillScreen is shipped and actively used today, not
  future work. Sampled topics run 10–66+ questions per topic (five sampled
  live: 10, 14, 22, 48, 66) — smaller blast radius than WAEC's hundreds, but
  the same defect class, and the spec already specifies the exact number to
  cap at.
- **Estimate:** 15–20 minutes — same pattern as the WAEC fix, but simpler
  (no year field to rotate on; a topic's questions have no natural ordering
  to bias against, so a plain `.limit(20)` plus a shuffle of the returned
  batch is enough — no random-pivot trick needed).
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
- **Re-ranking check:** latent risk, not live breakage — no user is hitting
  this today. Stays P2.
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
  same document with these same rules unless it's revisited first.
- **Re-ranking check:** latent design risk, not live breakage — nothing is
  currently exploited. Stays P2.
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
- ~~Cap `waecQuestionsProvider`~~ — done this session; moved to P0 write-up
  above rather than staying here, since it turned out to be live breakage,
  not hygiene.

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
  `questions.explanation`, which is empty for all 4,286 seeded questions.
  Add it back once `explanation` has real content; don't build an empty
  accordion in the meantime.
- **No real video embedding** — no `youtube_player`/`webview_flutter`
  dependency added, since no topic has a `videoId` to point one at. Add the
  package and the field together, when video content actually exists.
- **Re-ranking check on all four:** absent functionality — no video/notes/
  explanation data exists anywhere to be broken. Correctly stay deferred.

## Full re-ranking pass — everything else on the roadmap

Checked against the live-breakage-vs-absent-functionality test; all confirmed
**absent functionality, correctly deferred, no reclassification**:
`4_scrape_answers.js` (answers never scraped), DrillScreen score summary
(pops instead of showing a summary — missing feature, not corruption or a
crash), Google Sign-In on Android, `com.example.paragon` org name, question
image support in `FullLatexView`, About screen content, offline/PWA support,
AI-generated explanations, gamification/XP (Session 13 — and see item #3
above for the design work that should land *with* it, not after), user
profiles, onboarding funnel, guest mode, iOS build, Chemistry/Economics/
Biology content (Session 18), App Store listing (Session 19).

One roadmap-level pattern worth naming rather than an individual item:
**Session 17 ("Performance — bundle size, 3G load time, offline
persistence") reads the same way the WAEC cap did** — a generic future
bucket that could quietly absorb specific, already-identifiable defects
(items #1a above, and the two unbounded WAEC/Drill queries generally) under
"we haven't done perf work yet," when at least two of them are already
live breakage today, not future polish. Treat Session 17 as "whatever
performance work is left after the known live breakage is fixed," not as
the place #0 or #1a belong.

Also checked and *not* reclassified: `subjectsProvider`/`unitsProvider`/
`topicsProvider` (`learning_repository.dart`) are unbounded too, but at
current data scale (single digits to low tens of documents per query)
aren't a live performance problem — noted for awareness, not filed as a
defect.
