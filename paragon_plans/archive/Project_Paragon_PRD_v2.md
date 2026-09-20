# Project Paragon — PRD v2
### Solo Founder · Passion Project · 5–10 hrs/week · No External Funding

> **One sentence:** A free, mobile-first YouTube channel + lightweight web platform where Nigerian SS1–SS3 students practice WAEC past questions with short explainer videos, basic progress tracking, and a daily streak — built by one person, shipped in stages.

---

## ⚠ What Changed From v1

The original strategy document described a product that requires a 4–6 person team, $150k in funding, and 18 months of full-time work. You have none of those things. This PRD strips everything down to what one person can actually build and sustain at 5–10 hours per week. Features are sequenced so each phase produces something real that students can use — not a half-built product waiting for future phases.

---

## 0. The One Decision You Must Make First

**Is Paragon a general science channel, or a WAEC/JAMB prep tool?**

Your video workflow doc uses GPS and password hashing as examples. Those are good videos — but they are not what a WAEC candidate needs 3 months before their exam. If the content is general science, Paragon competes with Kurzgesagt, MinutePhysics, and Crash Course — global brands with millions of subscribers and years of head start. If the content is WAEC-aligned, Paragon has no serious competitor doing it well. The answer is: **WAEC-aligned content first, always.**

Every video topic must map to a specific WAEC syllabus objective. GPS does not. Quadratic Equations, Laws of Indices, Organic Chemistry nomenclature, Reading Comprehension strategies — these do.

---

## 1. What You're Building (And What You're Not)

### You Are Building:
- A **YouTube channel** (Paragon) publishing short explainer videos aligned to WAEC/JAMB syllabus topics
- A **lightweight web platform** (paragonlearns.com or similar) where students can watch videos, attempt past questions, and track a streak
- A **WhatsApp broadcast** distributing a daily past question to subscribers

### You Are Not Building (Yet):
- AI-powered explanations (cost + API complexity — remove from MVP entirely)
- Spaced repetition engine (requires significant engineering — Phase 3)
- Offline PWA (important but complex — Phase 2)
- Teacher dashboard (Phase 3)
- Parent email reports (Phase 2)
- Admin CMS with workflow (use Firebase console + simple upload form instead)
- Native Android app (Year 2 if ever)
- Multiple subjects simultaneously (one subject at a time)

### Why This Scope Is Correct:
At 5–10 hrs/week, you have roughly 250–500 hours per year after accounting for life. The platform MVP as described in PRD v1 requires approximately 350–500 engineering hours alone — before a single video is made. You must sequence content and platform, not run them in parallel, or both will be half-finished.

---

## 2. North Star Metric

**Weekly Active Students** — the number of unique students who attempt at least one practice question per week.

Everything else (videos, questions, streaks, WhatsApp) exists to move this number.

---

## 3. Target User (unchanged from v1, but simplified)

**Primary:** Nigerian SS2 and SS3 students (ages 15–18), urban and peri-urban, preparing for WAEC. Device: budget Android phone (Tecno/Infinix). Connectivity: 3G/4G, inconsistent.

**Secondary:** JAMB candidates (post-SS3) in intensive exam prep mode.

**Not primary right now:** JSS students, parents, teachers. Serve students first. Everything else is Phase 2+.

---

## 4. The Beachhead: WAEC Mathematics

Start with Mathematics only. No other subject at launch.

**Why Maths:**
- Highest WAEC failure rate (consistently 40–60% nationally)
- Highest student urgency and search intent
- Largest past question bank (2000–2024 ≈ 2,400 questions)
- Most visual — diagrams, graphs, and worked solutions suit your video format well
- Students with Maths problems have them daily, not just before exams — drives repeat visits

Add English Language in Phase 2 only after Maths content is established.

---

## 5. MVP Feature List

### Phase 1 MVP — Content-First (Months 1–4)
*Ship this before writing a single line of platform code.*

| Feature | Description | Why It's In MVP |
|---|---|---|
| YouTube channel | 1 short video per week, WAEC Maths topics, 60–90 seconds | Content is the product at this stage |
| WhatsApp broadcast | Daily past question sent to subscribers. Reply to see answer/worked solution | Zero engineering. Highest reach per hour invested |
| Notion-based question bank | Internal spreadsheet of 200 curated past questions with worked solutions | Foundation for the platform later |
| Channel website (placeholder) | Single static page: channel description, WhatsApp join link, YouTube subscribe link | Stakes the name and gives WhatsApp a landing page |

**What this proves:** Do students watch WAEC Maths explainers? Do they join the WhatsApp broadcast? Do they share it? If yes on all three — you have demand. Build the platform. If no — you learn this in Month 2 instead of Month 12 after building an engineering project.

---

### Phase 2 MVP — Minimal Platform (Months 4–8)
*Start this only after publishing 10+ videos and reaching 200+ WhatsApp subscribers.*

| Feature | Description | Notes |
|---|---|---|
| Past Questions Bank | 200 WAEC Maths past questions (2000–2024), organized by topic | Static JSON files in Next.js — no database needed at this scale |
| Question viewer | Show question, student selects answer, reveal worked solution | No AI. Worked solutions are written by you. |
| Basic Auth | Email + Google sign-in via Firebase Auth | Required for streak tracking only |
| Daily Streak | Counter increments if student attempts ≥5 questions that day | Simple Firestore write. High retention value. |
| Progress by topic | Show accuracy % per topic (Algebra, Geometry, etc.) | Motivates targeted practice |
| Mobile-first UI | Dark background (#0D1117), Montserrat, 360px-first layout | Match the YouTube channel aesthetic |
| Video integration | Embed your YouTube video for each topic alongside its questions | Students watch the explanation, then practice |

**What this proves:** Do students use the platform daily? Does the streak work as a retention mechanic? Which topics have the worst accuracy rates (tells you what to video next)?

---

### Phase 3 — Add Intelligence (Months 8–16)
*Only if Phase 2 has active weekly users.*

| Feature | Description | Notes |
|---|---|---|
| Offline mode (PWA) | Service worker + download question pack (20 questions) | Workbox library. Required for rural users. |
| Spaced repetition | Show weak-topic questions more frequently | Simple algorithm: if wrong twice, resurface after 3 days |
| NECO past questions | Same format, NECO syllabus | Content work more than engineering work |
| English Language | Second subject, same structure | New content pipeline |
| Parent progress email | Weekly email to parent with topic accuracy summary | Firebase + Resend free tier |
| WhatsApp integration | Share streak/results via WhatsApp Web link | No API needed — use wa.me deep link |

---

## 6. Content Strategy (WAEC-Aligned Topics)

### Video Format (from your production doc — keep it, change the topics)
Your ElevenLabs + Canva + DaVinci Resolve workflow is correct. Keep it. Change the topics.

**Every video must:**
1. Name the WAEC topic explicitly in the first 5 seconds
2. Solve one specific WAEC question type, not a general concept
3. End with a prompt: "Try a past question on this — link in bio"

**Wrong topic framing:** "How quadratic equations work" (general, Kurzgesagt style)
**Right topic framing:** "How to solve ANY quadratic by completing the square — WAEC 2022 Q4 explained"

The hook is not curiosity ("did you know…"). The hook is urgency ("this exact question type comes up every year").

### Topic Sequence (First 20 Videos)
Map each video to a specific WAEC topic. Suggested order (highest failure rate first):

| # | Topic | WAEC Frequency |
|---|---|---|
| 1 | Completing the square | Every year |
| 2 | Indices — laws and simplification | Every year |
| 3 | Logarithms — change of base, solving equations | Every year |
| 4 | Simultaneous equations (elimination + substitution) | Every year |
| 5 | Circle theorems — the 6 you must know | Every year |
| 6 | Surds — rationalising the denominator | High |
| 7 | Trigonometry — SOHCAHTOA applied | Every year |
| 8 | Sequence and series — AP and GP | High |
| 9 | Matrices — 2×2 determinant and inverse | High |
| 10 | Probability — combined events | High |
| 11 | Statistics — mean, median, mode from frequency table | High |
| 12 | Functions — domain, range, composite | High |
| 13 | Algebraic fractions — LCM method | High |
| 14 | Sets — Venn diagrams with 3 sets | Every year |
| 15 | Vectors — addition, subtraction, magnitude | Medium-High |
| 16 | Mensuration — surface area and volume (cone, sphere) | Every year |
| 17 | Linear inequalities — number line and graph | High |
| 18 | Modular arithmetic | Medium |
| 19 | Coordinate geometry — gradient and equation of line | Every year |
| 20 | Differentiation — basic rules and rate of change | High |

**Rule:** Before you script each video, pull 3 actual WAEC past questions on that topic (from 2018–2024). Your video should explain exactly how to solve those question types — not the concept in the abstract.

---

## 7. Tech Stack

Keep this boring and small. Complexity is a solo-founder killer.

| Layer | Technology | Why |
|---|---|---|
| Frontend framework | Next.js (App Router) | You know frontend/fullstack. Excellent static generation for questions. |
| Hosting | Vercel | Free tier is sufficient for Phase 1-2. Zero DevOps. |
| Auth | Firebase Authentication | Google + Email. Free tier. Easy to implement. |
| Database | Firestore | Free tier handles Phase 1-2 easily. Offline persistence built-in for Phase 3. |
| Past questions data | JSON files (Phase 1-2), Firestore (Phase 3) | Start with static data. No backend complexity until you need it. |
| Video hosting | YouTube (your own channel) | You control the channel. Embed via YouTube IFrame API. |
| Email | Resend free tier | 100 emails/day free. Enough for Phase 2 parent reports. |
| Analytics | Firebase Analytics | Free. Already in your stack. |
| CDN / Media | Vercel Edge / built-in | No separate CDN needed at this scale. |
| Styling | Tailwind CSS | Fast to build with. Matches your production constraints. |

**What you're not using in Phase 1-2:**
- Any AI API (remove from MVP — add in Phase 3 if funding appears)
- Cloudflare R2 (unnecessary at this scale)
- Any paid service

---

## 8. Non-Functional Requirements (Simplified)

| Requirement | Target | Rationale |
|---|---|---|
| Page load (3G) | < 3 seconds | Nigerian 3G average is 5–8 Mbps |
| Initial JS bundle | < 100KB gzipped | Low-end Android (2GB RAM) |
| Image format | WebP, max 60KB | Data cost |
| Mobile viewport | 360px primary | Budget Android screen reality |
| Auth friction | < 3 taps to create account | Students abandon long sign-up flows |
| Offline (Phase 2+) | Core questions loadable offline | Service worker + Firestore offline persistence |

---

## 9. Data Model (Phase 2 Platform)

Keep the schema simple and extend it in Phase 3.

```
users/{uid}
  - email: string
  - createdAt: timestamp
  - currentStreak: number
  - lastActiveDate: string (YYYY-MM-DD)
  - topicAccuracy: { [topicId]: { correct: number, total: number } }

questions/{questionId}
  - year: number (e.g. 2022)
  - topic: string (e.g. "completing_the_square")
  - questionText: string
  - options: string[] (A, B, C, D)
  - correctAnswer: string (A/B/C/D)
  - workedSolution: string (markdown)
  - videoId: string (YouTube video ID for this topic)
  - difficulty: 1|2|3

attempts/{uid}_{questionId}
  - userId: string
  - questionId: string
  - selectedAnswer: string
  - isCorrect: boolean
  - timestamp: timestamp
```

This schema handles streak tracking, topic accuracy, and question history. It's the minimum needed for the Phase 2 platform. Spaced repetition (Phase 3) adds a `nextReviewDate` field to attempts.

---

## 10. Screens (Phase 2 Platform)

You need exactly 7 screens for the Phase 2 MVP. Nothing more.

| Screen | Purpose |
|---|---|
| Home | Topic list with accuracy % shown for logged-in users. YouTube embed of latest video. |
| Topic page | List of 20–30 past questions for a topic. Video for this topic embedded at top. |
| Question view | Single question, 4 options, submit → reveal answer + worked solution. |
| Dashboard | Current streak, questions attempted this week, accuracy by topic (simple bar chart). |
| Sign in/up | Email + Google. Minimal. One screen. |
| About | What Paragon is, WhatsApp join link, YouTube subscribe button. |
| 404 | Something on-brand. |

No onboarding flow. No profile page. No settings. No notifications. Students care about one thing: practicing questions. Get them there in two taps.

---

## 11. WAEC Past Questions — Copyright

**This needs to be resolved before launch, not after.**

WAEC questions are widely reproduced across Nigerian educational websites. Enforcement has historically been minimal. However:

1. Get a Nigerian IP/education lawyer (many work on single consultations for ₦10,000–₦30,000) to advise specifically on reproducing WAEC past questions for a nonprofit educational platform
2. Alternatively, pursue a formal letter to WAEC requesting educational use permission — as a nonprofit this may be granted with no objection
3. Do not launch the platform at scale with questions before this is resolved

Your YouTube videos explaining WAEC topics have no copyright issue — you're teaching the concepts, not reproducing the exam paper.

---

## 12. Distribution (No Budget)

In order of time-investment vs. payoff:

| Channel | Action | Time to first result |
|---|---|---|
| WhatsApp broadcast | Set up WhatsApp Business, post join link everywhere, send daily question | Week 1 |
| 3–5 school pilots | Visit or call SS2/SS3 class teachers at Lagos private schools. Ask them to share with students for 1 month. | Week 2–4 |
| YouTube SEO | Title every video: "[Topic] — WAEC [Year] Q[Number] Solved" | Compound over months |
| TikTok repost | Repost every Short to TikTok with Nigerian student hashtags | Week 1 |
| Nigerian education Facebook groups | Share videos in groups like "WAEC 2025 Students" (hundreds of thousands of members) | Week 2 |

**Do not:** Run paid ads, partner with influencers before you have 20 videos, or spend time building a social following before you have consistent content.

---

## 13. Analytics You Actually Care About

At your stage, you need three numbers. That's it.

1. **WhatsApp broadcast subscribers** — growing weekly?
2. **YouTube 7-day view count** — trending up video over video?
3. **Platform weekly active students** (Phase 2) — do students return?

If all three are growing slowly but consistently: keep going. If any is flat for 6 weeks: something is wrong with either content quality, topic selection, or distribution. Diagnose and fix before adding features.

---

## 14. What Success Looks Like at Each Phase

| Milestone | Definition | Approximate Timeline |
|---|---|---|
| Proof of content | 10 videos published, 100 WhatsApp subscribers, comments asking for more | Month 3 |
| Proof of demand | 500 WhatsApp subscribers, students sharing videos without being asked | Month 5 |
| Platform launch | 200 registered users, 50 weekly active students | Month 8 |
| Early traction | 1,000 registered users, 200 weekly active | Month 12 |
| Channel growth | 5,000 YouTube subscribers | Month 12–18 |

These numbers are modest. They are also realistic for a solo founder working part-time with no marketing budget. Do not benchmark against funded startups.

---

## 15. The Sustainability Question (For a Passion Project)

You said you're not collecting funding. That's fine for Phase 1. It becomes a constraint in Phase 2 when you have real engineering work, infrastructure costs, and content production overhead hitting simultaneously.

**Realistic cost to operate at Phase 2:**
- Vercel / Firebase: ₦0 (free tiers cover Phase 1-2 easily)
- AI API: ₦0 (not in MVP)
- Domain: ~$12/year
- Your time: 5–10 hrs/week

The only real cost is your time. That's sustainable as a passion project indefinitely. What's not sustainable: committing to a 1-video-per-week schedule while also solo-engineering a platform. That's 2 part-time jobs. Sequence them.

**When to seek funding:** When you have 200+ weekly active students and a clear gap between what you can build alone and what they need. At that point, you have traction data to back a grant application. Not before.

---

## 16. Risks (Honest Version for Solo Founder)

| Risk | Likelihood | What Actually Happens |
|---|---|---|
| Burnout from doing everything alone | High | You stop publishing for 3 weeks. Then 6. Then the project dies. Mitigation: set a sustainable pace. 1 video/week is too aggressive for a solo creator building a platform simultaneously. Start at 1 video/2 weeks. |
| Content quality is not good enough | Medium | Students don't share or return. Mitigation: watch your first 5 videos with a real SS3 student present. Their reaction tells you everything. |
| Afrilearn adds AI explanations | Medium | Your YouTube channel and WhatsApp community are yours — a platform competitor doesn't kill that. Focus on the distribution moat, not the feature moat. |
| WAEC copyright enforcement | Low-Medium | Resolve this legally before platform launch. Videos are safe. |
| Platform build takes too long | High | You ship a half-built product or never ship it. Mitigation: Phase 1 content-first strategy means students get value while the platform is built. |

---

*Project Paragon PRD v2 — May 2026 — Solo Founder Edition*
