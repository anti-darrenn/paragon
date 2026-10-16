> **Read first:** `project/docs/REPO_FACTS.md`, § "Plan v2 against reality" (Phase 0, 2026-10-16).
> It records where this plan's guesses about the repo were wrong, and which items already exist.

# Paragon — Plan v2 (after the 16 Oct 2026 review)

> **For Claude Code.** This replaces the open parts of `PLAN.md` (v1). Most of v1 Phases 1–3 shipped. This plan covers what a second review of the live site (`paragon-hq.web.app`, 16 Oct 2026) found still open or new.
>
> The reviewer saw the **live site only, not the repo**. Facts marked **(observed)** were seen on the live site. Anything about code, file names or collections is a **guess to confirm in Phase 0**.
>
> **Content is being written separately.** Don't write lessons, explanations or questions yourself. Build the tools, checks, flags and UI so content drops in cleanly and bad data can't reach students.

---

## Ground rules (read every session)

1. Work on **one phase per session**. Start with plan mode, show the plan, then implement.
2. **One commit per task**, message prefixed with the task ID (e.g. `Q2.3: flag recurring-decimal candidates`).
3. **Never deploy to live without asking.** Use Firebase preview channels: `firebase hosting:channel:deploy v2-<phase>`. Share the URL.
4. **Never bulk-edit or delete production Firestore data without asking.** Scripts default to `--dry-run` and print a report. They only change data with `--apply`. Export a backup first (`gcloud firestore export gs://<bucket>/backups/<date>`).
5. **Never rewrite question text, answers or explanations automatically.** Scripts may *flag* problems and *propose* fixes into a review queue. A human approves each change.
6. Anything marked **VERIFY** is Moyo's decision. Stop and ask.
7. At the end of each phase, tick the boxes here and add a one-line "Done notes".

---

## What's already done (don't redo, don't break)

All **(observed)**:

- Placeholder lessons gone. Empty topics say "Lessons for this topic are on the way. You can still practise now."
- Split counts everywhere: "49 past · 300 practice". "Paragon practice" badge on generated questions. Meta description distinguishes real past questions from practice.
- Counts agree across app and static site (Maths: 1,677 past, 12,900 practice, 483 for 2015–2024).
- Guest = persistent guest account (survived 3 days). Guests can drill all topics and sit untimed papers in Maths, Further Maths and Physics. Only timed exams are gated.
- Path URLs that deep-link: `/courses`, `/subject/mathematics/course`, `/subject/mathematics/course/topic/indices`, `.../indices/drill`, `/waec`, `/waec/mathematics/setup`, `/join`, `/support`, `/welcome`.
- Static site under `/past-questions/` with 4,428 sitemap URLs: subject, year, topic and question pages. Server-rendered KaTeX, `Quiz` + `BreadcrumbList` JSON-LD, canonical tags, WebP diagrams with alt text, `robots.txt`, a `<noscript>` fallback on `/`.
- "Full paper" exam preset = 50 questions. Drill feedback, hints, "Report a problem", "Save this question".
- Option buttons expose "Option A: 16, incorrect / correct" to screen readers.
- Logo 144 KB → 41 KB. KaTeX fonts loaded at startup: ~20 → 11.
- New: mastery %, unit tests, course challenge, live quiz (`/join`), support page, topic frequency line ("Comes up in about 1 in 34 WAEC Mathematics questions").

---

## Phase 0 — Confirm facts (no code changes)

Update `docs/REPO_FACTS.md` (create it if v1 Phase 0 didn't).

- [x] **0.1** Router file and the full route table, including the static `/past-questions/` generator: script path, language, how it's triggered, where its output goes.
- [x] **0.2** Question schema as it exists now: every field on a past question and on a practice question. Specifically find:
  - the field that marks past vs practice (`source`? something else?)
  - year, paper, question number (does a question-number field exist?)
  - topic tag field(s): single or multiple, by ID or name
  - explanation field(s)
  - image/diagram field(s)
  - any `verified` / `reported` / `reportCount` fields
  - where "Report a problem" submissions are stored, and their shape
- [x] **0.3** **Where did the past-question bank come from?** Look for import scripts, raw data files, scraper code, commit messages, README notes. Record what you find, quoting file paths. **Don't guess.** If nothing explains it, write "unknown" and ask Moyo.
- [x] **0.4** How practice questions are generated: script path, templates, how many templates per topic, how distractors are made, whether a difficulty field exists.
- [x] **0.5** How mastery is computed: file, formula, and whether past and practice answers are weighted differently.
- [x] **0.6** Firebase Hosting config (`firebase.json`): rewrites, redirects, headers, and which site(s) exist.
- [x] **0.7** Write down anything in this plan that's wrong given what you found. **Stop and wait for Moyo.**

Done notes: 2026-10-16. Recorded in `project/docs/REPO_FACTS.md` § "Plan v2". The bank came from myschool.ng, and its raw data is in the repo. There are no paper, sitting or question-number fields. Phase 4 is mostly built, and Phase 8.1 is done.

---

## Phase 1 — Custom domain (do first, before Google indexes more)

**Why:** Google is starting to index `paragon-hq.web.app` URLs. Every week that passes, more ranking signals build up on the wrong domain. Schools also trust a real domain more than `*.web.app`.

- [ ] **1.1** **VERIFY** with Moyo: the domain name and who buys it (e.g. `paragon.ng`, `paragonprep.ng`, `getparagon.com`). Moyo buys it and controls the registrar account. Claude Code doesn't.
- [ ] **1.2** Write `docs/DOMAIN_SETUP.md` with exact steps for Moyo:
  1. Firebase console → Hosting → Add custom domain → `<domain>` and `www.<domain>`.
  2. Add the TXT verification record and the A/AAAA records Firebase shows at the registrar.
  3. Wait for the SSL certificate to show "Connected".
- [ ] **1.3** Make the new domain canonical everywhere, using a single config value (e.g. `SITE_ORIGIN` env var / constant) read by:
  - the static generator: `<link rel="canonical">`, `og:url`, JSON-LD `url` and `item`, sitemap `<loc>`, `robots.txt` `Sitemap:` line
  - the Flutter app: share links, live-quiz join links, any absolute URLs
  - `web/index.html` meta tags
  - Grep for `paragon-hq.web.app` across the repo. **Zero hard-coded occurrences** when done (except docs and the redirect rule).
- [ ] **1.4** 301 every path on `paragon-hq.web.app` to the same path on the new domain. Firebase Hosting can't redirect by hostname inside one site, so:
  - Create a second Hosting site for the old `web.app` name, **or** **VERIFY** the approach Moyo prefers.
  - On the old site, deploy only a `firebase.json` with `"redirects": [{ "source": "/**", "destination": "https://<domain>/:splat", "type": 301 }]`. Confirm the `:splat` syntax works with a test path. If it doesn't, use a tiny Cloud Function / Cloud Run redirector that preserves path + query.
  - Firebase Auth: add the new domain to **Authorized domains**. Update the Google sign-in OAuth client's authorized JavaScript origins and redirect URIs. Test Google sign-in and email sign-in on the new domain **before** turning on redirects.
- [ ] **1.5** Support page: replace the personal Gmail with `hello@<domain>` (**VERIFY** the address and the email forwarding provider Moyo sets up). Put it in one constant.
- [ ] **1.6** `docs/DOMAIN_SETUP.md`: add Search Console steps for Moyo. Add a Domain property for the new domain, submit `https://<domain>/sitemap.xml`, and use "Change of address" from the old property if it's verified.

**Acceptance:** `curl -I https://paragon-hq.web.app/past-questions/waec/mathematics/2018/` → `301` to the same path on the new domain. Google and email sign-in work on the new domain. `grep -r "paragon-hq.web.app"` finds only docs and redirect config.

Done notes:

---

## Phase 2 — Past-question data quality and provenance

**Why (observed):** Two sampled questions match schoolngr.com word for word, including explanations and a typo:

- WAEC 2018 Maths `/past-questions/waec/mathematics/2018/J0lgjrRava/`: "Expression 0.612 in the form x/y…". Options 153/250, **68/111**, 61/100, 21/33. Marked answer A. 68/111 = 0.612612…, which suggests the original had recurring-decimal dots that were lost, so A may be wrong.
- WAEC 2016 Physics `/past-questions/waec/physics/2016/80xbCj3VG6/` (soft iron bar PQ).

Copied text hurts search ranking (Google prefers the original), carries over their errors, and raises a permission question. About 20–40% of sampled past questions have **no explanation**. Topic tags look off.

### 2.1 Provenance (decision first)

- [ ] **2.1.1** From Phase 0.3, write `docs/QUESTION_SOURCES.md`: where the bank came from, how it was imported, and the date.
- [ ] **2.1.2** **VERIFY** with Moyo (his decision, not Claude Code's): whether Paragon has permission to republish the source's question text and explanations. Options to present:
  - (a) Keep the questions (WAEC is the original author either way), but rewrite every explanation in Paragon's own words and fix the text against original papers.
  - (b) Get written permission from the source.
  - (c) Rebuild from original WAEC papers Moyo or contributors own.

  Record the decision in `docs/QUESTION_SOURCES.md`. The rest of Phase 2 assumes (a) unless told otherwise.
- [ ] **2.1.3** Add fields to past questions (names to match existing conventions from Phase 0):
  ```
  importedFrom:        string    // e.g. 'schoolngr' | 'manual' | 'contributor' — where THIS copy came from
  textVerified:        bool      // stem + options checked against an original WAEC paper
  answerVerified:      bool      // answer checked against an original paper / marking scheme
  explanationOrigin:   'imported' | 'original' | 'none'
  verifiedBy:          string?   // contributor uid
  verifiedAt:          timestamp?
  ```
  Backfill script `scripts/backfill_provenance` (dry run by default): `importedFrom` from Phase 0.3 evidence, `textVerified=false`, `answerVerified=false`, `explanationOrigin='imported'` where an explanation exists, else `'none'`.

### 2.2 Similarity report (finds what's copied)

- [ ] **2.2.1** If the import source's raw data is in the repo or a bucket, compare directly. If not, **don't scrape any website.** Use only what's already stored.
- [ ] **2.2.2** Script `scripts/report_explanations` writes `reports/explanations.csv` with these columns:

  `id, subject, year, topic, hasExplanation, explanationOrigin, explanationLength, explanationHasLatex, explanationLooksTemplated`

  `explanationLooksTemplated` is true when the text matches generic patterns such as "To round to two significant figures" on a three-significant-figure question. Check for a mismatch between the numbers in the stem and the explanation, e.g. the stem says "three significant figures" and the explanation says "two".
- [ ] **2.2.3** Print a summary: per subject × year, the % of questions with no explanation, imported explanations, and original explanations. This becomes the content team's to-do list.

### 2.3 Automated checks that flag questions for human review

Script `scripts/lint_past_questions`. Output `reports/question_flags.csv` (`id, url, flag, detail`). Also write a `flags: []` array onto each question with `--apply`. **No text changes.**

- [ ] **2.3.1** **Answer key sanity:** exactly one correct option, 4–5 options, no duplicate options after normalising whitespace, LaTeX and fraction forms (`\frac{68}{111}` = `68/111`).
- [ ] **2.3.2** **Recurring decimal candidates:** the stem contains a decimal like `0.612`, and one option equals the recurring value (e.g. 68/111 = 0.612612…, to within 1e-6) while another equals the terminating value. Flag `recurring_decimal_suspect`. This catches the 0.612 case.
- [ ] **2.3.3** **Numeric answer check:** where the stem is a pure arithmetic, rounding, significant-figure or standard-form task, compute the answer with a small evaluator and compare it to the marked option. Flag a mismatch as `answer_mismatch_suspect`. Keep the evaluator conservative: if it can't parse the question, skip it rather than guess.
- [ ] **2.3.4** **Typos and grammar in stems:** a list of known WAEC-stem typos (e.g. stem starts with `Expression ` followed by a number → likely "Express"). Also run a dictionary spell check with a maths and physics allow-list. Flag `typo_suspect` with the suggested word.
- [ ] **2.3.5** **Diagram references without an image:** the stem mentions `diagram|figure|illustrated|shown (below|above)|graph (below|above)|table (below|above)` and no image is attached. Avoid false positives on "significant figures" (the sampled false positive was "Correct 0.007985 to three significant figures").
- [ ] **2.3.6** **Formatting inconsistency:** stems containing raw ASCII maths like `2^(√(2x + 1))`, `[(16/9)^((-3)/2) x 16^((-3)/4)]^(1/3)`, `32_four`, or ` x ` used as a multiply sign between numbers. Flag `needs_latex` (observed on the Indices topic page and the 2018 year page).
- [ ] **2.3.7** **Duplicates:** normalise each stem (lowercase, strip LaTeX/whitespace/punctuation) and hash it. Flag exact duplicates within a subject. Separately flag near-duplicates (Jaccard ≥ 0.9 on word 3-grams) as `near_duplicate`.
- [ ] **2.3.8** **Year counts:** any subject-year with more than 50 objective questions (observed: Maths 1998 = 60, 2007 = 53) gets a year-level flag in `reports/year_counts.csv`, with the IDs, to check for duplicates or a mixed-in paper (e.g. Nov/Dec merged into May/June). **VERIFY** with Moyo whether the bank mixes May/June and Nov/Dec sittings. If so, add a `sitting` field and show it ("WAEC 2007 Nov/Dec").

### 2.4 Review queue in the admin console

- [ ] **2.4.1** In the admin/contributor console (build a minimal one if it doesn't exist; **VERIFY** placement), add a "Question review" view:
  - Filters: subject, year, topic, flag type, `explanationOrigin`, `textVerified`, `answerVerified`, has user reports.
  - The question renders exactly as students see it (same widget), with flags listed and user reports shown.
  - Actions: edit stem/options/answer; mark text verified; mark answer verified; edit or write the explanation (sets `explanationOrigin='original'`); clear a flag with a reason; change topic tag.
  - Every save writes an audit entry in `questions/{id}/history/{autoId}`: `{ uid, at, before, after, reason }`.
- [ ] **2.4.2** Prioritise the queue by impact: answer-mismatch and recurring-decimal flags first, then user-reported, then questions from the most recent 10 years, then by topic frequency.
- [ ] **2.4.3** Wire "Report a problem" into the queue: `reportCount`, latest report text, and reporter uid (or "guest").

### 2.5 Student-facing honesty

- [ ] **2.5.1** On a question with `answerVerified=false` *and* an open `answer_mismatch_suspect` / `recurring_decimal_suspect` flag, show a small note under the answer: "This answer is being checked." Don't hide the question.
- [ ] **2.5.2** On the static page, add a "Last checked: <date>" line only when `answerVerified=true`.

**Acceptance:** `reports/question_flags.csv` exists and includes the 2018 Maths 0.612 question as `recurring_decimal_suspect` and `typo_suspect`. The review queue loads, edits write history, and student pages are unchanged except for the 2.5 notes.

Done notes:

---

## Phase 3 — Topic tagging fixes

**Why (observed):** Maths "Matrices and Determinants" and "Vectors in a Plane" have 0 past questions. "Transformation" and "Rational Numbers" have 1 each, "Functions and Relations" has 2. Meanwhile "Statistics" and "Triangles and Polygons" have 119 each. That suggests mis-tagging.

- [ ] **3.1** Script `scripts/report_topic_tags`: per subject, a table of topic → count of past questions, and the 10 most common keywords per topic (from stems). Write to `reports/topic_tags.md`.
- [ ] **3.2** Keyword rules per topic in `data/topic_keywords.yaml` (start with Maths). For example:
  - `matrices-and-determinants`: `matrix|matrices|determinant|\begin{pmatrix}|\begin{vmatrix}`
  - `vectors-in-a-plane`: `vector|\vec|column vector|magnitude of|unit vector`
  - `transformation`: `reflection|rotation|translation|enlargement|image of the point`
  - `rational-numbers`: `rational|irrational|terminating decimal|recurring`
  - `functions-and-relations`: `f\(x\)|function|domain|range|mapping|one-to-one`
- [ ] **3.3** Script `scripts/suggest_topic_retags` (dry run): for each question whose stem matches another topic's keywords much more strongly than its current topic's, output `id, currentTopic, suggestedTopic, matchedKeywords` to `reports/retag_suggestions.csv`. **No automatic retagging.** Suggestions go to the review queue (2.4) as `retag_suggested`.
- [ ] **3.4** **VERIFY** with Moyo whether questions can belong to more than one topic. If yes and the schema is single-topic, plan a `topics: []` migration, keeping `primaryTopic` for display and counts.
- [ ] **3.5** After retags are applied by humans, recompute the stats/aggregates (whatever v1 P1.3 built) and the topic frequency lines ("1 in N"). Confirm static pages regenerate.

**Acceptance:** retag report exists. After review, no Maths topic that WAEC regularly tests shows 0 past questions without a written reason in `docs/QUESTION_SOURCES.md`.

Done notes:

---

## Phase 4 — Accessibility: the question must be readable

**Why (observed):** In a drill, after turning on Flutter semantics, the accessibility tree read: `Back | 0 | Option A: 16 | Option B: 6 | Option C: 5 | Option D: 8 | Get a hint | Submit Answer | Study tools`. **The question stem ("Evaluate 4^(3/2)") and, after answering, the explanation are missing entirely.** The topic page's "Comes up in about 1 in 34…" line is also missing. A screen-reader user hears the options without the question.

- [ ] **4.1** Find the widget that renders a question stem with mixed text and maths (probably a `RichText`/`Text.rich` with `WidgetSpan`s wrapping `Math.tex`, or a custom layout). Find why it produces no semantics node. Likely causes: an `ExcludeSemantics`, a `CustomPaint`, or `WidgetSpan` children that drop semantics.
- [ ] **4.2** Build `lib/a11y/tex_to_speech.dart` (if v1 didn't): a pure function `String texToSpeech(String tex)`. It must cover at least:
  - `\frac{a}{b}` → "a over b"; `\dfrac`, `\tfrac`
  - `x^{2}` → "x squared", `x^{3}` → "x cubed", `x^{n}` → "x to the power n", `4^{\frac{3}{2}}` → "4 to the power 3 over 2"
  - `\sqrt{x}` → "square root of x", `\sqrt[n]{x}` → "n-th root of x" (e.g. "fifth root of")
  - `x_{1}` → "x sub 1", base subscripts `32_{four}` → "32 base four"
  - `\times` "times", `\div` "divided by", `\pm` "plus or minus", `\le`/`\ge`/`\neq` "less than or equal to"/"greater than or equal to"/"not equal to", `\approx` "approximately"
  - `\pi`, `\theta`, `\alpha`, `\beta`; `^\circ` → "degrees"; `\%` → "percent"
  - `\log_{a} b` → "log base a of b"; `\sin`, `\cos`, `\tan`
  - `\overline{abc}` or `\dot{}` recurring notation → "a b c recurring"
  - `\begin{pmatrix}`/`\begin{vmatrix}` → "matrix with rows: …" / "determinant of …"
  - Unknown commands: strip the backslash and read the name. Never crash.
- [ ] **4.3** Unit tests: at least 40 cases, using real stems pulled from the database (store them in `test/a11y/fixtures.json`), including every Indices stem on the static Indices topic page.
- [ ] **4.4** Wrap the whole stem in one node: `Semantics(label: stemToSpeech(question), container: true, child: ExcludeSemantics(child: <existing stem widget>))`. `stemToSpeech` joins text runs and `texToSpeech` of maths runs in order. Add an optional `spokenText` field on questions that overrides it.
- [ ] **4.5** Do the same for options: "Option A: 4 to the power 3 over 2, incorrect". Keep the existing correct/incorrect suffix. Do it for the explanation block ("Explanation: …"), the hint, and the exam review screen.
- [ ] **4.6** Images in questions get `Semantics(image: true, label: <alt text>)`. Use the same alt text the static site already generates.
- [ ] **4.7** Topic header block: make sure the strand ("Number and Numeration") and the frequency line are exposed as text.
- [ ] **4.8** Live region: when feedback appears ("Not quite. The answer is D."), announce it with `SemanticsService.announce(...)` or `Semantics(liveRegion: true)`.
- [ ] **4.9** Static site: in KaTeX output, make sure screen readers get the MathML (KaTeX `output: 'htmlAndMathml'` is fine) and the visible HTML is `aria-hidden`. KaTeX does this by default, so just check the generator didn't change it.
- [ ] **4.10** Manual test script in `docs/A11Y_TEST.md`: Chrome + NVDA (Windows) or TalkBack (Android Chrome). Enable semantics, open the Indices drill, answer one question, read the explanation. Moyo or a tester runs it.

**Acceptance:** after enabling semantics, the drill's accessibility tree contains the full spoken stem, all options with maths spoken, and the explanation after answering. Unit tests pass.

Done notes:

---

## Phase 5 — Practice questions: harder, varied, and weighted honestly

**Why (observed):** Every Maths topic has exactly 300 practice questions (12,900 total). The sampled ones are template fills: "Evaluate 4^(3/2)" and "Simplify x⁹ × x¹²", with distractors made by multiplying, subtracting, or adding one to the powers. They're correct, but much easier than real WAEC items in the same topic, e.g. "Solve 2⁵ˣ ÷ 2ˣ = ⁵√2¹⁰", "If 16 × 2^(x+1) = 4ˣ × 8^(1−x), find x". Students can reach high mastery on easy practice and then fail real papers.

- [ ] **5.1** From Phase 0.4, write `docs/PRACTICE_GENERATOR.md`: templates per topic, parameter ranges, distractor rules.
- [ ] **5.2** Add `difficulty: 1 | 2 | 3` to practice questions and templates:
  - 1 = single rule (x^a × x^b)
  - 2 = two steps or a negative/fractional index
  - 3 = WAEC-style: equations in the unknown, mixed bases, multiple laws
  Backfill existing templates (**VERIFY** the assignments with Moyo/contributors, since a template's difficulty is a judgement call).
- [ ] **5.3** Calibrate against real questions: for each topic, record which difficulty level the past questions mostly sit at. Use the existing answers: the % correct on past questions vs each practice template from real student data, if there's enough. Store `pastDifficultyProfile` per topic in the stats doc.
- [ ] **5.4** Template coverage report `reports/template_coverage.md`: per topic, the number of templates at each difficulty. Flag topics with no level-3 templates. **This is a content to-do list.** Don't write new templates; set up the structure so contributors can add them (template schema + validation + preview in the admin console).
- [ ] **5.5** Drill composition: a drill of N questions mixes difficulties by the student's mastery, e.g. low mastery 60/30/10 (levels 1/2/3), mid 30/40/30, high 10/30/60. Always include at least 30% real past questions when the topic has any. Put the mix in one config file.
- [ ] **5.6** Mastery weighting (find the formula from Phase 0.5): weight each answer by `difficulty` and by source (past question ×1.5). Cap mastery from practice-only answers at "Familiar". Only past questions and level-3 practice can move a student to "Proficient" or above. Keep it a pure function with unit tests.
- [ ] **5.7** Distractor quality: add a distractor rule type `misconception` with a label (e.g. `multiplied_indices`, `added_bases`) so the wrong answer can trigger targeted feedback: "You multiplied the indices. When multiplying powers with the same base, add them." Show it in feedback when the student picks that option. Templates without labels behave as now.
- [ ] **5.8** Variety: within one drill, never show two questions from the same template with the same structure back to back.

**Acceptance:** drills draw from multiple difficulties per the config. Mastery can't reach Proficient from level-1 practice alone (unit test). Misconception feedback shows for labelled distractors.

Done notes:

---

## Phase 6 — Static site: stand out in search

**Why:** The static pages exist but mostly duplicate text available elsewhere. Google needs something unique on each page to rank it.

- [ ] **6.1** Indexing policy — **VERIFY** with Moyo. Recommended: a question page is `index` only if `explanationOrigin == 'original'` **or** it has published examiner insight. Otherwise `<meta name="robots" content="noindex, follow">` and leave it out of the sitemap. Year, topic and subject index pages stay indexed. Implement as one function `shouldIndex(question)` in the generator. As explanations get written, pages join the index automatically on the next build.
- [ ] **6.2** Question number in URLs and titles if the data has it (Phase 0.2). New URL `/past-questions/waec/mathematics/2018/12/`. Keep the old ID URL as a 301 (generate a `firebase.json` redirects list or per-ID redirect stub pages). Title: `WAEC 2018 Mathematics Q12: <stem preview> | Paragon`. If no question number exists, **VERIFY** whether contributors can add it during review (2.4), and keep IDs until then.
- [ ] **6.3** Unique value blocks on each question page, shown only when the data exists (no empty boxes):
  - "Common mistake" (from the misconception labels in 5.7, for past questions with labelled options)
  - "What examiners said" (examiner insights, if built — v1 P7.1)
  - "How often this topic comes up": "Indices: about 1 in 34 WAEC Maths questions" (already computed)
  - "Similar questions": 3 links to other past questions in the same topic, nearest by year
- [ ] **6.4** Year pages: add "Sit this paper in Paragon" (deep link to `/waec/<subject>/setup` with that year preselected; add query param support `?from=2018&to=2018`).
- [ ] **6.5** Plain-text fallbacks in lists: year and topic pages currently show raw strings like `32_four`, `9/5C`, `2^(√(2x + 1))` **(observed)**. Render stems on list pages with KaTeX too, or with the same `stemToSpeech`-style plain text (`32 base four`). Pick whichever keeps the page under its size budget.
- [ ] **6.6** Size budget: each question page ≤ 60 KB HTML + shared CSS. Today ~19 KB **(observed)**, which is fine. Add a CI check.
- [ ] **6.7** Root `/`: the static HTML has a good `<title>` ("Paragon: free WAEC past questions and practice"), but Flutter replaces it with "Paragon" **(observed)**. Fix in Phase 7.1. Also make the pre-Flutter content in `index.html` a short real landing block (headline, 3 subjects with counts, link to past questions) styled to match. **VERIFY** the headline copy with Moyo.
- [ ] **6.8** Regenerate on content change: confirm the static build runs on publish (or nightly), and that sitemap `lastmod` per URL reflects the question's `updatedAt`, not the build date.

**Acceptance:** generator unit tests for `shouldIndex`. Sitemap contains only indexable question URLs. Value blocks render when data exists and are absent otherwise.

Done notes:

---

## Phase 7 — App polish

- [ ] **7.1** **Per-route browser titles.** Wrap each route's page in Flutter's `Title(title: ..., color: ..., child: ...)`, or set it in the router's builder. Patterns:
  - Home: `Paragon: free WAEC past questions and practice`
  - Course: `Mathematics | Paragon`
  - Topic: `Indices · Mathematics | Paragon`
  - Drill: `Practise Indices | Paragon`
  - Exam setup: `WAEC Mathematics paper | Paragon`
  - Live quiz: `Join a live quiz | Paragon`
- [ ] **7.2** **Home page empty left column (desktop) (observed).** At widths ≥ 1024 px the left ~60% of the home page is blank. Fill it with data-driven blocks, each hidden when empty:
  1. "Continue": last topic practised with mastery % and a "Keep practising" button
  2. "Next up": the top 3 topics by `topicFrequency × (1 − mastery)` ("Shortest path" from v1 P7.2)
  3. "Your mistakes": count + button to the mistakes notebook
  If all are empty (brand-new guest): a "Start here" card with the 3 most common Maths topics.
- [ ] **7.3** **Stats flash (observed).** Home tiles render "0" and "—" before real values load (seen as 0/— then 1/11). Show a skeleton until data arrives. Only show 0 when the loaded value is 0. Same for course mastery rings.
- [ ] **7.4** **Topic page:** "Practise now" in the Learn section and "Start practising" in the side card go to the same place. Keep one primary CTA per viewport. On desktop, keep the side card and turn the Learn-section button into a text link.
- [ ] **7.5** **Live quiz** (`/join`): add a host-side "Share join link" that copies `<domain>/join?code=ABC234` and pre-fills the code. Validate the code format (6 alphanumerics) client-side before calling the backend.
- [ ] **7.6** **Support page:** use the `hello@<domain>` constant (Phase 1.5). Add a `mailto:` with subject "Paragon for schools".
- [ ] **7.7** **Chemistry and Government in WAEC Prep** show "No past questions yet" **(observed)**. Add "Notify me" (reuse the coming-soon waitlist from v1 P1.5 if built).

Done notes:

---

## Phase 8 — Performance on mobile data

**Observed:** `main.dart.js` ≈ 1,034 KB compressed (4.65 MB decoded), no deferred `part.js` chunks. CanvasKit wasm fetched from `gstatic.com`. 11 KaTeX TTFs + 4 Space Grotesk TTF weights (~30 KB each compressed) + a Roboto woff2 from `fonts.gstatic.com` (62 KB) at startup. Total first-visit resources ~1.4 MB excluding CanvasKit.

Measure before and after in `docs/PERF.md`: Lighthouse mobile with "Slow 4G", plus transferred bytes for `/` and a drill.

- [ ] **8.1** **Deferred loading.** Use `import '...' deferred as x;` + `await x.loadLibrary()` for screens not needed on first paint:
  - exam mode + exam review
  - live quiz (host and join)
  - study tools (calculator, four-figure tables, scratchpad)
  - account/sign-in screens (Firebase Auth UI)
  - admin/review console (must never be in the main bundle)
  - support/about pages

  Show a small loading state while a library loads. Confirm `main.dart.js_*.part.js` files appear in the build and `main.dart.js` shrinks. Target ≥ 30% smaller.
- [ ] **8.2** **Roboto fetch.** Flutter falls back to Roboto from `fonts.gstatic.com` when a glyph isn't covered. Find which text triggers it (likely a widget without the app's Space Grotesk theme, or a missing glyph like `≠`, `√`, `⁵`). Fix the theme coverage, or bundle a subset font that covers those glyphs, so the 62 KB external fetch doesn't happen.
- [ ] **8.3** **Font formats and weights.** Check if Flutter web accepts WOFF2 for bundled fonts in this Flutter version. If yes, convert Space Grotesk to WOFF2. Either way, drop weights not used (grep `FontWeight.w` usage: if only 400/500/700 are used, drop SemiBold or Medium).
- [ ] **8.4** **KaTeX fonts.** Of the 11 still loaded: are `Main-BoldItalic`, `Math-BoldItalic`, `Size3`, `Size4` used by any question? Grep the question data for `\boldsymbol`, `\bm`, large delimiters (`\Bigg`, tall `\left(` around `\frac`). If not used, stop preloading them. `flutter_math_fork` loads them on demand if not declared up front — check its docs for the version in use.
- [ ] **8.5** **Renderer.** Build with `flutter build web --wasm` on a preview channel. Compare first-load bytes and time on a real low-end Android phone (Moyo tests). Keep whichever is better.
- [ ] **8.6** **CanvasKit hosting.** Serve CanvasKit from your own hosting (`--no-web-resources-cdn` or the equivalent for this Flutter version) with `Cache-Control: public, max-age=31536000, immutable`, so it shares HTTP/2 with the app and is cached long-term. Measure: keep whichever is faster.
- [ ] **8.7** **Cache headers.** Confirm hashed assets are `immutable` and `main.dart.js`/`flutter_bootstrap.js`/`index.html` are `no-cache` (`main.dart.js` is already `no-cache` **(observed)**).
- [ ] **8.8** **Service worker.** Check whether Flutter's service worker is enabled (deprecated in recent versions). If not, consider caching the app shell so repeat visits work on bad connections. **VERIFY** before adding one.

**Acceptance:** `docs/PERF.md` with before and after numbers. Main bundle ≥ 30% smaller. No `fonts.gstatic.com` request on first load.

Done notes:

---

## Phase 9 — Tests and CI for everything above

- [ ] **9.1** Unit tests: `texToSpeech`, `stemToSpeech`, recurring-decimal detector, answer-key sanity, duplicate hashing, `shouldIndex`, mastery weighting, drill composition.
- [ ] **9.2** Fixtures: a small JSON of real (anonymised) question docs, including the 2018 Maths 0.612 question, the 0.007985 significant-figures question, a diagram question, and an Indices question with ASCII maths. Used by the linters' tests.
- [ ] **9.3** CI on every PR: `flutter analyze`, `flutter test`, the linters in report mode on the emulator seed, static site build + size budget, Lighthouse CI on the preview URL. A preview channel deploy with the URL posted to the PR.
- [ ] **9.4** Nightly job: run `lint_past_questions` and `report_explanations` against production (read-only). Commit the reports to a `reports` branch, or upload them to a bucket, and post a summary of new flags and explanation coverage.

Done notes:

---

## Suggested order

| # | Phase | Why now | Size |
|---|---|---|---|
| 1 | 0 Confirm facts | Everything depends on it | S |
| 2 | 1 Custom domain | Gets harder every week Google indexes the old domain | S |
| 3 | 2 Data quality + provenance | Trust, legal clarity, and the base for search | L |
| 4 | 4 Accessibility | The question is invisible to screen readers | M |
| 5 | 6 Static site indexing policy + value blocks | Turns content work into search traffic | M |
| 6 | 3 Topic tagging | Fixes counts, frequency lines, mastery | M |
| 7 | 5 Practice difficulty + mastery weighting | Stops inflated mastery | M–L |
| 8 | 7 Polish | Quick wins | S–M |
| 9 | 8 Performance | Measurable, independent | M |
| — | 9 Tests/CI | Alongside every phase | — |

---

## Decisions Moyo needs to make

1. **Domain name**, and the support email address. (Phase 1)
2. **Question bank source and permission**: (a) rewrite explanations + verify text, (b) get permission, or (c) rebuild from original papers. (Phase 2.1.2)
3. Does the bank mix **May/June and Nov/Dec** sittings? Should students see which one? (Phase 2.3.8)
4. Can a question belong to **more than one topic**? (Phase 3.4)
5. **Difficulty levels** for existing templates. Who signs them off? (Phase 5.2)
6. **Indexing policy**: noindex question pages until they have an original explanation? (Phase 6.1)
7. **Landing headline** copy. (Phase 6.7)
8. Add a **service worker**? (Phase 8.8)
