# LaTeX Rendering — Project Paragon

How maths is rendered in the app, which macros actually work, and why `$` is not
a delimiter.

> This document was previously wrong in a way worth naming: it described
> `FullLatexView` as using `flutter_tex`/MathJax and gave instructions for adding
> MathJax to `web/index.html`. `flutter_tex` is **banned** — it breaks the build —
> and following those instructions would have broken it. Nothing here describes a
> package the app does not depend on.

## The renderer

`flutter_math_fork` (^0.7.4) is the **only** maths dependency. There is no
MathJax, no KaTeX, no WebView, and no mobile-versus-web split: the same Dart
code runs on every target.

- **`FullLatexView`** (`lib/core/widgets/full_latex_view.dart`) is the real
  renderer — a hand-written scanner over mixed text and maths. It walks the
  string once, emits `TextSpan`s for prose and `WidgetSpan`s wrapping
  `Math.tex(...)` for maths, and returns a `RichText`. A string containing no
  maths is returned as a plain `Text`.
- **`MathText`** (`lib/core/widgets/math_text.dart`) delegates to
  `FullLatexView` by default. `useLightRenderer: true` selects its own,
  simpler inline parser. Both must agree on what a given string means — the two
  are chosen by a flag on the same widget, so a question that rendered one way
  in a drill must not render differently elsewhere.

Parse failures do not throw or blank the screen. `Math.tex` is given an
`onErrorFallback` that prints the offending source in **red monospace**, so a
bad expression is visible as itself rather than as a crash. Tests assert on that
red colour to detect fallbacks.

## Supported syntax

| Syntax | Result |
| --- | --- |
| `\(...\)` | inline maths — **the corpus standard**, emitted by every generator |
| `\[...\]` | display maths |
| `$$...$$` | display maths |
| `\textbf{...}` | bold text (brace-balanced, so nesting is fine) |
| `\textit{...}` | italic text |
| `\vspace{2cm}` | vertical gap (`SizedBox`, ~37.8px per cm; a bare number is px) |
| `\$` | a literal dollar sign |

Not supported, despite what older notes claimed:

- **`\emph{...}`** — appears nowhere in the renderer. Use `\textit{...}`. (No
  content uses `\emph`, so this is a documentation correction, not a live bug.)
- **`\vspace(2cm)`** with parentheses — only the brace form is parsed.
- **`$...$` as inline maths** — deliberately removed, see below.
- **Environments** — `\begin{align}`, `\begin{pmatrix}`, custom `\def` macros.
  Anything `flutter_math_fork` itself cannot parse hits the red fallback.

## `$` is currency, not maths

A lone `$` is rendered as a literal dollar sign.

WAEC questions are full of money, and while `$...$` was treated as inline maths,
the text *between two prices* was parsed as an expression. A question reading:

> 500 tickets were sold ... at `$4.50` and `$3.00` respectively

rendered as `500 tickets were sold ... at ` followed by the maths expression
`4.50 and ` — the second price absorbed into the delimiter and the words in
between set as italic variables. Six seeded Mathematics questions read as
nonsense because of it.

Removing the feature costs nothing. A scan of the whole corpus found **49
unescaped `$`, every one of them currency, and not a single one maths**. Inline
maths arrives as `\(...\)` (the scrapers' format, and what all 216 generator
modules emit) and display maths as `$$...$$`, both untouched by this.

**If you are authoring maths, use `\(...\)`.** A bare `$` will render as a dollar
sign, which is what a reader wants nearly every time it appears.

## Tests

- `test/currency_not_math_test.dart` — the four affected questions, verbatim
  from the seeded corpus, asserting every price survives and that `\(...\)` and
  `$$...$$` still render as maths. Revert the renderer and five of these fail;
  that was checked, not assumed.
- `test/generated_latex_test.dart` — parses every distinct expression in the
  generated corpus (57,992 of them) through `TexParser`, renders a sample, and
  asserts no red fallback appears. It opens with a control group feeding the
  parser deliberately broken LaTeX to prove the suite can fail at all.
- `test/latex_render_test.dart` — the light renderer's span construction.

## If something renders wrong

Copy the **exact** string from Firestore (do not retype it — the escaping is the
whole problem) and add it to `currency_not_math_test.dart` as a failing case
before changing the scanner. The scanner is ordered: escapes, then `\(`/`\[`,
then `$$`, then macros. Order matters, and a change that fixes one delimiter
tends to break another, which is what the corpus-wide test is there to catch.
