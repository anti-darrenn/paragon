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

### 0. `weeklyAttemptsCountProvider` — missing index — done
- Fixed: `firebase deploy --only firestore:indexes` deployed the composite
  index (`userId` ASC + `timestamp` ASC, already declared in
  `firestore.indexes.json`) — the earlier `401` had resolved on its own by
  the time this was retried, no reauth needed. Confirmed live: the exact
  query shape (`attempts` filtered by `userId` equality + `timestamp`
  range) that previously threw `FAILED_PRECONDITION` now succeeds. Kept
  here as the historical record.

### 0b. Guest sign-in was blocked — done
- Anonymous Auth was disabled in the Firebase Console (confirmed
  independently via a direct Identity Toolkit REST call before any app code
  was touched); enabled by the user. Two real bugs then surfaced during the
  live re-verification and were fixed in the same session, not deferred:
  `UserRepository.createUserIfNew` never wrote an `isAnonymous` field
  (`user_repository.dart`), and the router's own guest-permissive redirect
  (added this session) left a *freshly* signed-in guest stranded on
  `/welcome` instead of landing on home — fixed by having
  `_handleGuestSignIn` (`welcome_screen.dart`) navigate to `/` explicitly
  rather than relying on the redirect. Full guest walkthrough then
  live-verified end to end, including a 10-question guest exam whose
  attempts round-tripped to Firestore with `source: 'waec'` and the guest's
  UID. Kept here as the historical record; see `.cursorrules` §12 for the
  full verification detail.
- **New, deliberately not fixed:** signing out and browsing as guest again
  issues a brand-new anonymous UID; the previous guest's `users/{uid}` doc
  and attempts stay in Firestore, permanently orphaned with no UI path back
  to them. This is the expected consequence of no account-linking existing
  yet (see the Session 10 follow-ups section below) — noted as a real
  observed behavior, not filed as its own defect, since building
  account-linking is already tracked there.

## P1 — blocks the next shippable slice

### 1. WAEC exam results are never persisted — done
- Fixed: `8b355cc`, refactored in `c3b5cf1`. Kept here as the historical
  record; see `attempt_repository.dart`/`waec_exam_screen.dart`.

### 1a. `drillQuestionsProvider` has no cap either — done
- Fixed in `b416bea` (capped to 20 with a random document-id cursor and
  wraparound, per spec §2.2.7). This entry sat open for three commits after
  the fix had already shipped — worth noting as a process miss, not a code
  one.

### 1b. Every question was unanswerable — done
- **What it was:** all 4,286 questions had `correctIndex: null` and an empty
  `explanation`. Drill marked every submitted answer red and never showed a
  correct option; every exam scored `0 / N (0%)` / "Below pass mark"; every
  attempt ever written was `isCorrect: false`. The Dashboard's hardcoded
  accuracy placeholder masked it.
- **Why it outranked everything else here:** live breakage in shipped code,
  and it made the product actively wrong rather than merely incomplete. It
  also blocked Session 12 (accuracy over a 100%-false corpus) and Session 13
  (XP for nothing verifiable).
- **Fixed:** scraped answers + worked explanations from the original source
  and backfilled 4,254 of 4,286 (99.3%) with `correctIndex`, `explanation`,
  `sourceId` and `hasAnswer`. Verified in-browser: correct answers render
  green, wrong picks red alongside the green correct one, explanations
  render as formatted LaTeX, a 10-question exam scored 10/10 "Pass", and
  attempts wrote `isCorrect: true`.
- **Residue, tracked below:** the key is not authoritative (~4% source error
  rate), and 32 questions remain unanswered and filtered out.

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

## Session 10 follow-ups (setup screen + lockdown + guest auth shipped; these were deliberately deferred)

- **No account-linking on guest upgrade.** Tapping a sign-in entry point
  while anonymous starts a fresh real-account session; it does not call
  `linkWithCredential` to preserve the anonymous UID's data. Spec §2.1.10
  ("guest state is discarded on upgrade in Phase 1") and §2.3.11
  (`linkWithCredential` preserves it) contradict each other — resolved here
  by choosing the simpler, no-linking interpretation and stating the choice
  rather than silently picking one. Revisit if/when an Auth Upsell Sheet is
  built, since a guest could plausibly answer several practice questions
  worth preserving before upgrading.
- **Guest gating only applied to WAEC.** Dashboard, Drill, and Profile
  screens have no anonymous-auth-aware restrictions — a guest can currently
  reach all of them exactly as a real user would (Drill has no source-level
  guest lock at all; Dashboard/Profile weren't in this session's scope).
  Not a regression — just genuinely unbuilt, since the session was scoped to
  "setup screen and exam lockdown only."
- **No `sessions/{examId}` collection or results/review/history routes.**
  `/exam/results`, `/exam/review/:examId`, `/exam/history` from the spec
  don't exist. The existing in-memory `_ResultsView` (pre-dates this
  session) still just re-opens the live exam state when "Review Answers" is
  tapped — no correct/incorrect marking, no lock against re-answering, no
  persistence of the review state across a page reload. Live-verified this
  session; confirmed unchanged from before, not a Session 10 regression.
- **No mid-exam persistence/resume.** A page reload or crash mid-exam loses
  all progress — `shared_preferences` isn't even a dependency yet. Spec
  implies resumability; not attempted this session (setup + lockdown scope
  only).
- **No question flagging.** Not attempted — no UI, no Firestore field for it.
- **`setState` + `Timer.periodic` instead of `StateNotifier`.** Spec's
  literal wording implies a `StateNotifier`-based timer; this session used
  a plain `Timer.periodic` inside the widget's `State` instead — simpler,
  works, matches how the rest of this codebase's screens are built, but is
  a deliberate deviation from the spec's letter, noted rather than silently
  diverged from.
- **Re-ranking check on all six:** absent functionality within a
  deliberately scoped session, or (for the `StateNotifier` point) a stated
  implementation-approach deviation — not live breakage. Correctly stay
  deferred. The guest-sign-in-itself bug (and the `isAnonymous`-field and
  post-sign-in-navigation bugs found alongside it) *was* live breakage in
  what shipped, not absent scope — filed and closed as P0 item #0b above,
  not here.

## Answer-key follow-ups (backfill shipped; these are the known residue)

- **The answer key has a measured ~4% error rate and is not authoritative.**
  Hand-verifying 60 answers from the oldest years found 2 wrong at source
  (a conditional-probability question marked 8/19 where 4/7 is correct, and
  a "which is singular" question marking the identity matrix). The source
  describes its own answers as AI-assisted. Mitigation shipped: students can
  report a problem, writing to `flags`. **Query `flags` periodically** —
  nothing in the app reads it, and `reason == 'wrong_answer'` is the signal
  for which questions to re-check. This is the intended feedback loop, so it
  only works if someone actually looks.
- **32 questions have no verified answer** and are excluded from drill and
  WAEC by `hasAnswer`. 11 were text misses (6 of those near-identical to a
  source question, i.e. our stored text is slightly corrupt), 10 option
  mismatches, 7 with no correct option marked at source, 2 conflicting, 1
  ambiguous, 1 with multiple correct. Recoverable by hand if ever worth it;
  not worth it at 0.7%.
- **~700 questions depend on a diagram the app cannot show.** The scrape
  flagged image-bearing questions (506 maths, 196 physics, 17 further maths
  among matched). They now have correct answers but remain unanswerable on
  their own terms, since question image support is still deferred. This is a
  bigger content-quality problem than the 32 excluded ones and is currently
  invisible — `hasImage` was captured in the scrape output but not stored on
  the question documents, so the app cannot filter or label them.
- **Physics explanations are thin** — 1,023 of 1,762 matched (58%), versus
  92% and 94% for maths and further maths.
- **Historical attempts predating the backfill are all `isCorrect: false`**
  (29 documents, all test data). Not worth migrating, but any lifetime
  accuracy metric should either window to post-backfill timestamps or
  recompute by joining `questionId` against `questions.correctIndex`.

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
