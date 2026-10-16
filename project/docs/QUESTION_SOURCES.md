# Where the questions come from

Plan v2 §2.1.1. The evidence is in `docs/REPO_FACTS.md` § "0.3".

## Past questions (`source: 'waec'`)

| | |
|---|---|
| **Copied from** | myschool.ng's classroom archive (`https://myschool.ng/classroom/<subject>?exam_type=waec…`). Nothing else. |
| **How** | `tools/scraper/archive/1_scrape.js`, then `3_seed.js`, seeded the stems (both since retired). `4_scrape_answers.js` and `5_match_answers.js` added the answers and explanations, and `10_fetch_question_images.js` added the diagrams. |
| **When** | Before 2026-09-25, when the chain was retired (`d783017`). |
| **Raw copy kept** | `tools/scraper/data/answers_<subject>.json`: each record's HTML stem, options, the source's correct flag and its explanation. `raw_physics.json` and `raw_further-mathematics.json` come from the first scrape. |
| **Changed since** | The mechanical fixes (`fix_questions.js`) and reviewed corrections (`apply_corrections.js`, `docs/audit/CONTENT_REVIEW_2026-10-15.md`). 48 duplicates and 5 broken questions were retired. |
| **What it lacks** | The sitting (May/June or Nov/Dec), the paper and the question number. So `year` alone identifies a paper, and some "papers" hold 51 to 67 questions. |
| **Identifying a copy** | `source: 'waec'` with no `origin`, plus `sourceId` (myschool's record id). Questions added later through `import_questions.js` carry `origin: 'authored'`. |

## How much of the wording is the source's

From `node tools/admin/explanation_report.js` against the static-site cache (2026-10-16):

| Subject | Past questions | No explanation | Source's explanation | Reads differently | Not matched |
|---|---|---|---|---|---|
| Further Mathematics | 776 | 6% | 86% | 2% | 6% |
| Mathematics | 1,677 | 8% | 80% | 5% | 7% |
| Physics | 1,753 | 42% | 57% | 1% | 0% |

- **"Reads differently"** means the text no longer resembles the source's. That can be a
  rewrite or a heavy LaTeX correction, so check it before counting it as Paragon's own
  wording.
- **The stems and options are the source's text throughout.** WAEC wrote them first, and
  myschool.ng's transcription is what was copied, typos included (for example
  "Expression 0.612" in 2018 Mathematics).

## Practice questions (`origin: 'ai_generated'`)

`tools/scraper/gen/` generates these in code. Each answer is computed and checked by
`verify.js`, and nothing is copied. They are labelled "Paragon practice" everywhere.

## Permission: the owner's decision (open)

`docs/WAEC_OUTREACH.md` drafts the letter to WAEC; collecting the text from a public
archive is not permission. The options from Plan v2 §2.1.2:

- **(a) Keep the questions and make the rest Paragon's.** Rewrite every explanation in
  Paragon's own words, and check the stem, options and answer against an original
  paper. `explanation_report.js` is the to-do list.
- **(b) Ask myschool.ng for written permission** to use their transcription and
  explanations.
- **(c) Rebuild from original WAEC papers** that the owner or contributors hold.

**Decision:** _not made yet_.
