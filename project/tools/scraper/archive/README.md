# Retired scraper chain

The original content pipeline, kept as history. **Do not run these.**

| Script | What it did | Why it's retired |
|---|---|---|
| `1_scrape.js` | Scraped myschool.ng into `data/raw_<subject>.json` | myschool.ng is a Nuxt app now; its `.question-item` selectors match nothing. `4_scrape_answers.js` reads `__NUXT_DATA__` instead. |
| `2_classify.js` | Labelled topics with Groq `llama-3.1-8b-instant` | Wrong for 81% of Mathematics and 61% of Physics. Superseded by `reclassify.js` and `8_apply_reclass.js`. |
| `fix_misclassified.js` | Hand-patched `2_classify.js` output | Only existed to patch the classifier above. |
| `3_seed.js` | Created subject → units → topics → questions | **Always creates a fresh subject document**, so on an existing subject it duplicates it. Use `6_seed_generated.js` (additive) or `7_create_subject.js`. |

Each hardcoded its own `const SUBJECT`, and they had drifted apart.

They resolve `data/` from their own directory, so run from here they find
nothing and stop. That's deliberate. If you ever need one, copy it back up a
level and read it first.

The live pipeline is described in the root `CLAUDE.md`.
