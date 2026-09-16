# Project Paragon — Execution Plan
### Solo Founder · 5–10 hrs/week

---

## The Fundamental Rule

**Do not build the platform and create content in parallel.**

At 5–10 hrs/week, splitting attention between content creation and engineering means both are slow and mediocre. You sequence them. Content first. Platform second. Each phase has a specific output and a clear gate before moving on.

---

## Phase 0 — Resolve First (Week 1, ~3 hours)

Do these before anything else. They are blockers.

| Action | Time | Why It's First |
|---|---|---|
| Decide: WAEC-aligned content, or general science? | 0 hrs (decision) | Everything downstream depends on this |
| Choose your beachhead subject (Maths first — don't deviate) | 0 hrs (decision) | Topic selection is strategy |
| Get WAEC IP legal clarity (WhatsApp a Nigerian education lawyer, ₦10k–₦30k one-time) | 1 hr | Don't build a platform on legally uncertain content |
| Claim your handles: @paragonlearns on YouTube, TikTok, IG, Twitter/X | 30 min | Do this now before someone else does |
| Register your domain (paragonlearns.com or paragonng.com) | 30 min | ~$12/year. Vercel will host for free. |
| Set up WhatsApp Business account | 30 min | Your most important early distribution channel |

---

## Phase 1 — Content First (Weeks 2–16, ~4 months)

**Goal:** 10 published videos + 200 WhatsApp subscribers + proof that Nigerian students watch and share WAEC Maths content.

**Gate to Phase 2:** All three of the above must be true before you write a single line of platform code.

### Your Weekly Rhythm at 5–10 hrs/week

| Day | Activity | Time |
|---|---|---|
| Monday | Research WAEC topic. Pull 3 past questions. Write script. | 1.5 hrs |
| Wednesday | Generate voice-over (ElevenLabs). Build Canva assets. | 2 hrs |
| Friday | DaVinci Resolve assembly. Captions in CapCut. Export. | 2 hrs |
| Saturday | Upload + schedule YouTube. Post to TikTok. Send WhatsApp update. | 1 hr |

**Total: 6.5 hrs/week.** This fits the lower bound of your commitment. If you have more time, use it to build ahead — script the next 3 videos, not to add features.

### Video Production: Key Differences from Your Video Doc

Your production workflow (ElevenLabs + Canva + DaVinci + CapCut) is correct. Keep it. Change these specifics:

**Topic framing:** Every title = "[Specific technique] — WAEC [Topic] Explained"
- ❌ "How quadratic equations work"
- ✅ "Completing the Square — Step by Step (WAEC Maths)"

**Hook (first 5 seconds):** Make it urgency-based, not curiosity-based
- ❌ "Did you know that every GPS satellite uses Einstein's relativity?"
- ✅ "This question has appeared on WAEC Maths every year since 2015. Here's exactly how to solve it."

**Worked example:** Every video must show at least one actual WAEC past question being solved, step by step. Not an abstract explanation — a real question.

**Call to action:** End with: "Practice this on WhatsApp — join the link in my bio for a daily question."

### Publish Schedule: Sustainable Pace

Do not commit to 1 video/week from Day 1. Your workflow will be slow at the start.

| Period | Pace |
|---|---|
| Videos 1–3 | 1 video every 2 weeks (learning the workflow) |
| Videos 4–10 | 1 video per week (workflow is established) |
| Videos 11+ | Hold at 1/week. Add a second only if first is consistently taking < 4 hours. |

### WhatsApp Strategy (Runs in Parallel, Very Low Time Cost)

- Every day, send one WAEC Maths past question to your broadcast list
- Format: Question text → wait for replies → send worked solution at end of day
- This is < 30 minutes/day and builds a daily habit loop in students before the platform exists
- Use the 200 questions in your Notion question bank (built in Month 1)

**Building your question bank (Month 1, ~5 hours one-time):**
Pull 200 WAEC Mathematics past questions from 2015–2024 across the 20 topics in the PRD. Write brief worked solutions for each. Store in Notion with these fields: Year, Topic, Question text, Options (A–D), Answer, Worked solution, Difficulty (1/2/3). This becomes the Phase 2 platform content directly.

### Phase 1 Milestones

| Week | Milestone |
|---|---|
| 2 | Setup complete (accounts, tools, workspace) |
| 4 | Video #1 published. WhatsApp broadcast started. |
| 6 | Video #2 published. 20 WhatsApp subscribers. |
| 10 | Video #5 published. Workflow taking < 5 hrs/video. |
| 16 | Video #10 published. 200 WhatsApp subscribers. First school pilot begun. |

**Gate check at Week 16:**
- 10 videos published? ✅/❌
- 200 WhatsApp subscribers? ✅/❌
- Any organic sharing (students forwarding without being asked)? ✅/❌
- Average YouTube retention > 40%? ✅/❌

If 3 of 4 are yes: proceed to Phase 2.
If fewer than 3: spend 4 more weeks diagnosing and fixing content quality before touching engineering.

---

## Phase 2 — Minimal Platform (Weeks 17–36, ~4 months)

**Goal:** A working web platform where students can practice WAEC Maths questions, track a streak, and watch your videos alongside questions.

**Total engineering estimate:** 80–120 hours of actual coding. At 5–10 hrs/week with some hours still going to content: plan for 14–20 weeks.

**During this phase:** Drop video pace to 1 every 2 weeks. Platform build takes priority. Do not stop content entirely — momentum matters — but do not burn engineering hours on content.

### Build Sequence (in order — do not skip steps)

**Week 17–18: Foundation (10 hrs)**
- Initialize Next.js project with Tailwind CSS
- Connect Firebase Auth (Google + Email)
- Deploy to Vercel (should take 30 minutes)
- Commit: students can sign up and sign in

**Week 19–20: Content layer (10 hrs)**
- Convert your Notion question bank to JSON files (`/data/questions.json`)
- Build Topic index page: list of 20 WAEC Maths topics
- Build Topic page: list questions for a topic
- No auth required to view — anyone can browse
- Commit: students can browse questions without signing in

**Week 21–23: Question flow (12 hrs)**
- Build Question view page: question text, 4 options (radio buttons), Submit button
- On submit: reveal correct answer + worked solution
- If signed in: write attempt to Firestore (correct/incorrect, timestamp, topic)
- If not signed in: prompt to sign up after 3 questions (soft gate, not hard)
- Commit: core product works

**Week 24–25: Streak and progress (10 hrs)**
- Streak counter: Firestore Cloud Function checks if student attempted ≥5 questions today
- Update `currentStreak` on user document. Reset to 0 if no questions yesterday.
- Dashboard page: show streak, questions attempted this week, accuracy by topic
- Basic bar chart per topic (use Recharts — simple, lightweight)
- Commit: retention mechanic exists

**Week 26–27: Video integration (8 hrs)**
- Add `videoId` field to each topic in your data
- Embed YouTube IFrame at top of each Topic page
- Student watches video, then practices questions beneath it
- Commit: content and practice are unified

**Week 28–30: Polish + mobile (10 hrs)**
- Test everything on a real budget Android phone (Tecno or Infinix if you can get one)
- Fix layout issues at 360px viewport
- Reduce bundle size (next/image for all images, lazy load questions)
- Add basic loading states — students on 3G need to see progress
- Fix all the things that look fine on your laptop but break on mobile

**Week 31–32: About page + WhatsApp integration (6 hrs)**
- About page with WhatsApp join link (wa.me link) and YouTube subscribe button
- Add "Share your streak" button that opens WhatsApp with a pre-filled message
- This is free viral distribution — students share "I'm on a 7-day streak on Paragon"

**Week 33–36: Soft launch + fix bugs (12 hrs)**
- Share with your 3–5 school pilot contacts: "Try this and tell me everything that's broken"
- Fix bugs reported from real students on real devices
- Do not add features. Fix problems only.
- Commit: platform is ready for public launch

**Public launch: End of Week 36**
- Post to WhatsApp broadcast
- Post on all social channels
- Email your pilot school contacts asking them to share

### Phase 2 Content (Parallel, Reduced Pace)

| Week | Video |
|---|---|
| 20 | Video #11 |
| 22 | Video #12 |
| 24 | Video #13 |
| 26 | Video #14 |
| 30 | Video #15 |
| 34 | Video #16 |

6 videos in 18 weeks of platform building. Slow but doesn't kill momentum.

---

## Phase 3 — Add Intelligence (Months 10–18)

Only start Phase 3 if you have **200+ weekly active students** after Phase 2 launch.

Build in this order:

1. **Offline mode (PWA)** — Workbox service worker. Download a question pack (20 questions + solutions) for offline use. This is the most impactful feature for rural users and should be first in Phase 3.

2. **English Language** — second subject. Same platform structure. New content pipeline (videos + questions). Expand question bank.

3. **Basic spaced repetition** — Surface weak-topic questions more frequently. Simple rule: if wrong on a question twice, add it to a "Review" queue that appears at the start of each session. No complex SRS algorithm needed.

4. **Parent progress email** — Weekly email to an optional parent email address. Show streak, accuracy by topic, questions attempted. Use Resend free tier (100 emails/day).

5. **AI explanations** — Only if a funding source appears (grant, CSR) to cover API costs. Do not self-fund this at scale. Add as an optional "explain this differently" button, not as the default experience.

---

## The Master Timeline

```
MONTH 1       MONTH 2       MONTH 3       MONTH 4
[Phase 0] ----[Phase 1: Content + WhatsApp] --------------- [Gate check]
Setup         Video 1-2     Video 3-6     Video 7-10
              Q bank build  School pilot  200 WA subs?

MONTH 5       MONTH 6       MONTH 7       MONTH 8
[Phase 2: Build Platform] ---------------------------------- [Soft launch]
Foundation    Content layer Streak/dash   Mobile polish
Auth + deploy Questions     Video embed   School pilots test

MONTH 9       MONTH 10-18
[Fix + launch] [Phase 3: Intelligence — only if 200 WAU]
Public launch  Offline + English + Spaced repetition
```

---

## What To Do This Week (Your First Week)

In order:

1. **Decide** — WAEC-aligned content, Maths first. Write it down. Non-negotiable.
2. **Claim** — @paragonlearns on YouTube, TikTok, Instagram, Twitter. Do it before someone else does.
3. **Register** — paragonlearns.com or paragonng.com (~$12/year on Namecheap)
4. **Set up WhatsApp Business** — get the broadcast list ready before your first video
5. **Research** — Pull the first 3 WAEC Maths past questions on Completing the Square (2020, 2021, 2022). Write your first script using those exact questions.
6. **Start Phase 1 setup** from your production doc (accounts, software, voice clone) — you have this already

Do not start building the platform yet. Do not design a logo. Do not think about Phase 3. Ship video #1.

---

## The One Rule That Keeps This Alive

**Publish something every two weeks, no matter what.**

Not a perfect video. Not a complete product. Something. A video, a WhatsApp question pack, a platform feature. The projects that die are the ones that wait until everything is ready before showing anyone anything. Nothing is ever ready. Ship it.

---

*Project Paragon Execution Plan — May 2026 — Solo Founder Edition*
