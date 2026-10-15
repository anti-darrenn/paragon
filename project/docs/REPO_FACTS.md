# Repo facts for PLAN.md (Phase 0)

PLAN.md was written from the live site without seeing the code, so its file, collection
and class names were guesses. This file records what the code actually does, with
evidence, so later phases use real names. For the stack, schema and conventions, read
`../../CLAUDE.md`, the authoritative and current description. That covers Flutter 3.47,
Riverpod 3, go_router 18, Firebase v4 on the Spark plan, Node admin and scraper tools,
and no Cloud Functions.

Audited 2026-10-14 on `feat/launch-safety` (PR #29).

## The findings, checked against the code

| # | Finding | What the code does |
|---|---|---|
| F1 | `test2` and `test_article` live | Student queries already filter `status == 'published'` (`learn_repository.dart:44`), so the two items really were published. They are in Mathematics topic `sGeqO2FDw79otnkz3tz6`, which `content_lint.js` confirms. Nothing checked titles before publishing. |
| F2 | 300–420 "questions" per topic | `topics.questionCount` counted every question: 300 generated (`origin: 'ai_generated'`, `source: 'drill'`) plus scraped past questions (`source: 'waec'`, with a `year`). Mathematics holds 1,702 past and 12,900 practice questions. WAEC Prep's 485 is the 2015–2024 slice of the past questions. |
| F3 | 14,602 vs 14,616 | The welcome ticker reads `subjects.questionCount`, which counts only `hasAnswer: true` and is recounted nightly. The course page summed `topics.questionCount`, which was written at seed time with no `hasAnswer` filter and never recounted. |
| F4 | Guest wording contradicts itself | The copy lived in `guest_limits.dart` and the drill refusal in `drillAccessFor`. The topic page still offered drill to guests, and the WAEC Maths-only lock was applied only on the subject list. |
| F5 | Reload shows welcome | `initialLocation: '/welcome'`, plus a redirect that lets guests stay on welcome. |
| F6 | No deep links | Hash URL strategy. `context.push` does not update the address bar (go_router default). A signed-out redirect drops the target, and routes use Firestore ids. |
| F7 | Not indexable | There is no robots.txt, sitemap or static HTML; `index.html` has OG tags and a plain-HTML splash. |
| F8 | Heavy first load | `docs/audit/PERF.md`: about 3.5 MB gzipped, engine-bound. The logo is 149 KB, and about 20 KaTeX TTFs are in `FontManifest`. |
| F9 | Accessibility | `FullLatexView` has no `Semantics`. `speakText` (read aloud) can label maths. The exam options are bare `GestureDetector`s, and `onLow` text fails AA. |
| F10 | Exam defaults | 40 questions in 60 minutes, set in `waec_exam_setup_screen.dart:31-44`. There is no preset, keyboard support, flagging or autosave. |
| F11 | Positioning | A copy decision for the owner (Wave J). |

## The P0.0.3 questions

1. **Per-topic counts.** Stored fields. `topics.questionCount`, `pastQuestionCount` and
   `practiceQuestionCount` are written by `tools/admin/jobs.js --job=counts` from
   `count()` aggregates. Before 2026-10-14 the only field was `questionCount`, written by
   the seeders.
2. **The ticker.** `subjects.questionCount` and its split, written by the same job as the
   sum of the subject's topics. `tools/admin/check_counts.js` asserts that they agree.
3. **Where the extra Mathematics questions come from.** `tools/scraper/gen/` generates
   them; every one carries `origin: 'ai_generated'`. Past questions carry
   `source: 'waec'` and a `year`. There is no `paper` or `questionNumber` field.
4. **Guest state.** Firebase anonymous auth, persisted by the browser. Attempts, `progress`
   and `learn` are stored under the anonymous uid. Notes, cards and lesson ticks are kept
   on the device. Linking an account keeps all of it (`guest_upgrade.dart`).
5. **Gating.** It was scattered across the router, `GuestLimits`, `drillAccessFor` and
   inline `isGuestProvider` checks. It is now one table, `canUse` in
   `lib/core/auth/feature_access.dart`. The router still decides signed-out access.
6. **Other placeholders.** `node tools/admin/content_lint.js` checks every published Learn
   item, read-only. On 2026-10-14 it found only `test2` and `test_article`.

## PLAN.md against reality

| PLAN item | Status | Why |
|---|---|---|
| P1.1.1–1.1.4 status field, published-only queries, rules, claims scripts | **Exists** | `topics/{id}/resources` with `draft → in_review → published`, the rules, `verify_rules.js`, `set_role.js`. Questions are Admin-SDK-only writes. |
| P1.2.1 new provenance fields | **Adapted** | `source`, `year` and `origin` already carry the facts, so `Question.provenanceLabel` reads them instead of adding fields. |
| P1.2.3 hide `unverified` | **Decided** | Generated questions are shown as "Paragon practice" (owner, 2026-10-14). |
| P1.3 `stats` collection plus Cloud Function | **Adapted** | Spark has no Functions. The counts live on the topic and subject documents, kept by the nightly `jobs.js`. |
| P1.4.2 `mergeGuestProgress` function | **Declined** | Spark. Linking already keeps a guest's progress; merging into an existing account stays unsupported. |
| P1.4.4 guest table | **Adopted**, two rows changed | Exam history and offline saving already worked for guests, so they stay open. |
| P2.1.1 slugs in URLs | **Adapted** (Wave B) | App routes keep ids; the static pages use slugs. |
| P3.1 app moved to `/app` | **Declined** (owner) | The app stays at `/`, and `/past-questions/**` is added beside it. |
| P4.4 / P4.5 deferred imports, wasm | **Declined** | `PERF.md` measured about 50 KB and about 5%. |
| P5.2.4 autosave to Firestore | **Adapted** (Wave E) | It saves to the device instead; a write per answer is unaffordable on Spark. |
| P6.1 emulator rules tests | **Adapted** (Wave F) | They run in CI only (this machine has no Java), with `verify_rules.js` kept. |
| P6.5 Sentry | **Declined** | `ErrorReporter` already reports through Analytics, with no new vendor. |
| P7.2.2 EWMA mastery | **Adapted** (Wave G) | It reuses `MasteryLevel`. |
| P7.2.6 streak | **Declined** | Streaks were removed by decision; the weekly goal replaces them. |
| P7.7 teachers and classes | **Deferred** | It needs safeguarding work for minors and a server. |
| P8.2 l10n/ARB | **Deferred** | Large churn, with no second language planned. |
