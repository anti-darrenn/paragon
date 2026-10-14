# Paragon — Fix & Differentiate Plan

> **For Claude Code.** This plan comes from a review of the live site (`paragon-hq.web.app`, Flutter web on Firebase Hosting) on 13 Oct 2026. The reviewer had **not** seen the codebase. Every file path, collection name or class name below is a *guess to confirm*, not a fact. Phase 0 exists to replace guesses with facts.
>
> **Content is being written separately.** This plan does not ask you to write lessons, explanations or questions. It asks you to build the structure, flags, tooling and UI so content can drop in cleanly and so nothing unfinished reaches students.
>
> **Reconciled 2026-10-14.** The audit is in [`project/docs/REPO_FACTS.md`](project/docs/REPO_FACTS.md). It records which items already existed, which were adapted to the Spark plan, and which were declined, with reasons. The work runs as waves A–K, one PR each: A = Phases 0+1, B = 2, C = 3, D = 4, E = 5, F = 6, G = 7.2 + the weekly goal, H = live rooms, I = 7.1/7.3–7.6, J = 8 + trust/legal, K = launch QA.

---

## How to run this plan

1. Put this file at the repo root as `PLAN.md`.
2. Start each Claude Code session with: *"Read PLAN.md. Do Phase N only. Use plan mode first, show me the plan, then implement."*
3. **One phase per session.** One commit per task, message prefixed with the task ID (e.g. `P1.2: add question source field`). *(Adapted: conventional commits per CLAUDE.md, with the task id in the subject.)*
4. **Never deploy to the live site without asking.** Use Firebase preview channels (`firebase hosting:channel:deploy <name>`) for every phase and share the preview URL.
5. **Never delete or bulk-edit production Firestore data without asking.** Write migration scripts that run as a dry run by default (`--dry-run` prints what would change; `--apply` changes it). Back up first (`gcloud firestore export`).
6. When a task says **VERIFY**, stop and ask Moyo rather than guessing.
7. At the end of each phase, tick the checkboxes in this file and add a short "Done notes" line under the phase.

### Priority key
- **P0** — hurts trust today. Fix before showing Paragon to anyone new.
- **P1** — blocks growth (findability, speed, accessibility).
- **P2** — differentiation features.

---

## What the review found (the "why")

| # | Finding | Evidence on live site |
|---|---|---|
| F1 | Placeholder content is live | Maths → Indices shows two lessons titled `test2` and `test_article`. Only 2 of 43 Maths topics have lessons. |
| F2 | Question counts imply more WAEC questions than exist | Maths topics claim 300–420 questions each (14,616 total). WAEC Prep says 485 Maths questions for 2015–2024. Meta description says "Practise WAEC past questions". |
| F3 | Counts disagree between screens | Welcome ticker: Mathematics 14,602. Course page: 14,616. |
| F4 | Guest mode contradicts itself | Banner says guest progress is kept in the browser, but topic drills show "Drill needs an account". 4 of 5 WAEC Prep subjects are locked for guests. |
| F5 | Guest session doesn't seem to persist | After browsing as guest, loading `/` again landed on `#/welcome`. Reproduce before fixing. |
| F6 | No deep links | URL stays `#/courses` inside a subject and a topic. Direct navigation to `#/waec` while not in a session showed only "Back / Create an account". |
| F7 | Nothing indexable by Google | Flutter canvas rendering; fetching `/` returns only meta tags. |
| F8 | Heavy first load | `main.dart.js` ≈ 1.07 MB compressed (4.9 MB decoded) plus CanvasKit; ~20 KaTeX font files requested at startup; `paragon_logo.png` 144 KB. |
| F9 | Accessibility gaps | Welcome screen exposes no semantics labels. Math is dropped from the accessible text (`If F = 9/5 C + 32` reads as `If F = C + 32`). Small low-contrast footer text. |
| F10 | Exam defaults may not match WAEC | Default 40 questions; real paper length/time to be verified. |
| F11 | Generic positioning | Tagline "Learning the right way." Feature set matches every competitor. |

What's already good (don't break it): year tags on questions ("WAEC 2018"), KaTeX rendering via `flutter_math_fork`, the in-exam tools sheet (calculator, four-figure tables, scratchpad), the estimated grade on review, the mistakes notebook, the mobile layout.

---

## Phase 0 — Audit the repo (no code changes)

Goal: produce `docs/REPO_FACTS.md` so every later phase uses real names.

- [x] **P0.0.1** Map the project. Record in `docs/REPO_FACTS.md`:
  - Flutter and Dart versions (`flutter --version`, `pubspec.yaml` constraints).
  - State management (Riverpod / Provider / Bloc / setState).
  - Router (`go_router`? `Navigator 1.0`? `auto_route`?) and the file defining routes.
  - Firebase packages and versions (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_analytics`, etc).
  - Where the JavaScript part of the stack lives and what it does (Cloud Functions? build scripts? admin tools?).
  - `firebase.json` contents (hosting rewrites, headers, functions, emulators).
  - Firestore security rules file and what each rule allows.
  - Build/deploy commands actually used (look for scripts, Makefile, GitHub Actions, README).
- [x] **P0.0.2** Map the data model. For each Firestore collection: name, document shape (fields + types), who writes it, approximate count. At minimum find: subjects, modules, topics, lessons/articles, videos, questions, exam papers, user progress, mistakes, review cards. Write a sample document (with real field names, fake values) for each.
- [x] **P0.0.3** Answer these questions with evidence (file + line or query result):
  1. Where do the per-topic question counts (e.g. "351 questions") come from? Stored field, computed client-side, or aggregate query?
  2. Where does the welcome-screen ticker number come from? Why does it differ from the course page (14,602 vs 14,616)?
  3. Where do the ~14,000 Maths topic questions come from that aren't in the 485 WAEC 2015–2024 set? Is there any field recording source, year, paper, or generator? **Do not guess — if no field exists, say so.**
  4. How is guest state stored (localStorage? `shared_preferences`? Firebase anonymous auth?) and why might the welcome screen show again on reload?
  5. Which features are gated behind sign-in, and where is that check implemented? Is it one function or scattered?
  6. Are there other placeholder/test documents? Query lessons, articles, videos and questions for titles/bodies matching `/test|lorem|todo|placeholder|asdf|xxx|sample/i` and list them (IDs only, do not delete).
- [x] **P0.0.4** Run the app locally and with the Firestore emulator if configured. Record what works and what doesn't.
- [x] **P0.0.5** List anything in this plan that conflicts with what you found, and propose corrections. **Stop and wait for Moyo.**

Done notes: `project/docs/REPO_FACTS.md`. The stack and the data model were already
documented in `CLAUDE.md`, so that file links there rather than duplicating them. The
conflicts were resolved with the owner on 2026-10-14:
- generated questions are shown as "Paragon practice";
- the guest table is adopted;
- the app stays at `/`;
- one PR per wave.

There is no emulator, because this machine has no Java. `verify_rules.js` is the live
check.

---

## Phase 1 — Trust fixes (P0)

### P1.1 Publishing workflow: drafts never reach students (F1)

- [x] **P1.1.1** Add a `status` field to every content document type (lessons/articles, videos, and any future theory solutions): `draft | review | published`. Add `publishedAt` (timestamp) and `updatedAt`. *(Existed: `draft | in_review | changes_requested | published`.)*
- [x] **P1.1.2** Migration script `scripts/migrate_content_status`. *(Existed: `jobs.js --job=resourcestatus`, run 2026-09-24.)*
- [x] **P1.1.3** Every student-facing query filters `status == 'published'`. *(Existed, and verified in the audit.)*
- [x] **P1.1.4** Firestore rules: clients can read content only where `resource.data.status == 'published'`, unless staff. *(Existed: `isWriter()`/`isReviewer()`, `set_role.js`, `verify_rules.js`.)*
- [x] **P1.1.5** Topic page empty state: "Lessons for this topic are on the way. You can still practise now." plus the practise button. Never "0 of 0 lessons".
- [x] **P1.1.6** Pre-publish lint. `checkPublishable` blocks publishing in the editor, and a reviewer can override with a reason that is kept as a comment. `tools/admin/content_lint.js` lints what is live, read-only, and exits non-zero. CI arrives in Wave F.

**Acceptance:** On a preview channel, Maths → Indices shows no `test2`/`test_article`. A signed-in non-admin reading a draft by ID gets permission denied (prove with an emulator rules test). Lint exits non-zero on a seeded placeholder doc.

### P1.2 Question provenance (F2)

- [x] **P1.2.1** Provenance fields. *(Adapted: the existing `source`, `year` and `origin` are read by `Question.provenanceLabel`; no migration.)*
- [x] **P1.2.2** Classification report. *(`jobs.js --job=counts` dry run: Mathematics 1,702 past / 12,900 practice, Physics 1,762 / 19,200, Further Mathematics 790 / 6,300, Chemistry 0 / 13,800, Government 0 / 12,600.)*
- [x] **P1.2.3** A badge on every question: "WAEC 2018" or "Paragon practice". It appears in drill, the WAEC exam and its review, and the mistakes notebook.
- [x] **P1.2.4** Topic cards show split counts: "51 past · 300 practice", leaving out a side with none.
- [x] **P1.2.5** Copy: the meta, OG and splash text say "past questions" only where they exist. WAEC subjects with none say "No past questions yet".

### P1.3 One source of truth for counts (F3)

- [x] **P1.3.1–P1.3.3** *(Adapted, since Spark has no Cloud Functions.)* `jobs.js --job=counts` writes every topic's total, past and practice counts, and each subject's as the sum of its topics. Every surface reads `QuestionCounts`. `tools/admin/check_counts.js` asserts that they agree.

### P1.4 Guest mode that's honest and keeps progress (F4, F5)

- [x] **P1.4.1** Anonymous auth for guests. *(Existed.)*
- [x] **P1.4.2** Link instead of replace. *(Existed. The merge function is declined on Spark.)*
- [x] **P1.4.3** Persisted guests skip the welcome screen (fixes F5).
- [x] **P1.4.4** A single gating function: `canUse(Feature, isGuest)` in `lib/core/auth/feature_access.dart`.
- [x] **P1.4.5** The guest banner tells the truth, and the 30-day claim is backed by `jobs.js --job=guests`.
- [x] **P1.4.6** Sign-up prompts appear after a drill ("Save your 8/10") and after a WAEC result.

### P1.5 "Coming soon" subjects

- [x] **P1.5.1** "Notify me" on coming-soon courses stores `waitlist/{uid}` (accounts only). The studio shows the count per subject.

Done notes (Wave A, PR `feat/trust-fixes`):
- **Owner steps.** Deploy the rules, then run `verify_rules.js`; it has four new waitlist
  denials. Run `node tools/admin/jobs.js --job=counts --apply`, then `check_counts.js`.
  Unpublish `test2` and `test_article` in the studio.
- **Guest table rows changed.** Exam history and offline packs stay open to guests, who
  already had them. Unit tests follow the drill row.
- **Waitlist emails.** There is no email to waitlisted students yet. Resend's shared
  sender can't reach them until `NOTIFY_FROM` is set.

---

## Phase 2 — Routing and deep links (P1)

### P2.1 Real URLs for every screen (F6)

- [x] **P2.1.1** If not already, move to `go_router` (keep it if present). Define routes with slugs. *(Adapted: ids stay in app routes; see REPO_FACTS.)*
- [x] **P2.1.2** Switch to path URLs: `usePathUrlStrategy()` in `main()` (from `flutter_web_plugins`). Remove `#`.
- [x] **P2.1.3** Redirect old hash URLs: in `web/index.html`, before Flutter loads, if `location.hash` starts with `#/`, `history.replaceState` to the path equivalent.
- [x] **P2.1.4** Auth-aware redirects in `go_router.redirect`: deep link to a gated page while signed out → `/welcome?next=<path>`, then return to `next` after sign-in or "Browse as guest".
- [x] **P2.1.5** Browser back/forward works everywhere; leaving an in-progress exam asks for confirmation (`PopScope` + `onbeforeunload` via `dart:js_interop`).
- [x] **P2.1.6** Share button on questions and topics copies the path URL.

**Acceptance:** Paste `/courses/mathematics/indices` into a fresh tab → topic page loads (after auth flow if needed). Back button returns to Mathematics. Old `#/courses` links redirect.

Done notes (Wave B, PR `feat/deep-links`):
- Path URLs and old hash links rewritten.
- `push` updates the URL.
- `/welcome?next=` survives sign-in, onboarding and "Browse as guest", and is validated
  against open redirects.
- "Leave site?" during a WAEC exam or a topic test.
- Share on topic and course pages.

Routes keep Firestore ids, not slugs. The static question pages (Phase 3) carry their own
URLs, so there is no in-app `/q/:id` route.

Verified by unit tests and a release web build. Locally the hosting emulator served deep
paths with 200. The browser click-through is still to do: the extension wasn't
connected.

---

## Phase 3 — Findability: static landing + indexable question pages (P1)

*(Adapted by the owner: the app stays at `/`. Static `/past-questions/**`, `sitemap.xml` and `robots.txt` are added beside it.)*

- [x] **P3.1** Site structure (no `/app` move; cache headers for static pages and assets).
- [x] **P3.2** Landing: improve the `index.html` splash and `<noscript>` with honest counts and a link to `/past-questions/`.
- [x] **P3.3.1** `tools/site/build_static_site.js`: past-question pages with server-rendered KaTeX, "Show answer", JSON-LD `Quiz`, and a CTA into the app.
- [x] **P3.3.2** `sitemap.xml` and `robots.txt`.
- [x] **P3.3.3** Build step in the deploy recipe (and CI, Wave F).
- [ ] **P3.3.4** Submit sitemap in Google Search Console (owner).

**Acceptance:** `curl` of a question page returns full question text in HTML. Lighthouse SEO score ≥ 95 on landing and a question page. Rich Results Test accepts the Quiz markup.

Done notes (Wave C, PR `feat/static-site`):
- **Output.** 4,254 past questions in three subjects, at
  `/past-questions/waec/<subject>/<year>/<id>/`, plus year, topic, subject and index
  pages. 4,473 URLs are in `sitemap.xml`. Each page carries KaTeX with MathML, which
  screen readers can read, and JSON-LD `Quiz`. A question page is about 8.5 KB of HTML.
- **Checked.** Under the local hosting emulator, the question, topic and year pages
  returned 200 with their own titles; `/x` 301s to `/x/`; app routes still reach Flutter.
- **Not yet run.** Lighthouse and the Rich Results Test need a browser and the deployed
  URL; they are owner checks, along with P3.3.4 (Search Console).
- **Known data problem.** Some past questions still carry a wrong `topicId`; see the
  CLAUDE.md classification notes. The topic pages and "Practise <topic>" buttons repeat
  it publicly, so re-running reclassification matters more now.
- **Spark Hosting** allows 360 MB a day of transfer. At about 40 KB a first visit to a
  question page, that is roughly 9,000 visits a day.

---

## Phase 4 — Performance on Nigerian mobile data (P1)

- [ ] **P4.1** Baseline: Lighthouse (mobile, "Slow 4G") for `/` and a question page; record in `docs/audit/PERF.md`.
- [x] **P4.2** Logo and OG image re-encoded at display size.
- [x] **P4.3** KaTeX fonts: grep the corpus for families never used and stop shipping them, if a browser shows they are fetched at startup.
- [x] **P4.4** Deferred loading. *(Declined: `PERF.md` measured about 50 KB.)*
- [x] **P4.5** `--wasm`. *(Declined: about 5%, with a second render path.)*
- [x] **P4.6** Remove unused packages.
- [x] **P4.7** Firestore reads: no full loads to count. *(Done in P1.3.)*
- [x] **P4.8** Skeleton cards instead of lone spinners on course pages.
- [x] **P4.9** Budget recorded in PERF.md.

Done notes (Wave D, PR `feat/perf`): the first visit is about 250 KB lighter and makes 9
fewer requests.
- KaTeX font trim, from 21 files to 12, saves 140 KB gzipped.
- The logo drops from 149 KB to 42 KB.
- The OG image is now a 50 KB JPEG.
- The unused `google_sign_in` is removed.
- Skeletons replace the bare spinners on the course pages.

Numbers are in `project/docs/audit/PERF.md`. **P4.1 (Lighthouse) is still open**; it
needs a browser on the preview. The PLAN's 30% target isn't reachable without
wasm or a renderer change, both measured and declined.

---

## Phase 5 — Accessibility and exam UX polish (P1)

- [x] **P5.1.1** Welcome screen controls are real buttons with names.
- [x] **P5.1.2** Maths gets spoken labels from `speakText` (the read-aloud converter), with 30+ tests on real strings.
- [x] **P5.1.3** A question stem is one semantics node.
- [x] **P5.1.4** Contrast: `onLow` raised to AA in both themes.
- [x] **P5.1.5** Tap targets ≥ 48 dp (exam strip).
- [x] **P5.2.1** **VERIFY** WASSCE formats with Moyo → `lib/core/exam/exam_formats.dart`, "Real exam" preset.
- [x] **P5.2.2** Keyboard: A–E, ←/→, F, Enter.
- [x] **P5.2.3** Flag for review plus a pre-submit summary.
- [x] **P5.2.4** Autosave and resume, kept on the device. *(Adapted: Spark write quota.)*
- [x] **P5.2.5** Offline tolerance during an exam.

Done notes (Wave E, PR `feat/a11y-exam`):
- **Maths is spoken.** A stem with maths is one node whose label is the read-aloud
  words ("If F = nine fifths C plus 32…"). The tests cover 30+ real stems.
- **Light renderer.** It no longer shows raw `\textbf`.
- **Welcome links** are real buttons. The ticker is one label and stops under reduced
  motion.
- **Contrast.** `onLow` was raised to AA in both themes; a test computes the ratios for
  every text tone, with the old value as its control.
- **Exam.** The question strip has 48 dp targets and speaks each question's state.
  Options are buttons that announce whether they are selected. There are keyboard keys,
  flags and a pre-submit summary.
- **Autosave and resume** are on the device (Spark), with the questions stored so a
  resume works offline. P5.2.5 is covered by that: the questions are already preloaded
  at the start, and nothing is written until submit.
- **P5.2.1 is answered provisionally.** `exam_formats.dart` holds the commonly published
  lengths, marked `verified: false`, and the screen says "not yet checked". **Moyo:
  please confirm them.** The 2026 CBT screen layout is unknown.

Not yet done: a real screen-reader run (NVDA or TalkBack). The semantics tree is
asserted in tests, which is not the same thing.

---

## Phase 6 — Engineering foundations

- [x] **P6.1** Rules tests with the emulator, in CI only.
- [x] **P6.2** Widget tests for the empty state, badges, guest table and exam presets *(partly done in Wave A)*, plus the integration test.
- [x] **P6.3** GitHub Actions on PRs: analyze, test, lint and build, plus a preview channel once the owner adds the secret.
- [x] **P6.4** Funnel analytics events (`waitlist_join` done in Wave A).
- [x] **P6.5** Sentry. *(Declined: `ErrorReporter` exists.)*
- [x] **P6.6** Emulator seed data, in-test.

Done notes (Wave F, PR `feat/foundations`):
- **CI** (`.github/workflows/ci.yml`) runs on every PR:
  - analyze, test and the release build, with the plugin-registrant check;
  - the post-build step;
  - the Node script tests;
  - the rules emulator suite (`tools/rules-test`, about 30 cases with seeded fixtures);
  - read-only live checks (`content_lint`, `check_counts`);
  - a preview channel. It needs Hosting Admin on the service account; until then it
    fails without blocking.
- **Funnel events** `guest_start`, `signup_start`, `signup_complete{method}`, `topic_open`,
  `drill_start` and `exam_start{preset}`, plus `waitlist_join` from Wave A, are described
  in the privacy policy.
- **Not done:**
  - **Sentry**: declined; `ErrorReporter` covers it.
  - **The integration test** (guest → drill → reload) is still to do: it needs a browser
    driver and a Firebase project to sign in to. `guest_landing_test` covers the redirect
    half.
  - **Lighthouse CI**: declined; the numbers are recorded in PERF.md instead.

---

## Phase 7 — Differentiation (P2)

- [ ] **P7.1** Examiner insights (`insights/{questionId}`, reviewer-written, hidden when absent).
- [x] **P7.2** Topic weights, predicted grade range, shortest-path plan, exam countdown. *(No streak: removed by decision. The weekly goal replaces it.)*
  - *Done in Wave G (PR `feat/plan`).*
    - **Weights** come from each topic's share of real past questions, with no new job:
      `pastQuestionCount` already exists. Where there are none, all topics weigh the
      same, and the screen says so.
    - **Grade estimate** comes from practice. It is a range until 50 answers and is
      labelled an estimate, objective questions only. The PLAN's grade bands match
      `waec_grade.dart`.
    - **Shortest path** is the top 3 by weight × (1 − mastery), with topics a week to
      the exam.
    - **`plan/{uid}`** stores only the goal and the date.
    - **Home's "This week" card** replaces the duplicate weekly tile for accounts.
    - **Also shipped:** the guest **5-question taster** (`/try`) and **Challenge a
      friend** (`/c/:id`, a WhatsApp share, played as a guest, recorded as
      `challenge_link`, never in `progress`).
    - **Not done:** the exam-date onboarding step (the "This week" card prompts for it
      instead), and push reminders (they would need FCM web push and a consent flow,
      not worth it before launch).
- [ ] **P7.3** Real-exam (CBT) mode after P5.2.1 is answered.
- [ ] **P7.4** Theory (Paper 2) structure, hidden until 20+ questions.
- [ ] **P7.5** Contributor bylines.
- [ ] **P7.6** The studio exists. Add an insight editor and question validation in `content_lint.js`.
- [ ] **P7.7** Teachers and schools. *(Deferred: safeguarding for minors, needs a server.)*
- [ ] **P7.8** Offline packs. *(Exists: "Save for offline".)*

Done notes:

---

## Phase 8 — Copy and brand pass (needs Moyo's input)

- [ ] **P8.1** Five tagline options in `docs/COPY.md`.
- [ ] **P8.2** l10n/ARB. *(Deferred: no second language planned.)*
- [ ] **P8.3** About: where questions come from (partly exists).

Done notes:

---

## Open questions for Moyo (answer before the phases that need them)

1. ~~Phase 1: Hide `unverified` questions, or show them as "Practice question"?~~ Shown as "Paragon practice" (2026-10-14).
2. ~~Phase 1: Approve the guest policy table in P1.4.4?~~ Adopted (2026-10-14).
3. Phase 5/7: Real WASSCE paper formats per subject, and anything known about the 2026 CBT screen?
4. Phase 7: Confirm the positioning line and the grade bands. *(The bands already in `waec_grade.dart` match the plan's: A1 ≥ 75 … F9 < 40.)*
5. ~~Phase 7.6: Admin console inside the app or as a separate small web app?~~ It already exists inside the app (`/admin`).
6. Who has Google Search Console / Firebase owner access to submit the sitemap and approve live deploys?
