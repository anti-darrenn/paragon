# Paragon architecture

This is the whole system in one document: what Paragon is, every service it touches, how the
code is laid out, how a request moves through it, what is stored where and who may write it,
what runs on a schedule, how content gets in, and how it ships. It is written so that a new
engineer, or a new Claude session, can work on any part of the project from this file alone.

- **Companion files.**
  - `CLAUDE.md` at the git root is the *rulebook*: conventions, invariants and the reasons
    behind them. Where the two overlap, this file explains the shape and CLAUDE.md gives the
    rule.
  - `docs/LAUNCH_CHECKLIST.md` is the owner's to-do list.
  - `PLAN.md` at the git root records each review finding and what was built for it.
- **Paths.** Unless a path says otherwise, it is relative to `project/`, the Flutter app.
  The git root is one level up.
- **Last updated.** 2026-10-16, at `main` = merge of PR #49. PR #50 (the donate card) is
  described where it applies.

---

## Contents

1. [What Paragon is](#1-what-paragon-is)
2. [System map and every external service](#2-system-map-and-every-external-service)
3. [Repository layout](#3-repository-layout)
4. [The app at runtime](#4-the-app-at-runtime)
5. [Routing, the redirect pipeline and every route](#5-routing-the-redirect-pipeline-and-every-route)
6. [Product areas, feature by feature](#6-product-areas-feature-by-feature)
7. [The content studio](#7-the-content-studio)
8. [Data model: every Firestore collection](#8-data-model-every-firestore-collection)
9. [Security model](#9-security-model)
10. [Server-side work without Cloud Functions](#10-server-side-work-without-cloud-functions)
11. [Admin and content tooling](#11-admin-and-content-tooling)
12. [The content pipeline](#12-the-content-pipeline)
13. [Hosting, the static site and HTTP headers](#13-hosting-the-static-site-and-http-headers)
14. [Build, CI, previews and deploys](#14-build-ci-previews-and-deploys)
15. [Performance, the bundle and the quota](#15-performance-the-bundle-and-the-quota)
16. [Analytics, privacy and legal text](#16-analytics-privacy-and-legal-text)
17. [UI system and theming](#17-ui-system-and-theming)
18. [Testing](#18-testing)
19. [Invariants: the things that must stay true](#19-invariants-the-things-that-must-stay-true)
20. [Documentation index and history](#20-documentation-index-and-history)
21. [Open items](#21-open-items)

---

## 1. What Paragon is

Paragon is free WAEC (WASSCE) exam preparation for West African secondary-school students,
mainly in Nigeria. It is live at **https://paragon-hq.web.app** (Firebase project
`paragon-hq`).

It has **two product modes, which must never merge**:

| | Learning mode | WAEC Prep mode |
|---|---|---|
| Entry | `/courses` | `/waec` |
| Shape | Course → module (unit) → topic → lessons, topic test, drill | Subject → exam setup → a full timed or untimed paper → review |
| Feedback | Immediate, per question | None until the paper is submitted |
| Attempts recorded as | `source: 'drill'` (and `test`, `exercise`, `review`, `challenge`) | `source: 'waec'` |
| Feeds mastery (`progress`) | Drill only | Never |

**Content** comes from two sources:
- **Past questions**: real WAEC questions scraped from myschool.ng. Mathematics, Physics and
  Further Mathematics have them, labelled "WAEC 2018" and so on.
- **Generated practice**: questions built procedurally by code, with every answer computed,
  about 300 per topic. Mathematics, Physics, Further Mathematics, Chemistry and Government
  have them, labelled "Paragon practice", and every document carries
  `origin: 'ai_generated'`.

**Lessons** (articles, YouTube videos and exercises) are written in the content studio by a
small team of writers and reviewers.

**Subjects.** Mathematics, Physics, Further Mathematics, Chemistry and Government are live in
Firestore. Biology, Economics, English Language, Commerce and Music exist only as
placeholder outlines in `lib/core/content/subject_catalog.dart`, with a "Notify me" waitlist.

**Users.**
- **Guests** use anonymous Firebase Auth. They can do almost everything; the `canUse` table
  decides what they can't.
- **Accounts** sign in with Google or email and password.
- **Staff** have `writer`, `reviewer` or `admin` custom claims.

**Constraints that shape everything:**
- **Firestore is on the free Spark plan**: 50,000 reads, 20,000 writes and 20,000 deletes a
  day, counted per Pacific calendar day.
  - This is deliberate: the hard ceiling is the cost guarantee until there is revenue.
  - There are **no Cloud Functions**, because they need the Blaze plan. Server-side work
    runs as Node scripts on GitHub Actions.
- **Web first.** Flutter web is the primary target. Android builds work but are not shipped.
- **Low-end phones on slow connections.** Bundle size, first load and reads are measured
  and budgeted.

---

## 2. System map and every external service

```
                     ┌────────────────────────────── Browser (student / staff) ─────────────────────────────┐
                     │  Flutter web app (main.dart.js + deferred chunks, CanvasKit)                           │
                     │  Static pages: /past-questions/**, /privacy/, /terms/, /about/, 404.html               │
                     └──────┬──────────────┬───────────────┬──────────────┬───────────────┬──────────────────┘
                            │              │               │              │               │
                 Firebase Hosting   Firebase Auth     Cloud Firestore   Google Analytics  YouTube (nocookie
                 (paragon-hq.web.app) (anon, Google,  (Spark plan;      for Firebase      iframe, lessons)
                  rewrites, headers,  email/password) rules = the only  (events, opt-out)
                  CSP, 404)                            server-side guard)
                                                           ▲
                                                           │ Admin SDK (bypasses rules)
     ┌─────────────────────────────────────────────────────┴───────────────────────────────────────────────┐
     │ GitHub Actions (anti-darrenn/paragon)                                                                 │
     │   ci.yml            every PR/push: analyze, test, release build, node tests, rules emulator,         │
     │                     live content checks, Hosting preview channel                                      │
     │   notify-drafts.yml every 15 min: apply_roles, apply_account_requests, usage, notify_drafts (Resend)  │
     │   maintenance.yml   nightly 02:30 UTC: jobs.js --job=all --apply                                       │
     │   seed-content.yml  daily 08:30 UTC: seeders within the shared write budget                            │
     │   reclassify.yml    manual dispatch only: Groq-assisted topic reclassification                         │
     └───────────────────────────────────────────────────────────────────────────────────────────────────────┘
     Owner's machine (Windows, PowerShell): flutter build, build_static_site.js, firebase deploy, admin scripts
```

| Service | Used for | Where configured | Notes |
|---|---|---|---|
| **Firebase Hosting** | Serves the Flutter build and the static pages | `firebase.json` → `hosting` | SPA rewrite for listed route segments only; security headers; CSP enforced. Live deploys are manual. |
| **Firebase Auth** | Anonymous (guest), Google (popup), email and password | Firebase console; `lib/core/providers/auth_provider.dart` | Guests *link* to Google or email, so their uid is kept. Custom claims carry staff roles. |
| **Cloud Firestore** | All app data | `firestore.rules`, `firestore.indexes.json` | Spark quota. Offline persistence is on, with a 100 MB cache and multi-tab. |
| **Google Analytics for Firebase** | Usage events and screen views | `lib/core/providers/analytics_provider.dart` | Per-device opt-out. Screen names are route *patterns*. |
| **YouTube** (`youtube-nocookie.com`) | Video lessons | `features/lesson/video_player.dart` | The only file importing `youtube_player_iframe`. |
| **gstatic.com** | CanvasKit, Firebase JS SDK, Flutter's Roboto | CSP | Space Grotesk is bundled, so no runtime font fetch. |
| **GitHub** (`anti-darrenn/paragon`) | Code, PRs, Actions (CI and every scheduled job) | `.github/workflows/*.yml` at the git root | Secret: `FIREBASE_SERVICE_ACCOUNT`. |
| **Resend** | Staff emails (submitted for review, verdicts, report digests) | `tools/admin/notify_drafts.js` | `RESEND_API_KEY` secret, `NOTIFY_TO`/`NOTIFY_FROM` variables. Skips when unset. Without a verified domain, the sender reaches only the account's own address. |
| **Groq** (llama-3.1) | Proposing topic reclassifications | `tools/scraper/reclassify.js`, `reclassify.yml` | Dispatch-only. `GROQ_API_KEY`. Its labels were often wrong, so output is reviewed. |
| **myschool.ng** | Source of scraped past questions, answers, explanations and diagrams | `tools/scraper/4_*`, `5_*`, `10_*`, `myschool.js` | A Nuxt app; data is read from `__NUXT_DATA__`. The original HTML scraper is retired. |
| **Google Cloud Monitoring API** | Daily Firestore read and write counts for the studio | `tools/admin/usage.js` | Needs the **Monitoring Viewer** role on the service account; skips until granted. |
| **Google Search Console** | Indexing the static pages | `<meta name="google-site-verification">` in `web/index.html` | Removing the meta tag un-verifies the property. |
| **Paystack** (PR #50) | Donations | `kDonateLinks` in `lib/core/config/support_config.dart` | Payment pages open in a new tab, and Paragon never handles card data. Hidden until links are set. |
| **CDN for KaTeX** | None at runtime | — | KaTeX runs at *build time* in Node for the static pages. The app uses `flutter_math_fork`. MathJax is banned from `index.html`. |

**Secrets and variables** (GitHub repository settings):
- `FIREBASE_SERVICE_ACCOUNT`: the full service account JSON. Every script and workflow uses
  it. It needs Firebase Hosting Admin for previews and Monitoring Viewer for usage.
- `RESEND_API_KEY`, `GROQ_API_KEY`.
- Variables `NOTIFY_TO` and `NOTIFY_FROM`.

**Locally**, scripts read these instead:
- `tools/scraper/data/serviceAccountKey.json`, which is gitignored and must never be
  committed. `GOOGLE_APPLICATION_CREDENTIALS` also works.
- `tools/scraper/.env`, holding `GROQ_API_KEY`.

---

## 3. Repository layout

```
paragon/                         git root
├── CLAUDE.md                    rules, conventions, invariants (read first)
├── PLAN.md                      review findings → what was built / declined (waves A–K)
├── .github/workflows/           ci, notify-drafts, maintenance, seed-content, reclassify
├── paragon_plans/               PRD, tech-stack, schema docs (.docx/.md); archive/ is stale Next.js-era;
│                                router_sketch_deferred/ is dead code — never wire it in
└── project/                     the Flutter app — ALL flutter/firebase/node commands run here
    ├── .cursorrules             long-form brief / roadmap (its `cd` examples predate project/)
    ├── pubspec.yaml             Flutter 3.47, Dart 3.12+
    ├── firebase.json            hosting (rewrites, headers, CSP) + firestore file pointers
    ├── firestore.rules          the only server-side guard on client writes
    ├── firestore.indexes.json   composite indexes + collection-group overrides
    ├── web/index.html           splash/landing HTML, OG tags, hash→path rewrite, canonical
    ├── assets/                  google_fonts (Space Grotesk, OFL), images (logos), data (periodic table)
    ├── lib/                     the app (see 3.1)
    ├── test/                    106 test files (flutter_test, fake_cloud_firestore)
    ├── tool/                    Dart CLI: export_legal.dart (legal → static HTML), make_icons.dart, logo_source/
    ├── tools/                   Node: admin/, scraper/, site/, rules-test/, firestore_seed/ (see §11, §12)
    ├── docs/                    specs and records (see §20)
    └── android/ ios/ macos/ linux/ windows/   platform shells (Android builds; others unused)
```

### 3.1 `lib/`

```
lib/
├── main.dart              startup (path URLs, fonts, Firebase, Firestore cache, ProviderScope)
├── app.dart               ParagonApp: MaterialApp.router, theme, text scale, analytics binding,
│                          QuotaBanner/read-meter overlay above the navigator
├── firebase_options.dart  FlutterFire-generated
├── core/                  everything that is not a screen
│   ├── a11y/              speech_text.dart — LaTeX → spoken words (read-aloud + screen-reader labels)
│   ├── ai/                AiTutor seam + greyed "Ask (soon)" button; sends nothing
│   ├── auth/              feature_access (canUse table), guest_limits (copy), sign_out, staff_role
│   ├── challenge/         challenge_link model (/c/:id)
│   ├── config/            site_config (kSiteOrigin, kTagline), support_config (donations, thanks)
│   ├── content/           subject_catalog (placeholder outlines), question_counts (labels),
│   │                      session_mix (template capping), subject_tools (which study tools where),
│   │                      contributor (bylines)
│   ├── data/              read_meter (.metered()), cache_first, quota_status, error_reporter,
│   │                      read_meter_overlay (debug pill)
│   ├── exam/              exam_formats (verified WASSCE presets), saved_exam (device autosave),
│   │                      exam_result, waec_grade (A1–F9 estimate bands)
│   ├── insights/          examiner_insight model
│   ├── io/                save_file (web Blob download / no-op elsewhere) — data export
│   ├── learn/             topic_test (gate + pass mark), challenge (unit test/course challenge),
│   │                      exercise_session, hints, lesson_progress, watch_tracker, youtube_id
│   ├── legal/             legal_documents (privacy, terms, kLegalVersion), about_content — PURE DART
│   ├── lessons/           lesson_doc (THE parser), lesson_check (publish checks), subject_index
│   ├── models/            question, subject, unit, topic, learn_resource, lesson_asset, avatar,
│   │                      firestore_parsing (null-safe helpers)
│   ├── onboarding/        onboarding_step (funnel resolver, pure)
│   ├── plan/              weekly_goal, study_plan (weights, shortest path, grade estimate)
│   ├── prefs/             account_prefs (prefs that follow an account)
│   ├── progress/          mastery (levels), course_progress (outline × counters), mistakes
│   ├── providers/         auth, analytics(+binding), appearance, connectivity, reading settings
│   ├── repositories/      every Firestore read/write (see §4.3)
│   ├── rooms/             room (scoring, pure), room_repository, join_throttle
│   ├── router/            app_router (THE router), return_to (safe ?next=)
│   ├── search/            search.dart (pure ranking over catalog + subjectIndex + past questions)
│   ├── study/             study_dock, study_tool, study_tool_registry
│   ├── theme/             app_colors (only colour definitions), app_palette (ThemeExtension), app_theme
│   ├── theory/            theory_question model (Paper 2)
│   ├── web/               browser.dart (leave guard, share, origin) with web / other implementations
│   └── widgets/           shared widgets: AnswerOption, FullLatexView, MathText, QuestionRunner,
│                          DeferredScreen, LoadError, QuotaBanner, ParagonLogo, nav/ (shell, top bar,
│                          bottom tabs, back navigation, profile menu), ui/ui.dart (layout kit),
│                          lesson_blocks/ (renderers for lesson-format blocks)
└── features/              screens, grouped by area (see §6)
    ├── *.dart             dashboard, course catalog/index, topic overview, drill, topic test,
    │                      challenge, waec subject/setup/exam/review, exam history, welcome, sign-in,
    │                      settings, legal, about, support, not-found, route_keys
    ├── account/  admin/ (+ studio/)  challenge_link/  feedback/  lesson/  mistakes/  onboarding/
    ├── plan/  profile/  review/  rooms/  search/  settings/  study/ (calculator, cards, formulas,
    │   glossary, notes, offline, read_aloud, references, scratchpad)  support/ (PR #50)
    └── taster/  theory/  waitlist/
```

---

## 4. The app at runtime

### 4.1 Startup (`lib/main.dart`)

1. `usePathUrlStrategy()` gives real URLs. `web/index.html` first rewrites any old `/#/…`
   link with `history.replaceState`.
2. `GoRouter.optionURLReflectsImperativeAPIs = true`, so `context.push` updates the address
   bar.
3. `GoogleFonts.config.allowRuntimeFetching = false`. Fonts come from
   `assets/google_fonts/`, and the OFL licence is registered.
4. `Firebase.initializeApp`, then Firestore settings: persistence on,
   `WebPersistentMultipleTabManager`, and a 100 MB cache.
5. `ReadMeter.instance.logging = kDebugMode`.
6. `runApp(ProviderScope(child: ParagonApp()))`.

`web/index.html` shows a pure-CSS splash that doubles as a landing page:
- a pitch;
- a link to `/past-questions/`;
- a "still loading" note after 6 s.

The splash is removed on Flutter's `flutter-first-frame` event. The page preconnects to
gstatic, fonts, Firestore and identitytoolkit, and preloads `main.dart.js`.

### 4.2 State management (Riverpod 3)

- Screens are `ConsumerWidget` or `ConsumerStatefulWidget`.
- **Provider kinds:**
  - `FutureProvider` and `.family` for one-shot reads;
  - `StreamProvider` for Firestore streams, such as `weeklyAttemptsCountProvider`, the
    user document and rooms;
  - plain `Provider` for derived state.
- **v3 gotchas:**
  - there is no `.valueOrNull`; use `.asData?.value`;
  - `ref` cannot be used in `dispose()`, so `Analytics` resolves its instance lazily and may
    be held in a `State` field.
- **Auth** (`core/providers/auth_provider.dart`):
  - `authStateProvider` is `userChanges()` filtered to account-level changes (uid,
    anonymous, email, verified, providers). Unfiltered, the hourly token refresh would
    rebuild everything.
  - Also here: `currentUserProvider`, `userDataProvider` (the `users/{uid}` stream),
    `idTokenResultProvider` and `staffRoleProvider` (claims, UI only).
- **Appearance:** `appearanceProvider` (Dark / Light / Match device; dark is the default).
- **Reading settings:** text scale applied app-wide; line spacing and the Atkinson
  Hyperlegible font for articles.
- **Connectivity:** `connectivity_provider` drives the offline chip.

### 4.3 The data layer: repositories

All Firestore access lives in `lib/core/repositories/`. **Every read in `lib/` ends in
`.metered()`** (`core/data/read_meter.dart`).

| Repository | What it does |
|---|---|
| `learning_repository.dart` | `subjectsProvider`, `unitsProvider`, `topicsProvider` (cache-first), `drillQuestionsProvider(topicId)` and `waecQuestionsProvider(subjectId)`. **Drill**: `topicId ==` and `hasAnswer == true`, ordered by document id from a random auto-id cursor, limit 20. That is why questions need auto-ids. **WAEC**: `subjectId` + `source == 'waec'` + `hasAnswer` + year. |
| `course_repository.dart` | `courseProvider`: Firestore units and topics, or the catalog outline if none. `Course.findTopic` (id or slug, ids first); `topicPath`, `drillPath`, `testPath`, `pathForTopicId`; `subjectIdForKeyProvider`. |
| `learn_repository.dart` | Topic resources (`where status == 'published'`, ordered by `order`). Bank questions for exercises and tests. |
| `attempt_repository.dart` | `record()` writes one `attempts` doc per answer: `{userId, questionId, topicId, subjectId, selectedIndex, isCorrect, source, timestamp, hintsUsed?}`. |
| `progress_repository.dart` | `addSession()` writes **once per drill session** to `progress/{uid}`. Only drill calls it. |
| `learn_progress_repository.dart` | `learn/{uid}`: topic test results and lesson completion. |
| `exam_result_repository.dart` | `examResults` (one per finished WAEC paper) and history. |
| `mistakes_repository.dart` | The last 200 attempts (`userId ASC, timestamp DESC`) → the notebook. |
| `user_repository.dart` | User doc creation, username reservation (transaction with `usernames/{key}`), `setProfile` (onboarding: ignores blanks) vs `updateProfile` (settings: a blank is a delete). |
| `account_repository.dart` | `deleteOwnedDocuments`, export (`_ownedById`, `_ownedByQuery`), scheduled deletion. |
| `plan_repository.dart` | `plan/{uid}`. |
| `flag_repository.dart`, `feedback_repository.dart`, `waitlist_repository.dart` | Student-filed reports, feedback and waitlist. |
| `admin_flag_repository.dart` | Studio: resolve a question's reports (re-key the answer, retire, dismiss). |
| `admin_resource_repository.dart`, `lesson_workflow.dart` | Studio: lesson CRUD, versions, comments, one batch per workflow transition, `refreshLessonCount`. |
| `subject_index_repository.dart` | `subjectIndex/{subjectId}`: rebuilt from published lessons. |
| `staff_invite_repository.dart` | `staffInvites/{email}` (Team page). |
| `core/rooms/room_repository.dart` | Live quiz rooms. |

**Parsing.** Every `fromFirestore` uses the null-safe helpers in
`models/firestore_parsing.dart`: `docData`, `asString`, `asInt`/`asIntOrNull`, `asBool` and
`asStringList`. They coerce and never throw, because a throw inside provider mapping takes
down the whole screen.

**Cache-first content.** `subjects`, `units` and `topics` use `getCacheFirst`
(`core/data/cache_first.dart`): the device cache for 12 hours (`kContentMaxAge`) after a
server fetch, while the cache still holds every document. **Never** use it for questions,
attempts, progress or anything a student writes.

**Quota handling.**
- A `resource-exhausted` error sets `QuotaStatus`.
- `QuotaBanner`, above the navigator, and `LoadError` then say Paragon is busy until
  midnight Pacific.
- The next successful server answer clears it.

**Errors.** `ErrorReporter` sends `app_error` analytics carrying only the error type or
Firebase code and the route pattern. Each key is sent once, at most ten per session.

### 4.4 The navigation shell

`StatefulShellRoute.indexedStack` with `AppShell` (`core/widgets/nav/app_shell.dart`). It has
five branches, and **branch order is `NavTab` order**:

| # | Tab | Branch routes |
|---|---|---|
| 0 | Home | `/`, `/plan` |
| 1 | Courses | `/courses`, `/subject/:subjectId/course`, `…/course/topic/:topicId`, `/learn/topic/:topicId/:resourceId`, `/search` |
| 2 | WAEC | `/waec`, `/waec/:subjectId/setup`, `/waec/review/:examId` |
| 3 | Review | `/review`, `/mistakes`, `/saved`, `/cards/:subjectId`, `/settings/offline` |
| 4 | Me | `/me`, `/settings`, `/settings/*` (subjects, name, profile, username, export, security, reading) |

**Layout:**
- At **760 px and wider** (`kNavWideBreakpoint`), a translucent top bar
  (`kTopBarHeight` 68) floats over the pages. It has:
  - the logo on the left;
  - a centred island: Home, a Courses ▾ dropdown of every subject, WAEC Prep, Review and
    Search;
  - an account corner on the right: "Continue", or "Save progress" for a guest, an offline
    chip and the avatar menu.
- **Below 760 px**, there are bottom tabs instead.

**One tree shape across the breakpoint.** The pages are always the stack's first child, and
on a phone the top bar's slot is a positioned zero-size box. Re-parenting the navigators
would rebuild every page and restart a lesson video.

**Outside the shell** (full window):
- the focus sessions: drill, topic test, unit test and challenge, WAEC exam, mistakes
  practice, theory;
- onboarding, sign-in, `/legal/accept`, `/account/*`, `/about`, `/support`, `/try`,
  `/c/:id`;
- rooms and the studio.

**Back navigation.** Every app bar is `ParagonAppBar`. It pops when there is history,
otherwise it goes to `parentPathFor(uri)`. "Done" buttons use `context.popOrGo()`.
`back_navigation_test.dart` walks every route.

**Search palette.** It opens over the page from the top bar or with Ctrl/⌘+K. `/search?q=`
is the full page.

### 4.5 Deferred loading

Rarely used screens are imported `deferred as` in `app_router.dart` and built through
`DeferredScreen(load: lib.loadLibrary, builder: …)`. Loads are **keyed by the `load`
function**, and `didUpdateWidget` restarts a load when it changes. Keying by a shared string
id once made the WAEC exam render blank.

That covers the studio, rooms, the WAEC exam, challenges, theory, settings, account,
onboarding, support and similar screens.

Rules:
- A deferred library is imported eagerly nowhere else.
- A deferred type is never used in an `is` check; use a route-builder function such as
  `waecExamRoute`.
- Shared helpers are moved out to eager files, such as `admin_paths.dart`.

---

## 5. Routing, the redirect pipeline and every route

`lib/core/router/app_router.dart` is the only router.
- `appRouterProvider` builds the `GoRouter`.
- `_RouterNotifier` listens to `authStateProvider` and drives `refreshListenable`.
- `initialLocation` is `/welcome`.
- `errorBuilder` shows `NotFoundScreen`.

### 5.1 The redirect pipeline (order matters)

1. **Auth loading** → `null`, decide nothing yet.
2. **On `/welcome`**: remember `?next=` through `safeNextPath`, which allows in-app paths
   only, so there is no open redirect.
3. **Signed out**, on anything except `/signin`, `/welcome` or the public pages (`/privacy`,
   `/terms`, `/about`, `/support`) → remember the target and send them to
   `/welcome?next=…`.
4. **Signed in and arriving somewhere ordinary** → clear the pending `next`.
5. **Public pages** → allowed in every state, including part-way through onboarding.
6. **Studio gate**: `/admin/**` needs `staffRole.canWrite`, otherwise `/`. This is UI only;
   the rules are the real guard.
7. **Guests** (anonymous):
   - on a cold start at welcome → `next`, or `/`;
   - onboarding paths → `/`, because a guest must never reserve a username;
   - otherwise allowed.
8. **Accounts**, once `userData` has loaded:
   - **Deletion gate**: `deletionRequestedAt` set → `/account/deleting`, and nothing else.
   - **Onboarding gate**: `resolveOnboardingStep` requires `username`, `displayName` and
     `selectedSubjects`. Avatar and profile are optional steps reached only by going
     forward.
   - **Terms gate**: `needsLegalAcceptance` (the user's `legalVersion` ≠ `kLegalVersion`) →
     `/legal/accept`.
   - An account on sign-in, welcome or upgrade → `next`, or `/`.

**Signing out** always goes to `/welcome` (`signOutToWelcome`). Guests have "Welcome page"
and "Leave guest mode" in the profile menu and on `/me`.

### 5.2 Every route

**Legend:** **S** = inside the shell (tab), **D** = deferred, **P** = public (readable
signed out), **G✗** = guests refused by `canUse`.

| Path | Screen | Notes |
|---|---|---|
| `/welcome` | `WelcomeScreen` | Landing: sign in, browse as guest, try 5 questions; shows "Continue as guest" for an existing guest |
| `/signin` | `SignInScreen` | Google popup, email and password, reset |
| `/onboarding/username` · `/displayname` · `/avatar` · `/subjects` · `/profile` | onboarding screens (D) | Funnel; avatar and profile optional; profile is school and class only |
| `/` | `DashboardScreen` (S0) | Home: continue learning, "This week" goal card, practised topics |
| `/plan` | `PlanScreen` (S0) G✗ | Weekly goal, exam date, topic weights, grade estimate |
| `/courses` | `CourseCatalogScreen` (S1) | Every subject, live and coming soon |
| `/subject/:subjectId/course` | `CourseIndexScreen` (S1) | Modules, topics, mastery rings, plan panel |
| `/subject/:subjectId/course/topic/:topicId` | `TopicOverviewScreen` (S1) | Lessons, topic test, drill (gated), examiner themes, offline save |
| `/learn/topic/:topicId/:resourceId` | `LessonScreen` (S1) | Article, video or exercise beside the topic sequence, with "Up next" |
| `/search` | `SearchScreen` (S1) | `?q=` |
| `/waec` | `WaecSubjectScreen` (S2) | Subjects in `waecSubjectOrder` |
| `/waec/:subjectId/setup` | `WaecExamSetupScreen` (S2) | "Full paper" preset, custom, years, timed (G✗ timed), resume |
| `/waec/review/:examId` | `ExamReviewScreen` (S2) | Locked answers, grade estimate, practice comparison |
| `/review` | `ReviewScreen` (S3) | Hub: mistakes, saved, cards, offline |
| `/mistakes`, `/saved`, `/cards/:subjectId`, `/settings/offline` | (S3) | Notebook, bookmarks and notes, Leitner review, offline topics |
| `/me` | `MeScreen` (S4) | Private profile |
| `/settings` and `/settings/{subjects,name,profile,username,export,security,reading}` | (S4, D) | Every promise made in onboarding has a route here |
| `/subject/:s/course/topic/:t/drill` | `DrillScreen` | Gated by `drillAccessFor`; old `/subject/:s/unit/:u/topic/:t` redirects here |
| `/subject/:s/course/topic/:t/test` | `TopicTestScreen` | 10 questions, 80% pass |
| `/subject/:s/course/unit/:moduleId/test` | `ChallengeScreen` (D) | Unit test: 4 per topic, up to 40 |
| `/subject/:s/course/challenge` | `ChallengeScreen` (D) | Course challenge, 30; never unlocks drill |
| `/waec/:subjectId/exam` | `WaecExamScreen` (D) | Through `waecExamRoute`; leave-guard while running |
| `/waec/:subjectId/theory` | `TheoryScreen` (D) | Paper 2, self-marked; hidden below 20 questions |
| `/mistakes/practice` | `MistakesPracticeScreen` | 20 from the notebook, `source: 'review'` |
| `/join`, `/rooms/new`, `/rooms/:code/host`, `/rooms/:code` | rooms (D) | Hosting is G✗ |
| `/c/:id` | `ChallengeLinkScreen` (D) | A friend's challenge, `source: 'challenge_link'` |
| `/try` | `TasterScreen` | 5 instant-feedback questions, records nothing |
| `/support` (P), `/about` (P), `/privacy` (P), `/terms` (P) | (D) | The legal pages are also static HTML at `/privacy/` etc. |
| `/legal/accept` | `LegalAcceptScreen` | Terms gate |
| `/account/upgrade` | `UpgradeScreen` | Guest → account, linking the same uid |
| `/account/deleting` | `DeletingScreen` | 30-day grace: restore or delete now |
| `/admin`, `/admin/team`, `/admin/topic/:topicId`, `…/new/:type`, `…/resource/:resourceId`, `/admin/insight/:id`, `/admin/flag/:questionId` | studio (D) | §7 |
| Redirects | — | `/dashboard` → `/`; `/subjects` → `/courses`; `/subject/:id` and `/subject/:id/unit/:u` → the course; old `…/learn` and `…/article/…` paths → the lesson page |

**Readable URLs.** Keys are slugs, such as `/subject/mathematics/course/topic/indices`.
- Ids still resolve, because `findTopic` tries ids first.
- `SubjectKeyRoute` and `CourseTopicRoute` (`features/route_keys.dart`) resolve keys from
  cached data.
- Never build a path by hand.

**A new top-level segment** must be added to the hosting rewrite regex in `firebase.json`.
`hosting_rewrite_test.dart` fails until it is (see §13). A new route also needs a parent in
`parentPathFor`.

---

## 6. Product areas, feature by feature

### 6.1 Courses and topics (Learning mode)

**The course outline.** `courseProvider(subjectId)` joins Firestore units and topics into a
`Course`. If the subject has no units, it uses the catalog's placeholder outline.
Placeholder topics are never practisable (`CourseTopic.isPlaceholder`).

**Mastery** (`core/progress/mastery.dart`, pure) is per topic, from `progress/{uid}`
counters:

| Level | Answered | Accuracy |
|---|---|---|
| Not started | 0 | — |
| Attempted | 1 or more | — |
| Familiar | 10 or more | 50% or more |
| Proficient | 20 or more | 70% or more |
| Mastered | 40 or more | 90% or more |

- A topic is a **level**, never a percentage. Module and course aggregates become
  percentages.
- They are drawn only by `MasteryCircle` and `MasteryRing`.
- "Practised" topics are `practisedTopicIds`: drill answers or a topic test. They are
  display only.

**Question counts.** These are never one number that reads as "past questions":
`QuestionCounts.label` gives "51 past · 300 practice". The counts come from `topics` fields
written nightly (§10).

### 6.2 The drill gate, topic tests, unit tests and the course challenge

**The gate.** `core/learn/topic_test.dart` is pure and is the **only** place access is
decided, through `drillAccessFor`. Drill opens when:
- the topic test is passed: `kTopicTestQuestions` = 10 questions, `kTopicTestPassPercent` =
  80; or
- grandfathered: drill mastery is already proficient. This is permanent and one-way: it can
  grant access, never withhold it.

**Unit test** (`core/learn/challenge.dart`):
- 4 questions per topic (`kUnitTestPerTopic`), up to 40.
- It counts as passing a topic's test when it drew at least 4 of that topic's questions and
  80% were right. It writes `passedVia: 'unit_test'` with no increment to `attempts`.

**Course challenge**: 30 questions, and it **never** unlocks drill.

Both record `source: 'challenge'`. They add to `progress` only for topics already open once
marked.

**Enforcement.** The gate is **client-enforced by design**: rules see one document write,
not the answers behind it. Drill is practice, not a reward. Anything valuable placed behind
it would need a server first.

**Drill sessions:**
- 20 questions;
- instant feedback through `AnswerOption` and `AnswerVerdict`;
- hints, which are the explanation's steps minus the last. A right answer after a hint never
  counts toward mastery, and `hintsUsed` is recorded.

`mixSession` caps each generator template per session.

### 6.3 Lessons (`features/lesson/`)

**Page layout.** `/learn/topic/:topicId/:resourceId` shows the item beside the topic's
sequence, Khan-style, with "Up next" ending at the topic test. It keeps one tree shape: the
sidebar collapses to zero width rather than swapping a Row for a Column, so the iframe never
moves.

**Completion:**
- **Video**: `WatchTracker` counts about 90% actually played; seeking earns nothing.
- **Article**: its end is scrolled into view (`ScrollUpdateNotification` with
  `pixels > 0`), or 1.5 s after layout if it fits on screen.
- **Exercise**: a set is finished. Rules are in `ExerciseSession`: the first try is scored,
  then one retry, then the answer is revealed. Accounts record first tries once per set as
  `source: 'exercise'`.

**The lesson format** (`docs/LESSON_FORMAT.md`). `parseLessonDoc` is the **one** parser.
- It handles fenced blocks: callouts, worked examples with `--- step`, try-it, quick checks
  (never recorded), bank-question checks (`::: check q:<id>`, `::: waec q:<id>`), revision
  cards, figures (`asset:<id>`), tables, `::: more`, `::: video` and `::: todo`.
- Older plain articles go through `parseArticleBlocks` unchanged.
- Malformed input becomes a `LessonIssue` and is never thrown.

**Rendering.** `ArticleView` takes a `BlockDecorator`. `ArticlePane` composes the glossary,
notes and read-aloud hooks, so features never edit the renderer.

**Block keys** are `type + FNV-1a(normalised text) + occurrence`. They are split to be
web-safe, and notes and cards anchor to them.

**Learn content is never gated.** A lesson nudge above the topic test is never a gate.

### 6.4 Maths rendering

- **`FullLatexView`** (`core/widgets/full_latex_view.dart`) is the real renderer.
  - A hand-written scanner over mixed text and maths.
  - It handles `\(...\)`, `\[...\]`, `$$...$$`, `\textbf`, `\textit` and `\vspace`.
  - Inline maths sits in a horizontal scroll view.
  - Parse errors fall back to red monospace.
- **`MathText`** delegates to it. `useLightRenderer: true` is a lighter inline parser, and
  the two must agree.
- **Engine.** `flutter_math_fork` only; `flutter_tex` is banned.
- **Delimiters.** `$` is a literal dollar sign. `\emph` is unsupported; use `\textit`.
- **Accessibility.** `mathSemantics()` labels every maths line with `speakText`.
- **KaTeX fonts.** The build trims Caligraphic, Fraktur, SansSerif, Script and Typewriter
  from `FontManifest.json` (`tools/site/trim_fonts.js`). The editor and `content_lint.js`
  warn on the commands that need them.
- **Static pages.** `tools/site/render.js` mirrors this dialect with KaTeX in Node. Change
  both together.

### 6.5 WAEC Prep

**Setup** (`waec_exam_setup_screen.dart`):
- **The "Full paper" preset** comes from `core/exam/exam_formats.dart`, checked 2026-10-16
  against the WAEC syllabuses and the 2026 timetables, so `verified: true`:

  | Subject | Questions | Time |
  |---|---|---|
  | Mathematics | 50 | 90 min |
  | Further Mathematics | 40 | 90 min |
  | Physics | 50 | 75 min |
  | Chemistry | 50 | 60 min |
  | Biology | 50 | 50 min |
  | Government | 50 | 60 min |
  | Economics | 50 | 60 min |

  An unlisted subject falls back to 50 questions in 60 minutes, unverified, and the screen
  says "approximately".
- Custom size and years are also offered.
- Timed papers need an account. Untimed ones are open to guests in every subject.

**The exam** (`waec_exam_screen.dart`):
- **Keyboard**: A–E answer, ←/→ move, F flags, Enter submits from the summary.
- A 48 dp question strip announces each number's state.
- A pre-submit summary of answered, unanswered and flagged.
- A browser leave-guard while it runs.
- **No instant feedback, ever.**

**Autosave.** `SavedExam` keeps the paper on the device (shared_preferences, questions
included) so it can be resumed with answers, flags, place and clock. It is never in
Firestore. Submit or exit clears it, and it goes stale after a day.

**Results:**
- `examResults/{id}` stores the items and the score, and is never updated.
- The review (`/waec/review/:examId`) locks every answer.
- The grade is **always labelled an estimate from objective questions only** (`waec_grade`
  bands A1 ≥ 75 … F9). The bands are not official.
- `PracticeComparison` sets it beside the practice grade estimate.

**Theory (Paper 2)**: `theoryQuestions`, self-marked against the scheme, with nothing
stored. Hidden until a subject has 20 (`kTheoryMinQuestions`).

### 6.6 Review: mistakes, saved items, revision cards and offline

- **Mistakes notebook** (`core/progress/mistakes.dart`).
  - Nothing is stored for it. A question is in the notebook while its latest attempt, among
    the student's last 200, was wrong.
  - Practice draws 20 and records `source: 'review'`, which never reaches `progress`.
- **Notes and highlights.**
  - `notes/{id}` holds one note per annotated block. A snapshot shows "from an earlier
    version" if the lesson is reworded.
  - Bookmarks and the Leitner `cards` schedule live in `study/{uid}`, written once per review
    session as a merge.
  - Guests keep these on the device only; the rules refuse anonymous writes.
- **Revision cards** come from `subjectIndex` (published lessons). Up to 20 per session
  (`kCardsPerSession`).
- **Save for offline** prefetches a topic, with 30 questions, into the Firestore cache.
  Videos can't be cached. Saved topics are kept in shared_preferences.

### 6.7 Study tools (`core/study/`, `features/study/`)

`StudyDock` wraps the lesson, drill, topic test and WAEC exam screens.
- Tools implement `StudyTool` and register in `study_tool_registry.dart`.
- **Availability** comes from `content/subject_tools.dart`.
  - Exams narrow to `examAllowedTools`: calculator, four-figure tables and scratchpad.
  - The periodic table is **off in exams** by decision.

**The tools:**
- a calculator: a hand-written fx-82-style engine, with persistent memory through a
  provider;
- a scratchpad;
- the periodic table (CIAAW 2024, `assets/data/periodic_table.json`);
- four-figure tables, computed and never typed;
- units and constants (CODATA 2018);
- a glossary;
- a formula sheet.

Per-visit tool state lives in `StudySession`, owned by the dock.

**Read aloud.** `flutter_tts` with the LaTeX-to-speech converter, at rates of 0.75 to 1.5. It
never speaks hidden answers.

### 6.8 Plan, goal and grade estimate (`core/plan/`)

- **Weekly goal**: one of 50, 100, 200 or 400 (`kWeeklyGoals`). Weeks run Monday to Sunday
  in Lagos time, whatever the device's zone. No run of weeks is kept, so there are no
  streaks.
- **Topic weights**: each topic's share of real past questions (`pastQuestionCount`), or
  uniform where there are none, and the UI says which.
- **Shortest path**: weight × what is left.
- **Grade estimate from practice**:
  - hidden below 20 drill answers in the subject;
  - shown as a range below 50;
  - always beside `kGradeEstimateNote`.

  It reads `progress`, which is allowed because it is private and display only.
- **Storage**: `plan/{uid}` holds the goal and exam date. Accounts only.

### 6.9 Search (`core/search/search.dart`, `features/search/`)

- **Sources:**
  - courses and topics from the course catalog;
  - lessons and topics from each live subject's `subjectIndex` (one cached read each);
  - past questions from `/past-questions/search.json`, a static file fetched only for
    queries of 3 or more characters, so it costs no reads.
- **Palette**: arrows, Enter and Esc, up to 6 results per group.
- **Privacy**: nothing about searches is stored or logged.

### 6.10 Live quiz rooms (`core/rooms/`, `features/rooms/`)

**Codes** are drawn from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, with up to 50 players.

**The host** (an account) creates `rooms/{code}`:
- `{hostUid, subjectId, topicId, topicName, questionIds ≤ 20, state, index, createdAt,
  results}`;
- `state` moves lobby → question → reveal → podium, then closed.

**Players** (guests allowed) write `players/{uid}` with a nickname, and
`answers/{uid_index}`.
- An answer is accepted only while the room's `state == 'question'` at that index, once,
  from a joined player. The rule reads the room with `get()`.
- `join_throttle.dart` rate-limits code guessing on the client.

**Scoring** (`room.dart`) is one point per right answer, with no speed bonus. The host's
client totals the score at the podium.

**Cost and cleanup.** A player listens to the room only: about 2,600 reads for a
30-player game. Rooms **never** write `attempts` or `progress`, and are deleted after a day
by `jobs.js --job=rooms`.

### 6.11 Challenge links, the taster and the waitlist

- **Challenge a friend**: from a practice session, writes `challenges/{id}`
  (`{userId, name, subjectId, topicId, topicName, questionIds ≤ 10, score, total,
  createdAt}`).
  - The friend opens `/c/:id` and answers with `source: 'challenge_link'`, which never
    reaches `progress`.
  - Deleted after 30 days.
- **Taster** (`/try`): five questions from a subject's most-examined topic, with instant
  feedback through the shared `QuestionRunner`. Records nothing.
- **Waitlist**: "Notify me" on a coming-soon subject writes `waitlist/{uid}`
  `{userId, subjects: [slug], updatedAt}`. Accounts only. Reviewers `count()` it per
  subject.

### 6.12 Accounts, onboarding and guests

**Guests.** Anonymous auth, decided entirely by `canUse(Feature, isGuest:)` in
`core/auth/feature_access.dart`. Guests are refused only `waecTimed`, `studyPlan` and
`hostRoom`. The copy lives in `guest_limits.dart`, and there is never an inline `isGuest`
gate.

**Upgrading a guest** (`/account/upgrade`):
- *links* Google or email to the anonymous uid, so everything stays;
- copies device-only notes, cards and lesson ticks up (`guest_upgrade.dart`);
- cannot merge into an existing account: the student is told their guest progress stays
  behind.

**Onboarding:** username → display name → avatar (optional) → subjects → profile
(optional: school and class only).
- **Usernames** are reserved in `usernames/{key}` and change once every 90 days.
  Reservations are never released.

**Profile.** `users/{uid}` also holds:
- `avatar` (`preset:<id>` or `initials:<colour>`);
- `bio` (up to 160 characters, private);
- `prefs`, which follow the account (`account_prefs_sync.dart`). An analytics opt-out
  spreads to every device; an opt-in never does.

**Deleting an account.**
- An account is scheduled for 30 days; `/account/deleting` offers restore or "delete now".
- A guest is deleted at once.
- Anything keyed by uid is deleted by `AccountRepository.deleteOwnedDocuments` and by
  `OWNED` in `jobs.js`.

**Security settings:**
- password reset and email verification;
- re-authentication;
- "sign out everywhere", which writes `accountRequests/{uid}`. The 15-minute job revokes
  the refresh tokens.

**Export.** "Download my data" (`/settings/export`) is a JSON Blob of everything owned.
`export_test.dart` keeps export and delete covering the same set.

**Terms.** `kLegalVersion` is `2026-10-15`. Bumping it sends every account to
`/legal/accept`.

### 6.13 Support, about, feedback and reporting

- **`/support`**: why Paragon is free, schools and tutors (live quiz, mailto), and help
  another student.
  - The donate card (PR #50) is Khan-style: one-time or monthly, preset ₦ amounts and
    "Other".
  - It opens Paystack pages from `kDonateLinks`, and is hidden while every link is null.
- **`/about`**: thanks the names in `kAcknowledgements` and explains the provenance labels.
- **Feedback**: "Send feedback" from Settings and About writes `feedback/{id}`
  `{userId, kind: idea|problem|praise|other, message ≤ 2000, screen, createdAt}`. Guests are
  allowed, and the studio triages it.
- **Problem reports** (`flags`):
  - `ReportProblemButton` on questions;
  - `ReportLessonButton` on lessons (with `resourceId` and `topicId`);
  - a missing `status` means open.

### 6.14 Accessibility

- **Answer options.** Every option a student answers is `AnswerOption`: one semantics node,
  "Option B: 4, selected", then "…, incorrect", in a mutually exclusive group, with its own
  tap action.
- **Verdicts.** `AnswerVerdict` is words and an icon in a live region.
- **The WAEC exam** has its own tile with the same semantics.
- **Maths** is spoken through `speakText`.
- **Contrast.** `onLow` text passes WCAG AA.
- **Reading settings**: text size (0.9 to 1.5) and the Atkinson Hyperlegible font. Low-data
  mode loads images and videos only on tap.

---

## 7. The content studio

**Entry.** Settings → Content studio (`/admin`). The router lets writers in; the **rules**
decide each action.

**Roles** are custom claims on the Auth token, never fields on `users/{uid}`:

| Role | Can |
|---|---|
| `writer` | Create and edit **unpublished** items, submit them, delete their own drafts |
| `reviewer` | Everything a writer can, plus publish, request changes (with the reason as a comment), unpublish, delete, reorder, handle every problem report, re-key or retire questions, update `topics.lessonCount` |
| `admin` | Everything, never subject-limited. Manages the team. |

- A `subjects` claim limits a writer or reviewer to some subjects; no claim means all.
- The rules check both the old and the new `subjectId` on updates.

**Giving a role:**
1. The person signs up normally.
2. An admin uses **Team** (`/admin/team`), which writes `staffInvites/{email}`.
3. `apply_roles.js`, in the 15-minute workflow, sets the claims.
4. The person signs out and in; a claim change otherwise waits for a token refresh, up to an
   hour.

`set_role.js` does the same at once from a terminal.

**Workflow** (`docs/CONTENT_ROLES.md`): `draft → in_review → published`, with
`changes_requested` sending an item back.
- Only the exact string `published` is ever visible to students.
- **Revisions.** A published item is never edited in place. "Start a revision" creates a
  draft with `revisionOf`, and approving it copies the content into the original, which
  keeps the original's id and every student's completion tick.
- **History.** Every save appends the previous content to `…/resources/{id}/versions`,
  append-only and restorable. Review threads live in `…/comments`.
- **One batch per transition** (`LessonWorkflow`). The transition also sets
  `pendingNotice`, which the email job picks up.
- **Side effects.** Publish, unpublish and delete rebuild that topic's entry in
  `subjectIndex` and refresh `topics.lessonCount`.
- **Placeholders.** `checkPublishable` (`lesson_check.dart`) refuses placeholder titles,
  empty articles and video lessons without a link. A reviewer can override with a reason.

**Screens:**

- **`/admin`**, in order:
  1. the review queue and the "sent back" list;
  2. question reports, grouped by question over the 200 most recent, open first;
  3. lesson reports;
  4. a course map of every topic's lesson state, from one collection-group query per
     subject;
  5. the launch panels (`launch_panels.dart`):
     - **Usage**: `_meta/usage`;
     - **Content quality**: `_meta/contentAudit`;
     - **Feedback**;
     - **Waitlist**: `count()` per subject;
     - **Traction**: `metrics/{day}`, admins only.
- **`/admin/topic/:topicId`** is the topic planner: items in order, drag to reorder
  (reviewers), "Preview as student", and row menus.
- **The editor** (`/admin/topic/:topicId/new/:type` and `…/resource/:resourceId`) has:
  - an insert toolbar, keyboard shortcuts and a bank-question picker;
  - the problems panel (`checkLesson`) and copy/paste of blocks between lessons;
  - image upload to `lessonAssets`, compressed in the browser. `file_picker` and `image`
    are **deferred**, so students never download them;
  - history, comments, and an autosave backup **on the device only**.
- **`/admin/insight/:id`** is the examiner insight editor. It refuses to publish text with
  20 or more consecutive words shared with the pasted report (`longestSharedRun`).
- **`/admin/flag/:questionId`** resolves a question in one batch that also closes its open
  reports:
  - mark a different answer, keeping `previousCorrectIndex`, with a revert offered;
  - retire it (`hasAnswer: false`);
  - dismiss the reports.

  Generated questions are labelled, because their fix belongs in `tools/scraper/gen` too.
- **Rebuild buttons**: "Rebuild search, glossary & cards" for one subject, and "Rebuild all
  subjects".

**Emails** (`notify_drafts.js`, every 15 minutes):
- Submitted items, together with new question, lesson and feedback reports, go to
  reviewers as a digest. Reports are tracked by cursors in `_meta/notify`.
- Verdicts go to the writer.
- While `NOTIFY_FROM` is unset, writer emails go to `NOTIFY_TO`, labelled with who they are
  for.

---

## 8. Data model: every Firestore collection

**Legend:**
- **R/W** is who reads and writes from the *client*, enforced by the rules.
- **Admin** means written only by the Admin SDK (scripts or jobs), which bypasses the rules.
- **Owned** means keyed by or carrying a uid. Every owned collection must be in
  `deleteOwnedDocuments`, the export, and `OWNED` in `jobs.js`.

### 8.1 Content (read by students)

| Collection | Key fields | Client access | Written by |
|---|---|---|---|
| `subjects/{id}` | `name`, `topicCount` (0 = unknown), `questionCount`, `pastQuestionCount`, `practiceQuestionCount`, `theoryCount` | read: **anyone, even signed out** (the welcome ticker) | seeders, `jobs.js --job=counts` |
| `units/{id}` | `subjectId`, `name`, `order` | read: signed in | seeders |
| `topics/{id}` | `subjectId`, `unitId`, `name`, `order`, `questionCount` (`hasAnswer`), `pastQuestionCount` (`source == 'waec'`), `practiceQuestionCount` (`origin == 'ai_generated'`), `lessonCount` (0 = unknown), `hasExaminerThemes` | read: signed in. Update: a **reviewer**, `lessonCount` only | seeders, the counts job, the studio |
| `questions/{id}` (auto-ids) | `subjectId` (required), `topicId`, `text`, `options` (no A/B/C prefix), `correctIndex` (0-based; **−1 = no verified answer**), `hasAnswer`, `source` (`waec`/`drill`), `origin` (`ai_generated` for generated), `year`, `explanation`, `imageId`, `explanationImageId`, `needsDiagram`, `hasInsight`, `previousTopicId`, `previousCorrectIndex`, `reviewNote`, `duplicateOf`, `reviewedAt`/`By` | read: signed in. Update: a **reviewer**, only `correctIndex` (bounded by the option count), `previousCorrectIndex`, `hasAnswer`, `reviewedAt`, `reviewedBy` | scrapers, seeders, `import_questions.js`, `fix_questions.js`, `apply_corrections.js` |
| `topics/{t}/resources/{id}` | `type` (article/video/exercise), `title`, `body`, `videoUrl`, `order`, `subjectId`, **`status`** (must be present), `revisionOf`, `createdBy`, `editedInApp`, `pendingNotice` | read: `published` for anyone signed in (**the list must filter `status == 'published'`**); every status for writers. Writes: the workflow rules (§7) | the studio, `9_seed_resources.js` (skips `createdBy` and `editedInApp` items without `--force`) |
| `…/resources/{id}/versions/{v}` | previous content | the team; append-only | the studio |
| `…/resources/{id}/comments/{c}` | review thread | the team | the studio |
| `lessonAssets/{id}` | `{mime (webp/jpeg/png/svg), data ≤ 900k chars, width, height, createdBy, createdAt}`; images ≤ 1600 px wide | read: signed in; create: writers; never updated; delete: reviewers | the studio, `10_fetch_question_images.js` |
| `subjectIndex/{subjectId}` | definitions, formulas, revision cards from published articles; every topic with `lessons: [{id, title, type}]` | read: signed in; write: reviewers of that subject | the studio's rebuilds |
| `insights/{id}` (per question by its id; per topic as `topic_<topicId>`) | `kind`, `subjectId`, `status`, `summary`, citation | students *get* published ones only; writers draft, reviewers publish | the studio; `jobs.js --job=insights` stamps the `hasInsight` and `hasExaminerThemes` flags |
| `theoryQuestions/{id}` | `subjectId`, `status`, `parts` | published only | Admin |
| `contributors/{uid}` | `{displayName, role, credential}` | public read | Admin (`set_contributor.js`, after consent) |

### 8.2 Per-student data (owned)

| Collection | Shape | Rules |
|---|---|---|
| `users/{uid}` | Create exactly `{uid, email, displayName, isAnonymous, createdAt}`, then client-writable: `displayName`, `selectedSubjects`, `profile` (`{school ≤ 100, classYear ∈ JSS3/SS1/SS2/SS3/Graduate/Other}`), `avatar`, `bio`, `prefs`, `username`/`usernameKey` (through a reservation), `usernameChangedAt`, `deletionRequestedAt`, `legalVersion`/`legalAcceptedAt`, `isAnonymous`, `email`, `updatedAt` | Owner only. An **allow-list** of client fields (`clientWritableFields`) and shape checks (`clientFieldsAreValid`, `profileIsValid`, `prefsAreValid`). Every timestamp must be `request.time`. XP, levels, stats and streak fields are **refused**. |
| `usernames/{normalised}` | `{uid, raw}` | Claimed in a transaction; permanent |
| `attempts/{id}` | `{userId, questionId, topicId, subjectId, selectedIndex, isCorrect, source, timestamp, hintsUsed?}`, with `source ∈ drill / waec / test / exercise / review / challenge / challenge_link` | Create, read and delete by the owner; never updated. **The source of truth.** |
| `progress/{uid}` | `{userId, updatedAt, topics: {<topicId>: {answered, correct, subjectId}}}` | Owner. Closed field set, `updatedAt == request.time`. **A display cache**: only drill writes it, and nothing competitive may read it. |
| `learn/{uid}` | `{userId, updatedAt, topics: {<topicId>: {passed, bestScore, attempts, subjectId, lastAttemptAt, passedVia?, completed: {<resourceId>: true}, lastCompletedId, lastCompletedAt}}}` | Owner. Kept separate from `progress` because a test pass is not recomputable. |
| `examResults/{id}` | `{userId, subjectId, items (≤ 100), total, correct, timed, durationSeconds, submittedAt}` | Owner. Exact shape; never updated. |
| `notes/{id}` | `{userId, topicId, resourceId, subjectId, blockKey, colour, text ≤ 2000, snapshot ≤ 1000, createdAt, updatedAt}` | Owner; not anonymous |
| `study/{uid}` | `{userId, updatedAt, bookmarks (≤ 500), cards (≤ 5000; ids `topic:resource:key`)}` | Owner; not anonymous; merge writes |
| `plan/{uid}` | weekly goal (from `kWeeklyGoals`), exam date | Owner; accounts only |
| `waitlist/{uid}` | `{userId, subjects, updatedAt}` | Owner writes; reviewers read |
| `challenges/{id}` | see §6.11 | Written once; *get* by anyone signed in; *list* and delete by the creator |
| `flags/{id}` | `{questionId | resourceId+topicId, userId, reason, createdAt}`, plus `status`, `resolvedAt`, `resolvedBy` | Create (no status, or `open`); the owner and reviewers read; reviewers change only the status fields |
| `feedback/{id}` | see §6.13 | As `flags`; statuses `open / done / dismissed` |
| `accountRequests/{uid}` | `{type, requestedAt}` | Owner; applied by `apply_account_requests.js` |
| `staffProfiles/{uid}` | a team member's name and avatar | Team-readable |
| `rooms/{code}` (+ `players/{uid}`, `answers/{uid_index}`) | see §6.10 | Hosts are accounts; guests join; answers only while live |

### 8.3 Operational

| Document | Purpose | Access |
|---|---|---|
| `staffInvites/{email}` | Team page requests `{email, role, subjects, status}` | Admin only |
| `metrics/{day}` | Daily aggregate counts (Lagos day), no uids | Admins read |
| `_meta/usage` | Daily Firestore reads and writes (`usage.js`) | Reviewers read |
| `_meta/contentAudit` | Content audit summary (`content_audit.js --publish`) | Reviewers read |
| `_meta/notify` | Email cursors (`flagsNotifiedThrough`, `feedbackNotifiedThrough`) | Admin SDK only |

### 8.4 Indexes (`firestore.indexes.json`)

**Composite indexes:**
- `users`: `isAnonymous`, `createdAt`, for guest cleanup.
- `attempts`: `userId`, `timestamp` ASC and DESC, for the weekly count and the mistakes
  notebook.
- `examResults`: `userId`, `subjectId`, `submittedAt` DESC, for history.
- `questions`: `topicId`, `hasAnswer`, `__name__`, for drill rotation.
- `questions`: `subjectId`, `source`, `hasAnswer`, `year` ASC and DESC, for WAEC.
- `resources`: `status`, `order`, for students' published lists.

**Collection-group overrides** on `resources`:
- `status`, for the course map and the review queue;
- `pendingNotice`, for the email job;
- `subjectId`.

---

## 9. Security model

**The rules are the server.** With no Cloud Functions, `firestore.rules` is the only thing
standing between a client and the database.

**Philosophy:**
- **Allow-lists, never deny-lists.** Any `users/{uid}` field not in `clientWritableFields`
  is server-only by construction, including fields that don't exist yet.
- **Closed shapes** with `keys().hasOnly(...)` and `hasAll(...)`, type and size checks, and
  `request.time` for every timestamp.
- **Rules are not filters.** A list query must provably return only readable documents. Hence
  the `status == 'published'` filter, and the ban on any "missing status counts as
  published" clause, which once leaked drafts.
- **Roles from token claims.** `isWriter()` ⊃ `isReviewer()` ⊃ `isAdmin()`, with
  `inScope`, `writes(subjectId)` and `reviews(subjectId)` for subject limits.
- **Anonymous limits.** Guests cannot write `notes` or `study`, nor reserve usernames, which
  the router also blocks.

**Known, deliberate client trust:**
- the drill gate (§6.2);
- room scoring, totalled by the host;
- mastery counters, which are private and display only.

**Verifying the rules.** Every change needs both checks:
- **The emulator suite** (`tools/rules-test/rules.test.js`) runs in CI's `rules` job,
  because Java is not on the dev machine. It has seeded fixtures and allow and deny cases,
  including a whole room game.
- **`tools/admin/verify_rules.js`** runs against **production** after a deploy, as a real
  anonymous client over REST. It makes about 150 checks, and **the denials are the
  content**.

**Hosting security** is covered in §13.

**Credentials:**
- The service account JSON lives only in the GitHub secret and the gitignored local file.
- The Firebase web config in `firebase_options.dart` is public by design.

---

## 10. Server-side work without Cloud Functions

All server work is plain `firebase-admin` Node, run by GitHub Actions on a schedule
(`.github/workflows/`, at the git root). The trade-off: nothing reacts to an event within
milliseconds. Derived values are recomputed on a schedule from `attempts` and the content,
which is correct, just eventually.

| Workflow | Schedule | Runs | Needs |
|---|---|---|---|
| `ci.yml` | every PR and every push to main | §14 | `FIREBASE_SERVICE_ACCOUNT` (content, preview) |
| `notify-drafts.yml` | every 15 min | 1. `apply_roles.js` (Team invites → claims)<br>2. `apply_account_requests.js` ("sign out everywhere" → revoke tokens)<br>3. `usage.js --apply` (Monitoring → `_meta/usage`; skips without Monitoring Viewer)<br>4. `notify_drafts.js` (Resend; skips without `RESEND_API_KEY`) | SA, `RESEND_API_KEY`, `NOTIFY_TO`/`NOTIFY_FROM` |
| `maintenance.yml` | daily 02:30 UTC (03:30 Lagos) | `jobs.js --job=all --apply` | SA |
| `seed-content.yml` | daily 08:30 UTC | `7_create_subject.js` (Chemistry, Government), `6_seed_generated.js --all`, within the shared daily budget; skips what is already seeded | SA |
| `reclassify.yml` | **manual dispatch only** | `reclassify.js --apply` | SA, `GROQ_API_KEY` |

**`tools/admin/jobs.js`.** A dry run unless `--apply`. `--job=all` runs:

| Job | Does |
|---|---|
| `guests` | Deletes anonymous users idle 30 or more days, with everything they own (`OWNED`) and their Auth user |
| `deletions` | Completes deletions scheduled 30 or more days ago |
| `orphans` | Removes owned documents whose user no longer exists |
| `counts` | `topics.questionCount`, `pastQuestionCount`, `practiceQuestionCount` with `count()` aggregates; subject totals as the **sum of topics**; `lessonCount` (openable published items, mirroring `LearnResource.isAvailable`); `theoryCount` |
| `challenges` | Deletes challenges older than 30 days |
| `rooms` | Deletes rooms older than a day, with their subcollections |
| `insights` | Stamps `questions.hasInsight` and `topics.hasExaminerThemes` from published insights |
| `metrics` | Writes `metrics/{lagos-day}` aggregate counts |

**One-shots, never in `all`:**
- `dropstreak`: for restoring an old backup;
- `resourcestatus`: backfilled `status`;
- `dropprofile`: removed retired profile keys. On 2026-10-16, 0 of 44 users held one.

`OWNED` = `attempts`, `flags`, `feedback`, `notes`, `examResults` and `challenges` (by
`userId`), plus `progress`, `learn`, `study`, `accountRequests`, `staffProfiles`,
`waitlist`, `plan`, `contributors` and `users` (by document id).

---

## 11. Admin and content tooling

**Node CommonJS, with no npm scripts.** Run each file directly from its folder after
`npm install`. Credentials come from `FIREBASE_SERVICE_ACCOUNT`,
`GOOGLE_APPLICATION_CREDENTIALS`, or `tools/scraper/data/serviceAccountKey.json`. Almost
everything is a **dry run** until `--apply` or `--commit`.

### 11.1 `tools/admin/`

| Script | Purpose |
|---|---|
| `jobs.js` | Scheduled maintenance (§10) |
| `notify_drafts.js` | Staff email digests through Resend |
| `apply_roles.js` / `set_role.js` | Team invites → claims / set a role from the terminal |
| `set_admin_claim.js` / `create_admin_user.js` | Bootstrap admins |
| `apply_account_requests.js` | Carries out "sign out everywhere" |
| `usage.js` | Daily read and write counts → `_meta/usage` |
| `verify_rules.js` | About 150 live rules checks as a real client |
| `content_lint.js` | Published lessons with placeholder titles, broken maths or trimmed-font commands. Exits non-zero. Same regexes as `lesson_check.dart`. |
| `check_counts.js` | Asserts each subject's count equals the sum of its topics |
| `question_rules.js` | **Pure, tested** content rules: broken or stray LaTeX, duplicate options, lost negative powers, missing diagrams, duplicates within a paper, and so on. Also the mechanical fixes. |
| `content_audit.js` | Past questions vs the rules. `--cache` costs no reads, `--list=<rule>`, `--publish` writes `_meta/contentAudit`. |
| `fix_questions.js` | Mechanical fixes outside maths only: `10-3` → `10^{-3}`, units, `30o` → `30°`, naira, OCR fixes. `--commit`, `--revert=.backups/…`. |
| `apply_corrections.js` | Reviewed hand corrections from `corrections/*.js`: retire a duplicate (`hasAnswer: false`, `duplicateOf`), reword a stem, retag (`previousTopicId`) |
| `import_questions.js` | Validated bulk import: 4–5 distinct options, one answer, maths that parses, a year on past questions, no duplicate stems. It refuses the level-A rules. |
| `set_contributor.js` | Publishes or removes a public byline, after consent |
| `credential.js` | Shared credential loader |

Every content write keeps a backup in `tools/admin/.backups/` (gitignored). The record of the
2026-10-15 cleanup is `docs/audit/CONTENT_REVIEW_2026-10-15.md`.

### 11.2 `tools/scraper/`

| Script | Purpose |
|---|---|
| `4_scrape_answers.js <subject>` | Answers and explanations from myschool.ng's `__NUXT_DATA__` |
| `5_match_answers.js <subject> --apply` | Joins them onto existing questions |
| `6_seed_generated.js --all` | Generated questions into **existing** topics, by `topicId`. Additive; skips full topics. |
| `7_create_subject.js --subject=<id>` | A whole new subject: subject → units → topics → questions |
| `8_apply_reclass.js` | Applies a reviewed reclassification mapping, recording `previousTopicId` |
| `9_seed_resources.js --subject=<id>` | Learn articles, videos and exercises. Writes `published`; skips studio-edited items. |
| `10_fetch_question_images.js --all` | Diagrams → `lessonAssets`, setting `imageId`; retires questions whose diagram is gone (`needsDiagram`) |
| `reclassify.js` | Groq-proposed topic reassignments, for review |
| `check_linkage.js`, `check_subjects.js`, `diagnose_classification.js` | Diagnostics |
| `seed_quota.js` | The shared daily write budget (`data/_seed_budget.json`, keyed to the Pacific day) |
| `delete_old_subject.js` | One-off cleanup |
| `myschool.js` | Source parsing helpers |
| `gen/*.js` + `run.js` | The procedural generators (§12.2). `verify.js` checks them. |
| `archive/` | The retired `1_scrape`, `2_classify`, `fix_misclassified` and `3_seed`. **Never revive `3_seed.js`**: it duplicates subjects. |
| `content/` | Lesson source files for `9_seed_resources.js` |

### 11.3 `tools/site/`, `tools/rules-test/`, `tool/` and `tools/firestore_seed/`

- `tools/site/`: `build_static_site.js`, `render.js` (+ `render.test.js`), `site.css` and
  `trim_fonts.js` (§13).
- `tools/rules-test/`: the emulator suite (`npm test`).
- `tool/export_legal.dart`: legal and about text → JSON for the static pages.
- `tool/make_icons.dart`: icons, favicon, OG image and the logo PNGs from
  `tool/logo_source/`.
- `tools/firestore_seed/`: small JSON fixtures, historical.

---

## 12. The content pipeline

### 12.1 Past questions (scraped)

```
myschool.ng (Nuxt)  ──4_scrape_answers──►  data/*.json  ──5_match_answers──►  questions (source:'waec', year, correctIndex)
                     ──10_fetch_question_images──►  lessonAssets + questions.imageId
                     content_audit / fix_questions / apply_corrections  ──►  cleaned questions (backups kept)
                     reclassify (Groq) ──review──► 8_apply_reclass  ──►  topicId (+previousTopicId)
```

- **Answers.** The scraped corpus originally had `correctIndex: -1`, meaning no verified
  answer. `-1` stays the required fallback, because a `0` fallback silently marks option A
  correct.
- **Visibility.** Only `hasAnswer: true` questions reach drill, WAEC, tests or exercises.
- **Classification accuracy.** On a sample, the Groq labels were wrong for 81% of
  Mathematics, 61% of Physics and 8% of Further Mathematics.
  - 2,246 high-confidence reassignments were applied.
  - 290 low-confidence rows were deliberately left alone.
  - After any reclassification, re-check topic counts and seed the thin topics; a drill
    session needs 20.

### 12.2 Generated practice

- **Where.** `tools/scraper/gen/` has a module per subject area. Each computes its answers
  in code.
- **What.** It produces `data/generated_<subject>_<topic>.json`: 300 per topic, 216 topics,
  about 64,800 questions.
- **Unseeded randomness.** The generators use unseeded `Math.random()`, so **re-running
  `run.js` produces a different corpus**. The committed JSON (about 44 MB) is the corpus.
  Don't re-run it casually.
- **Marking.** Every document is `origin: 'ai_generated'` (`source: 'drill'`), with
  auto-ids and `hasAnswer: true`.
- **Templates.** There are a few per topic; Indices has 300 questions from nine templates.
  `mixSession` caps repeats in a session.

### 12.3 Seeding under the Spark quota

- Seeding everything needs four to five days of quota.
  - The seeders share `data/_seed_budget.json`, stop cleanly when the day's budget is spent,
    and resume the next day.
  - `seed-content.yml` drives them.
- Counting uses `count()` aggregation, billed per 1,000 index entries. Never fetch a whole
  topic just to size it; that drained the read quota once.

### 12.4 Lessons

- **Written in the studio** by the team (§7).
- **Seeded in bulk** from `tools/scraper/content/` by `9_seed_resources.js`.

### 12.5 Content correctness

- **A defect class, not a content task.** Before shipping a feature that reads a field,
  verify the field actually has values in production.
- **`test/generated_latex_test.dart`** parses every LaTeX expression in the generated corpus
  through `flutter_math_fork`, and renders a sample. It carries a deliberate control case.
- A green suite proves content parses and renders, not that it is *right*. Problem reports
  and the studio's flag screen are the correction loop.

---

## 13. Hosting, the static site and HTTP headers

### 13.1 Build output

The `build/web` deploy contains:
- **the Flutter app**: `index.html`, `main.dart.js`, deferred `*.part.js`, assets and
  `FontManifest.json` (trimmed);
- **`/past-questions/**`**: a static page per published past question, plus subject and year
  indexes, `/past-questions/waec/` and `search.json`;
- **`/privacy/`, `/terms/`, `/about/`**: static HTML generated from the app's own text on
  every build, through `dart run tool/export_legal.dart`, never from cache;
- **`sitemap.xml`, `robots.txt` and `404.html`**.

### 13.2 `build_static_site.js`

- **What it publishes.** Only past questions: `source == 'waec'`, `hasAnswer`, a real
  `correctIndex`. Never generated practice.
- **Cost and caching.** The first run reads about 4,500 documents. The result is cached in
  `tools/site/.cache/` (CI keys it by ISO week), and `--refresh` reads again.
- **Maths** is rendered server-side by KaTeX (`render.js`, mirroring `FullLatexView`).
  - Plain-text places (titles, descriptions, previews, JSON-LD) use `plainMath()`:
    `\frac{2x-1}{x+3}` → `(2x-1)/(x+3)`, and never TeX source.
- **Titles** carry no question number. They are de-duplicated, and the build **fails** if
  two remain the same.
- **JSON-LD**: Quiz (accepted answer plus the suggested others), BreadcrumbList and
  ItemList.
- **Social and trust**: `og:image` on every page, and a trust footer.
- **Sitemap `lastmod`** is the day a page's HTML last changed (`.cache/lastmod.json`).
- **The origin** comes from `kSiteOrigin` in `lib/core/config/site_config.dart`. That is the
  one-line switch for a domain move.

### 13.3 `firebase.json` hosting

- **The SPA rewrite.** Only the app's top-level route segments are rewritten to
  `/index.html`, by an RE2 regex with no lookahead:

  ```
  ^/(?:(?:about|account|admin|c|cards|courses|dashboard|join|learn|legal|me|mistakes|onboarding|
  plan|privacy|review|rooms|saved|search|settings|signin|subject|subjects|support|terms|try|waec|
  welcome)(?:/.*)?)?$
  ```

  - Anything else gets `404.html` with a real 404.
  - Hosting serves real files before rewrites.
  - `test/hosting_rewrite_test.dart` walks the router and fails when a segment is missing.
  - The local Hosting emulator **cannot** test regex rewrites on Windows: superstatic's
    `glob-slasher` turns `/courses` into `\courses`.
- **Headers on every path except `/__/`**, which Firebase Auth frames:
  - `X-Frame-Options: DENY`, `nosniff`, a referrer policy and a permissions policy;
  - **an enforced Content-Security-Policy**:
    - `default-src 'self'`;
    - scripts from self, inline and `wasm-unsafe-eval`, gstatic, googletagmanager and
      apis.google.com;
    - connections to `*.googleapis.com`, gstatic, fonts.gstatic, Analytics and
      `paragon-hq.firebaseapp.com`;
    - frames from firebaseapp.com, `youtube-nocookie.com`, accounts.google.com and
      apis.google.com;
    - `img-src https: data: blob:`;
    - `object-src 'none'`, `base-uri 'self'`, `form-action 'self'`,
      `frame-ancestors 'none'`.

    **A new third-party host must be added here first.** It was verified clean in
    report-only mode, through sign-in, video and an exam, before being enforced.
- **Cache headers.** App routes are `no-cache` (same regex). `/past-questions/img/**` is
  immutable.

### 13.4 Search engines

- The static pages are the **only** part of Paragon a crawler can read.
- Every app route's `index.html` names `/` as canonical.
- The splash and `noscript` link to `/past-questions/`.
- Search Console is verified by meta tag. "URL is not on Google" for new pages is normal
  until they are crawled.

---

## 14. Build, CI, previews and deploys

### 14.1 Local commands (PowerShell, from `project/`)

```powershell
flutter run -d chrome
flutter analyze
flutter test                                   # or a file / --plain-name
flutter build web --release; node tools/site/build_static_site.js; firebase deploy --only hosting
firebase deploy --only firestore:rules ; node tools/admin/verify_rules.js
firebase deploy --only firestore:indexes
```

- **After adding or removing a plugin, run `flutter clean`** before a release build. A stale
  cached `web_plugin_registrant.dart` once shipped production without the YouTube and
  SharedPreferences plugins. Check with:
  `grep -c WebYoutubePlayer .dart_tool/flutter_build/*/web_plugin_registrant.dart`.
- **Android.** `flutter build apk --debug` works; an AVD `Test-_-` exists. It isn't shipped.
- **Windows and PowerShell 5.1 pitfalls:**
  - `Get-Content` and `Set-Content` mangle UTF-8; use the editor or `[IO.File]`.
  - Quotes inside `git commit -m` break; use `-F file`.
  - Never `Stop-Process -Name node`; stop processes by PID.

### 14.2 CI (`ci.yml`)

| Job | Does |
|---|---|
| `app` | `flutter analyze`, `flutter test`, the release build, a plugin-registrant check, the static site build (cached by ISO week), font trimming. **Fails if `main.dart.js` exceeds 5,000,000 bytes.** |
| `node` | `tools/admin/*.test.js`, `tools/site/render.test.js` |
| `rules` | The emulator suite |
| `content` | `content_lint.js` and `check_counts.js` against production, read-only (about 250 reads) |
| `preview` | Deploys to a 7-day Hosting preview channel and comments the URL on the PR |

**Live deploys are manual, by the owner.** Merging to main deploys nothing.

### 14.3 Git conventions

- **Commits** are conventional, with project scopes from `.cursorrules`:
  - types `feat|fix|chore|content|refactor|style|docs`;
  - scopes such as drill, waec, auth, dashboard, router, theme, models, providers, scraper,
    seeder, classifier, firestore, latex, android and deploy.
- Formatting commits never mix with logic commits.
- Work goes on a branch, then a PR into `main`. Don't stack PRs on each other's branches:
  merging into a stacked base once caused confusion.

---

## 15. Performance, the bundle and the quota

- **First load.** About 3.5 MB gzipped, measured 2026-10-03: `main.dart.js` about 1.5 MB and
  CanvasKit about 2 MB from gstatic. Details are in `docs/audit/PERF.md`.
- **Bundle.** `main.dart.js` is about 4.75 MB unpacked, against the CI budget of 5 MB. Rarely
  used screens are deferred (§4.5).
- **Fonts.** Space Grotesk and the Atkinson Hyperlegible reading font are bundled in
  `assets/google_fonts/`. Runtime fetching is off, so `bundled_fonts_test.dart` fails if
  `lib/` asks for a family that isn't there. KaTeX fonts are trimmed to the ones used.
- **Images.** No full-size image is ever put in `assets/`. The logo is 128 px tall, at 2x.
- **Reads** are measured per route pattern by the debug read-meter pill. Tap it to copy a
  table for `docs/audit/QUOTA.md`.
- **Design choices that keep reads low:**
  - `progress`, `learn` and `study` are one document each, not subcollections. Forty
    padlocks cost one read.
  - `subjectIndex` costs one read per subject for search, glossary, cards and formulas.
  - Content is cache-first for 12 h.
  - `search.json` and the static pages cost zero reads.
  - The notify job uses cursors, not stamps on every report.
  - Counting uses `count()`.
- **Writes.** Drill writes `progress` once per session. A WAEC exam writes one
  `examResults` document, and the in-progress exam stays on the device.

---

## 16. Analytics, privacy and legal text

**Events** (`core/providers/analytics_provider.dart`):

| Group | Events |
|---|---|
| Funnel | `guest_start`, `signup_start`, `signup_complete{method}`, `onboarding_step`, `onboarding_complete` |
| Learning | `topic_open`, `drill_start`, `drill_complete`, `topic_test_complete`, `exercise_complete`, `lesson_item_complete` |
| WAEC | `exam_start{preset}`, `exam_complete` |
| Social | `challenge_created`, `challenge_played`, `room_hosted`, `room_joined` |
| Other | `taster_complete`, `waitlist_join`, `app_error` |

There is also the user property `is_guest`.

**Rules for analytics:**
- `analytics_binding.dart` wires screen views from the deepest route leaf
  (`currentConfiguration.last`) and `is_guest`.
- Screen names are **route patterns**, never concrete URLs or ids.
- There is a per-device opt-out, read at call time.

**Legal text** (`core/legal/legal_documents.dart`) holds the privacy policy, terms,
`kLegalVersion`, `kLegalChanges` and contact details.
- **It must change whenever analytics or stored data changes**, because it tells users
  exactly what is collected.
- It is pure Dart, so `tool/export_legal.dart` can turn it into the static pages.
- It includes an NDPA "legal basis" section, and is still a draft for a lawyer's review.

**Minors' data.** Profiles hold school and class only; age, gender, country and state were
removed on 2026-10-15. Profiles are private: nothing social reads `users/{uid}`.

---

## 17. UI system and theming

- **Colours.**
  - `AppColors` is the **only** place colours are defined; there are no raw `Color()`
    literals in widgets.
  - Theme-dependent colours come from `context.palette` (`AppPalette`): background,
    surface, border, track, text primary and secondary, `textStrong`, `onHigh`,
    `onMedium`, `onLow`, `outline` and `outlineFaint`.
  - Never use `AppColors.*Dark` or translucent white in a widget. `AppColors.neutral` is for
    places with no context.
- **Modes.** Dark is the default; Light and Match device are options
  (`kAppearanceChoiceEnabled = true`). `ParagonLogo` picks the white or black wordmark.
- **Components.** Buttons, fields, dialogs, snackbars, chips and segmented buttons are
  styled by `AppTheme`; don't restyle them inline.
- **Type.** Space Grotesk: `displayLg`, `heading1–3`, `bodyLg/Md`, `label`, `caption` and
  `btnLabel`.
- **Layout kit** (`core/widgets/ui/ui.dart`): `PageBody`, `PageIntro`, `SectionHeader`,
  `SurfaceCard`, `ListRow`, `RowGroup` and `EmptyState`.
  - Pages are `kPageMaxWidth` 720 wide, with a section gap of 28.
  - `ParagonPage` and `CompactPageBar` (`page_layout.dart`) handle phone headers and scroll
    padding under the top bar.
- **Breakpoints.** 760 is nav wide or compact. The top bar has dense (900) and roomy (1100)
  steps.

---

## 18. Testing

- **The Flutter suite**: 106 files under `test/`, using `flutter_test` and
  `fake_cloud_firestore`.
- **Many tests carry a deliberate *control* case**, which proves the test can fail. Keep the
  controls when editing.

| Test | Pins |
|---|---|
| `generated_latex_test.dart` | Every generated LaTeX expression parses and a sample renders, with a control |
| `latex_render_test.dart` | `FullLatexView` and `MathText` behaviour |
| `model_null_safety_test.dart` | Parsing helpers never throw, with a control group |
| `hosting_rewrite_test.dart` | Every router segment is in the rewrite regex; headers; CSP |
| `back_navigation_test.dart` | Every route has a parent |
| `deferred_screen_test.dart` | Loads are keyed per library |
| `bundled_fonts_test.dart` | Every `GoogleFonts` family in `lib/` is bundled, with a control |
| `guest_landing_test.dart`, `guest_waec_start_test.dart` | Guest routing |
| `challenge_screen_test.dart`, `challenge_link_test.dart`, `exercise_pane_test.dart`, `mistakes_notebook_test.dart`, `drill_hints_test.dart` | Which sources may reach `progress` |
| `lesson_progress_test.dart` | `learn/{uid}` parsing |
| `export_test.dart` | Export and delete cover the same collections |
| `profile_edit_test.dart` | `setProfile` vs `updateProfile`, each the other's control |
| `exam_ux_test.dart` | Exam keyboard, strip, save and resume, formats |
| `legal_details_test.dart` | Legal text facts |
| `donate_card_test.dart` (PR #50) | The donate card, and that what ships stays hidden |

**Node tests:**
- `tools/admin/*.test.js`: question rules, import, lint, counts, roles, contributor;
- `tools/site/render.test.js`.

**Rules tests:** the emulator suite in CI, and `verify_rules.js` live.

---

## 19. Invariants: the things that must stay true

Breaking any of these has caused, or would cause, a real defect. Most have a test.

1. **Modes never merge.**
   - WAEC questions never reach drill providers without a `source` filter.
   - There is no instant feedback in the WAEC exam.
   - WAEC never feeds `progress`.
2. **Only drill writes `progress`.** Test, exercise, review, challenge-link and room answers
   never do; otherwise mastery would bypass the topic test.
3. **Nothing competitive or rewarding reads `progress`.** XP, leaderboards and achievements
   must recompute from `attempts` on a server first. Client-writable stats on `users/{uid}`
   are a hard blocker.
4. **`drillAccessFor` is the only gate. `canUse` is the only guest table.**
5. **`correctIndex` fallback is −1, never 0.**
6. **Resources must carry `status`, and student lists filter `status == 'published'`.**
   Never add a "missing status counts as published" clause.
7. **Questions use auto-ids** (drill rotation) and need `hasAnswer: true`.
8. **Every Firestore read ends in `.metered()`.** Content uses cache-first; student data
   never does.
9. **Anything keyed by uid** is in `deleteOwnedDocuments`, the export and `OWNED`.
10. **Every `fromFirestore` uses the parsing helpers.**
11. **A new top-level route** goes in the hosting regex and `parentPathFor`.
12. **A new third-party host** goes in the CSP.
13. **A deferred library is imported only by the router**, and its types are never used in
    `is` checks.
14. **`flutter clean` after plugin changes.**
15. **No MathJax in `index.html`. No `flutter_tex`. `$` is money.**
16. **`legal_documents.dart` changes with analytics or data changes.** Bump `kLegalVersion`
    only for significant changes.
17. **Streaks are gone; don't reintroduce them.**
18. **Onboarding asks only for data something uses.** Every "change it later" has a route.
19. **One tree shape** across breakpoints in `AppShell` and `LessonScreen`, so videos
    don't restart.
20. **A published lesson is never edited in place**; use revisions.
21. **Never revive `3_seed.js`. Don't casually re-run `gen/run.js`. Don't re-enable the
    reclassify schedule** without deciding which pass is authoritative.
22. **After changing the rules:** deploy, run `verify_rules.js`, and add an emulator case.
23. **Bundle ≤ 5 MB. No full-size images in `assets/`.**
24. **google_fonts stays at 8.** Version 9 needs a `material_ui` migration. **A new font
    family or weight needs its file in `assets/google_fonts/`**, because runtime fetching is
    off.
25. **Profiles are school and class only.** A new profile field needs `profileIsValid`
    changed first.

---

## 20. Documentation index and history

| File | What |
|---|---|
| `../CLAUDE.md` | Rules and conventions (authoritative) |
| `../PLAN.md` | Review findings and waves A–K: built or declined, and why |
| `.cursorrules` | Original long-form brief and roadmap |
| `docs/ARCHITECTURE.md` | This file |
| `docs/LAUNCH_CHECKLIST.md` | The owner's remaining steps, deploys, decisions |
| `docs/CONTENT_ROLES.md` | Studio roles and the workflow contract |
| `docs/LESSON_FORMAT.md` | The lesson markup spec |
| `docs/LATEX_RENDERING.md` | The maths dialect |
| `docs/COPY.md` | Tagline options |
| `docs/WAEC_OUTREACH.md` | Draft letter to WAEC about past-question permission |
| `docs/REPO_FACTS.md` | Phase 0 audit: what the code really did versus PLAN.md's guesses |
| `docs/audit/STATE.md`, `CONFLICTS.md`, `NEXT.md` | The 2026-09-17 codebase audit |
| `docs/audit/PERF.md`, `QUOTA.md` | Measured performance and reads |
| `docs/audit/CONTENT_REVIEW_2026-10-15.md` | The content cleanup record |
| `tools/admin/README.md`, `tools/scraper/archive/README`, `tools/firestore_seed/README.md` | Tool notes |
| `paragon_plans/` | Spec docs. `archive/` (PRD v2, Tech Stack, Execution Plan) is **stale, Next.js-era**. `router_sketch_deferred/` is **dead**. |

**History in brief:**
- **2026-09:** the codebase audit, the account system (PR #8), a build round, then the nav
  shell, light mode and Flutter 3.47 (PRs #21–#27).
- **Waves A–K** (PRs #29–#40): launch safety, the drill gate, slugs and path URLs, studio
  roles, rooms, plan, insights, trust pages.
- **The 2026-10-15 external audit** (PRs #43–#48):
  - hosting, SEO and the CSP;
  - accessibility;
  - the content cleanup: 842 mechanical fixes, 57 hand corrections, 53 retirements;
  - deferred screens and bundled fonts.
- **2026-10-16:** PR #49 (verified exam formats, the profile rule), PR #50 (the donate
  card), and this document together with the reading-font fix. Atkinson Hyperlegible had
  been silently falling back since the fonts were bundled.

---

## 21. Open items

**Owner-only** (details in `docs/LAUNCH_CHECKLIST.md`):
- deploy the rules after PR #49 and run `verify_rules.js`;
- add the Paystack links to `kDonateLinks`;
- grant **Monitoring Viewer** to the service account;
- set `NOTIFY_FROM` once a domain is verified in Resend;
- bylines through `set_contributor.js`, with consent;
- choose a tagline (`kTagline`; options in `docs/COPY.md`);
- the domain move (`kSiteOrigin`, Hosting custom domain, Search Console);
- send the WAEC letter;
- get a lawyer's review of the privacy policy;
- the browser click-through in the checklist.

**Deliberately not done:**
- the audit's H ideas;
- the 923 missing explanations;
- real alt text for diagrams;
- rebuilding the 31 flattened tables;
- 20 questions with duplicate distractor options, which the Content quality panel shows as
  expected.

**Structural limits to keep in mind:**
- **No server.** The drill gate, room scores and mastery are client-trusted.
- **Spark quotas.** A busy day can exhaust reads; the app degrades with the quota banner.
- **Scheduled jobs**, not triggers. Counts and flags lag by up to a day.
