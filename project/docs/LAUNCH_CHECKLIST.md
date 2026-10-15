# Launch checklist

The handover for the production-readiness waves (PLAN.md, waves A–K). The code is done
and on stacked PRs. What is left is deploying it, a few decisions, and a person clicking
through it. Tick each step as it is done.

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

1. **Clean first.** Plugins changed (`flutter_web_plugins` was added, `google_sign_in`
   removed):
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
   verification now runs **149** checks:
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
- [ ] `node tools/admin/jobs.js --job=dropprofile`: removes age, gender, country and
  state.
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
- [ ] Optional: a **custom domain**. If you add one:
  - pass `--origin=https://<domain>` to `build_static_site.js`;
  - update `og:url` and `og:image` in `web/index.html`;
  - update `appOrigin`'s fallback in `lib/core/web/browser_other.dart`.

## 5. Decisions still open

- [ ] **The WASSCE paper formats** (`lib/core/exam/exam_formats.dart`). They are marked
  unconfirmed, and the setup screen says so. Confirm or correct each subject, then set
  `verified: true`.
- [ ] **The tagline**: pick one of the five in `docs/COPY.md`.
- [ ] **Donations**: set `donateUrl` in `lib/core/config/support_config.dart` when
  there is somewhere to send them. Until then the button stays hidden.
- [ ] **Tighten the profile rule** to `school` and `classYear` only, *after*
  `--job=dropprofile` has run.
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
