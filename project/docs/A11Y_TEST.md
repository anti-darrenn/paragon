# Screen-reader check (Plan v2 §4.10)

The automated tests show that Flutter's semantics tree has what a screen reader needs
(`test/math_semantics_test.dart`, "drill-shaped page"):
- the stem as one node, its maths spoken ("Evaluate 4 to the power three halves");
- the "Comes up in about 1 in 34…" line;
- each option, with "correct" or "incorrect" once answered;
- the verdict, as a live region.

What no test can show is how Flutter **web** turns that tree into the page's DOM, and
what a real screen reader then says. The 16 Oct review saw the options, but not the stem
or the frequency line, in Chrome's accessibility tree. That is what this checks.

## Setup

- **Windows:** Chrome and NVDA (free, nvaccess.org).
- **Android:** Chrome and TalkBack (Settings → Accessibility).
- Open the production site, or the PR's preview channel.

## Steps

1. Open `/subject/mathematics/course/topic/indices`.
2. Turn semantics on.
   - **NVDA or TalkBack:** they turn it on themselves. If they don't, press Tab once;
     Flutter's hidden "Enable accessibility" button comes first.
   - **Without a screen reader:** run this in the DevTools console:
     `document.querySelector('flt-semantics-placeholder')?.click()`.
3. **Topic page.** Listen for the strand and "Comes up in about 1 in N WAEC Mathematics
   questions".
4. Start the drill (**Start practising**). Listen for:
   - [ ] the **whole stem**, maths spoken, before the options;
   - [ ] each option as "Option A: …";
   - [ ] after answering, the verdict ("Not quite…", "Correct") spoken without moving
     focus;
   - [ ] **Get a hint**, then the hint text;
   - [ ] the explanation under the verdict;
   - [ ] a diagram (a past question with one) as "Diagram for this question".
5. Finish a WAEC exam (untimed, a few questions), then open its review. The stem,
   options, the student's choice and the explanation should all be read.

## If the stem is silent

In DevTools → Elements, find the stem's `<flt-semantics>` element and note:
- whether it has `aria-label` or text content;
- its `role`.

A node carrying only `aria-label`, with no role, is ignored by Chrome: the name is
dropped from the accessibility tree. In that case the fix is in how the app labels plain
nodes, not in the speech converter. Record what you found here:

| Date | Device and reader | Build | Stem read? | Notes |
|---|---|---|---|---|
| | | | | |
