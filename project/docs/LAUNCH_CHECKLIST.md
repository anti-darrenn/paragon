# Launch checklist

The handover for the production-readiness waves (PLAN.md, waves A–K). The code is done
and on stacked PRs. What is left is deploying it, a few decisions, and a person clicking
through it. Tick each step as it is done.

## 0. The 2026-10-17 feature round

Six stacked PRs. Merge them oldest first, each after CI is green.

| PR | What | Deploy |
| --- | --- | --- |
| #65 | LaTeX everywhere, Normal/LaTeX editor, audit flags clear on fix | rules, then hosting; `build_static_site.js --refresh` once |
| #66 | Students rate difficulty | rules, then hosting |
| #67 | The founder's question bank and vetting | **see below; this empties the site until you vet** |
| #68 | Study tab: custom quiz, flashcards, tools | rules (decks, `quiz` attempts), then hosting |

**The vetting PR, in this order:**
1. **Grant yourself the founder claim**, on an account that is already admin:
   `node tools/admin/set_founder_claim.js --email=<you> --grant`. Then sign out and in.
2. **Deploy the indexes first**, and wait until the console shows them **Enabled**
   (several minutes): `firebase deploy --only firestore:indexes`. Every student query
   now filters `vetted == true`, and without its index each one fails.
3. **Deploy the rules**, then run `node tools/admin/verify_rules.js`.
4. **Deploy hosting.** From this moment students see **no questions** until you vet
   some. That was your decision ("everything pending, enforced on deploy").
5. **Recount** so courses stop advertising questions they cannot serve:
   `node tools/admin/jobs.js --job=counts --apply`, then `check_counts.js`.
6. **Rebuild the static site** with `build_static_site.js --refresh`. It publishes
   vetted past questions only, so `/past-questions/` pages disappear until you vet
   (search engines will drop them; they return as you vet).
7. **Vet.** Open Studio → Question bank, pick a subject, and press **Vet** on a topic.
   "Approve & next" (Ctrl+Enter) saves any edits and moves on. Counts refresh nightly.

## 1. Merge the stack, in order

Each PR is based on the one before it. Merge them oldest first and delete each branch as
it merges; GitHub then retargets the next PR to `main` by itself. Check that CI is green
on each before merging. The `content` job stays red until step 3 is done; it reports
live data and does not block a merge.

| PR | Wave | What |
| --- | --- | --- |
| #29 | launch 1 | Launch safety: read meter, quota banner, error reporting, feedback |
| #30 | A | Trust: placeholders, provenance, split counts, guest policy, waitlist |
| #31 | B | Real URLs, return-to after sign-in, leave guard, share |
| #32 | C | Static past-question pages, sitemap, robots |
| #33 | D | Lighter first visit (fonts, logo), skeletons |
| #34 | E | Spoken maths, contrast, exam keyboard/flags/resume, "Full paper" |
| #35 | F | CI, rules on the emulator, funnel analytics |
| #36 | G | Weekly goal, grade estimate, shortest path, challenge links, taster |
| #37 | H | Live quiz rooms |
| #38 | I | Examiner insights, bylines, theory, question importer |
| #39 | J | Support, traction metrics, profile narrowed, terms bumped |
| this | K | This checklist and the handover docs |

## 2. Deploy

Run everything from `project/`.

1. **Clean first.** Plugins changed (`flutter_web_plugins` and `firebase_app_check`
   were added, `google_sign_in` removed):
   ```powershell
   flutter clean; flutter pub get; flutter build web --release
   ```
2. **Check the plugin registrant**, which once shipped without the YouTube player. CI
   checks this too. The command should print a number of at least 2:
   ```bash
   grep -c "WebYoutubePlayer\|SharedPreferencesPlugin" .dart_tool/flutter_build/*/web_plugin_registrant.dart
   ```
3. **Post-build:** the font trim plus the static pages. Run `npm install` in
   `tools/site` once first.
   ```powershell
   node tools/site/build_static_site.js
   ```
4. **Rules and indexes.** Deploy them, then verify against the live project. The
   verification now runs **159** checks (security sweep, 2026-10-16):
   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes
   node tools/admin/verify_rules.js
   ```
5. **Hosting:**
   ```powershell
   firebase deploy --only hosting
   ```
6. **Check in a browser.** Open the live site and confirm that the address bar shows
   real paths, not `#/`, and that an old `/#/courses` link lands on `/courses`.

## 3. Data steps

Every script is a dry run first. Read its output, then re-run it with `--apply`.

- [ ] `node tools/admin/jobs.js --job=counts`. It splits past and practice counts and
  fixes the 14,602 vs 14,616 mismatch. Then run `node tools/admin/check_counts.js`,
  which should print "All … agree".
- [ ] Unpublish **`test2`** and **`test_article`** in the studio (Mathematics topic
  `sGeqO2FDw79otnkz3tz6`). Then run `node tools/admin/content_lint.js`, which should
  print "All clean".
- [x] `node tools/admin/jobs.js --job=dropprofile`: removes age, gender, country and
  state. Checked 2026-10-16: 0 of 44 users held one, so there was nothing to remove.
- [ ] `node tools/admin/jobs.js --job=insights`. It does nothing until an insight is
  published. After that, the nightly run keeps the flags current.
- [ ] In the studio, run **"Rebuild all subjects"**, then confirm a production
  `subjectIndex` document has `lessons`.
- [ ] Run `cd tools/admin && npm install`, which picks up `katex` for the lint and the
  importer.

## 4. Settings only you can change

- [ ] Grant the service account **Monitoring Viewer**, so that `usage.js` can record
  daily reads and writes.
- [ ] Set **`NOTIFY_FROM`** to a domain sender (Resend). Until it is set, writer emails
  go to `NOTIFY_TO`, and nothing can email waitlisted students.
- [ ] Submit `https://<domain>/sitemap.xml` in **Google Search Console**.
- [ ] Optional: a **custom domain** (audit E10). **`docs/DOMAIN_SETUP.md` is the full
  procedure**, including the redirect from the old address. In short, the code side is one line:
  `kSiteOrigin` in `lib/core/config/site_config.dart`. The static build reads it and
  rewrites the built `index.html`'s canonical and share tags to match. Then:
  - add the domain in the Firebase console (Hosting → Add custom domain) and set its
    DNS records;
  - add it under Authentication → Settings → Authorised domains, or Google sign-in
    fails on it;
  - change `contactEmail` and `contactEmailCc` in `legal_documents.dart` to domain
    addresses (audit G2). The static privacy page follows on the next build.
  - Submit the new sitemap in Search Console.
- [x] **Content-Security-Policy** (audit G1): enforced after a clean preview run on
  2026-10-16. A new third-party host must be added to it in `firebase.json`. The
  security sweep found it reached only `/` until its path pattern was fixed (see below).
- [ ] **Deploy the Firestore rules** (`_meta/contentAudit`), then run
  `node tools/admin/verify_rules.js`.
- [ ] **Write to WAEC** about the past questions (audit G4): `docs/WAEC_OUTREACH.md`.
- [ ] **Have the privacy policy read** by someone who knows the NDPA (audit G3). It now
  names the Act, the NDPC and the right to complain, and asks under-18s to check with a
  parent.

### Security (sweep of 2026-10-16, `docs/audit/SECURITY_2026-10-16.md`)

- [ ] **Before deploying**, run `node tools/admin/security_audit.js` (read-only). It
  should end "Nothing needs attention."
- [ ] **After deploying hosting**, check that the headers reach every path, not only `/`:
  ```bash
  curl -sI https://paragon-hq.web.app/welcome | grep -i "content-security\|x-frame"
  ```
  Then open a lesson video from a fresh tab on `/` and confirm it plays. Under the old
  policy it could not.
- [ ] **App Check** (the guard against a script spending the day's quota):
  1. Firebase console → App Check → Apps → the web app → register with
     **reCAPTCHA Enterprise**. Create the key in Google Cloud → reCAPTCHA (website
     key, domain `paragon-hq.web.app`, plus a custom domain if there is one).
  2. Put the site key in `kRecaptchaEnterpriseSiteKey`
     (`lib/core/config/app_check_config.dart`), then build and deploy hosting.
  3. Watch App Check → Firestore → **verified requests** for about a week. When nearly
     every request is verified, press **Enforce** for Cloud Firestore. Until then
     nothing is refused.
  4. Running the app locally against production after enforcement: copy the debug
     token from the browser console into App Check → Manage debug tokens.
- [ ] **Branch protection** on `main` (Settings → Branches): require a pull request and
  the `app`, `node` and `rules` checks. The repository is public, and `main` currently
  accepts any push.
- [ ] **Restrict the API keys** (Google Cloud → APIs & Services → Credentials):
  - the browser key: HTTP referrers `paragon-hq.web.app/*`,
    `paragon-hq.firebaseapp.com/*`, `localhost/*` (and a custom domain);
  - the Android key: package name plus SHA-1.
  They are public by design; a restriction stops another site from using them.
- [ ] **Authentication → Settings**:
  - turn on **email enumeration protection**;
  - remove any authorised domain that is not yours;
  - optionally raise the **password policy** to 8 characters, to match the app.
- [ ] **`NOTIFY_TO` as a secret**: GitHub → Settings → Secrets and variables → Actions.
  Create the secret `NOTIFY_TO` with the same value, then delete the variable. Variables
  are printed in the public Actions logs.
- [ ] **Android, before it ships**: a real signing key (release builds use the debug key)
  and an application id other than `com.example.paragon`. Re-download
  `google-services.json` for the new id. App Check on Android then needs Play Integrity.
- [ ] **Decide: external lesson figures.** A lesson figure can be any `https:` image, so
  its host learns the IP address of each student who opens the lesson. Either keep it,
  or allow-list hosts (or uploads only) in `lesson_doc.dart`.

**Batch app deploys** (audit F4). Every deploy that changes the app makes returning
students download `main.dart.js` again (4.75 MB unpacked, 1.4 MB gzipped). Changes to
the static pages alone don't. So ship app changes together, and rebuild the static
pages (`build_static_site.js`) as often as you like.

## 5. Decisions still open

- [x] **The WASSCE paper formats** (`lib/core/exam/exam_formats.dart`). Checked
  2026-10-16: question counts against each WAEC syllabus, times against WAEC's May/June
  2026 timetables. Re-check when WAEC publishes a new timetable.
- [ ] **The tagline**: pick one of the five in `docs/COPY.md` and put it in `kTagline`
  (`lib/core/config/site_config.dart`). Until then it reads "Free WAEC prep. Still a
  work in progress."
- [ ] **Donations** (the Khan-style card on `/support`; hidden until a link is set).
  1. Sign up at paystack.com and finish the business verification (an individual
     "starter business" works; it needs your BVN and an ID). Add the bank account the
     money goes to.
  2. **One-time:** Paystack → Payment Pages → New page → One-time payment. Make one page
     per amount (₦1,000, ₦2,500, ₦5,000, ₦10,000; fixed amount), plus one with the amount
     left blank so the donor types it ("Other"). Name them "Donate to Paragon".
  3. **Monthly (optional):** Paystack → Plans → create a monthly plan per amount, then
     Payment Pages → New page → Subscription, one per plan.
  4. Copy each page's link into `kDonateLinks` in `lib/core/config/support_config.dart`.
     A choice whose link stays `null` is hidden, so you can start with only some.
     Change the amounts there too if you like.
  5. Build and deploy hosting. Try one ₦100 test page first if you want to see a payment
     land, then delete it.
- [ ] **The profile rule** is tightened to `school` and `classYear` only (PR
  `chore/step9-reconcile`). After merging, deploy it:
  `firebase deploy --only firestore:rules`, then `node tools/admin/verify_rules.js`.
- [ ] **Bylines**: run `node tools/admin/set_contributor.js --email=… --name=… --role=…`
  for each writer who agrees to be credited.

## 6. Click through it yourself

Nobody has driven these flows in a browser yet, because no browser was connected for
the agent. Do it on the deployed site, at **phone width and desktop width**, in **dark
and light**, ideally on a budget Android phone on mobile data.

**Guest first visit**
- [ ] Open `/` signed out. The welcome page appears, and nothing else flashes first.
- [ ] Tap "Try 5 questions now". You get 5 questions with instant feedback, and the end
  offers the topic.
- [ ] Reload. You land on Home, not the welcome page.
- [ ] Topic page: lessons are shown, or "on the way" when there are none. The
  "Practise now" button and the topic test both work.
- [ ] Pass a topic test, then drill. The drill summary asks you to save your score.
- [ ] Use "Make an account" (Google). Your progress is still there afterwards.

**Links**
- [ ] Paste `/subject/<id>/course/topic/<id>` into a fresh signed-out tab. You are
  asked to sign in, and "Browse as guest" brings you back to that topic.
- [ ] Share a topic from a phone. The WhatsApp sheet opens.

**WAEC exam**
- [ ] Setup defaults to "Full paper" and says the length isn't checked yet.
- [ ] Answer with the keyboard (A–E, ←/→), and flag with F.
- [ ] Close the tab mid-exam. You get "Leave site?".
- [ ] Reopen setup. "Resume" restores your answers, flags and clock.
- [ ] Submit. The summary shows the answered, unanswered and flagged counts.
- [ ] The result shows the grade estimate, plus your practice estimate if you have one.
- [ ] Review works, and so does the history.

**Plan**
- [ ] Set a weekly goal and an exam date. Home's "This week" card updates, and `/plan`
  shows each subject's estimate and shortest path.

**Challenge**
- [ ] After a drill, "Challenge a friend" sends to WhatsApp.
- [ ] A second browser (signed out) opens the link, plays as a guest, and sees both
  scores.

**Live quiz**
- [ ] One account hosts on a laptop. Two guest phones join with the code.
- [ ] Play 5 questions. The answer count goes live, the reveal shows the split, and the
  podium appears.
- [ ] A phone that reloads mid-game is still in.

**Accessibility**
- [ ] With TalkBack or NVDA, a question with a fraction is read with the fraction
  ("nine fifths"). The exam strip announces "Question 3, answered, flagged".

**Studio**
- [ ] Publishing a lesson titled `test` is refused.
- [ ] An examiner insight with copied report text is refused. A reworded one publishes.
- [ ] Traction shows yesterday after the first nightly run.

**Support and legal**
- [ ] `/support` opens signed out.
- [ ] A signed-in account is asked to accept the 2026-10-15 terms once.

**Light mode**
- [ ] Repeat a few of the above in light mode. It has not been reviewed in a browser
  before.

## 7. Measure on the final build

- [ ] Lighthouse (mobile, Slow 4G) on `/` and a past-question page. Record LCP and
  transfer in `docs/audit/PERF.md`.
- [ ] Run the Rich Results Test on a past-question page; the `Quiz` markup should be
  accepted.
- [ ] A day after launch, check the studio's Traction and Daily quota panels against
  `docs/audit/QUOTA.md`.
