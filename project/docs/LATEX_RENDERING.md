# LaTeX Rendering — Project Paragon

How maths is rendered in the app and on the static pages, what LaTeX works, and
why `$` is not a delimiter.

> Rewritten on 2026-10-17. The previous version listed `\begin{pmatrix}` as
> unsupported (it always parsed) and had no answer for an author who types
> `0.\overline{3}` without `\( \)` — which showed as raw source. Both are fixed
> below.

## The pipeline

Every string with maths in it goes through two steps, everywhere:

1. **`normalizeTex`** (`lib/core/latex/tex_preprocess.dart`) turns LaTeX as
   people write it in Overleaf into the small dialect the renderers draw. It
   is pure Dart, idempotent, and a no-op on any string without a backslash, so
   the existing corpus is untouched.
2. **The scanner** (`latexSpans` in `full_latex_view.dart`) draws `\(...\)`,
   `\[...\]` and `$$...$$` with `flutter_math_fork`, and the text styles
   between them.

`FullLatexView` and `MathText` (both of its modes) share that one scanner.
Until 2026-10-17 the light renderer was a second hand-written scanner that
disagreed with the first (it ended `\textbf{` at the first `}`). Now
`useLightRenderer: true` only means "don't wrap wide maths in a sideways
scroll box".

The same preprocessor runs in read-aloud (`speakText`), the screen-reader
labels (`mathSemantics`), the question checks (`checkDraft`, `lesson_check`)
and the audits (`question_rules.js`, `content_lint.js`). The static site uses
`tools/site/tex_preprocess.js`, a line-for-line mirror. Both test suites run the
shared cases in `test/fixtures/tex_preprocess_cases.json`, so the two cannot
drift. **Change both together.**

`flutter_math_fork` (^0.7.4) is the only maths dependency in the app; the
static pages use KaTeX. There is no MathJax and no WebView. Parse failures never
throw: the source is shown in **red monospace**.

## What works

### Maths (inside `\( \)`, `\[ \]`, `$$ $$`)

Everything `flutter_math_fork` parses, which is most of KaTeX:
- fractions, roots and binomials;
- every accent: `\overline`, `\bar`, `\dot`, `\vec`, `\hat`, `\widehat`,
  `\overrightarrow`, `\underline`;
- `\text`, `\mathrm`, `\mathbf`, `\boldsymbol`, `\mathbb`, `\operatorname`;
- `\cancel`, `\xrightarrow`, `\overset`, `\underset`, `\boxed`, `\color`;
- the environments `array`, `matrix`/`pmatrix`/`bmatrix`/`vmatrix`, `aligned`,
  `alignedat` and `cases`;
- Greek, relations, arrows, big operators and `\left … \right`.

The preprocessor adds what the parser lacks:

| You write | It becomes |
| --- | --- |
| `\ce{2H2 + O2 -> 2H2O}`, `\ce{SO4^2-}`, `\ce{N2 + 3H2 <=>[Fe] 2NH3}`, `\ce{CuSO4.5H2O}` | upright formulae with subscripts, charges, states, coefficients, hydrates, arrows with conditions (a subset of mhchem) |
| `\SI{9.8}{\metre\per\second\squared}`, `\si{kg.m/s^2}`, `\qty{3e8}{m/s}`, `\num{1.2e-3}`, `\ang{30;15;}` | siunitx units, numbers and angles |
| `\begin{gathered}`, `gather`, `align`, `split`, `multline`, `equation` | `array`/`aligned` equivalents |
| `\recurring{3}`, `\degree`, `\celsius`, `\ohm`, `\micro`, `\nicefrac{1}{2}`, `\substack`, `\tag{1}`, `\bm`, `\pmb` | their nearest parsable forms |
| `\label`, `\nonumber`, `\limits`, `p{2cm}` / `@{}` column specs | dropped or simplified |

### Maths without delimiters

A maths command typed in text — `Express 0.\overline{3} as a fraction`,
`\frac{1}{2}+\frac{1}{3}`, `\sqrt[3]{27}`, `\alpha particles`,
`\begin{pmatrix}…\end{pmatrix}` — is wrapped as inline maths. It takes the
command's arguments and scripts, anything joined on without a space, and digits
just before it (the `0.` of `0.\overline{3}`).

### Text (outside maths)

- **Drawn:** `\textbf`, `\textit`, `\underline` and `\texttt`, nested freely;
  `\vspace{2cm}`; `\$`.
- **Converted:**
  - `\emph`, `\textsl` (italic) and `\textsc` (capitals);
  - `\textsuperscript` and `\textsubscript`;
  - `\section*` and friends (bold headings), `itemize`/`enumerate`/
    `description` lists, `tabular` (a maths array), `center`, `quote`;
  - `\\` and `\newline` (line breaks), `--` and `---` (dashes), ``` ``…'' ```
    (quotes), `~` (a non-breaking space);
  - accents (`\'e`, `\"{o}`, `\c{c}`), `\%`, `\&`, `\#`, `\ldots`, `\pounds`,
    `\naira`, `{\bf …}`;
  - `\footnote`, `\href`, `\url`.
- **Macros:** `\newcommand`, `\renewcommand`, `\def`, `\let` and
  `\DeclareMathOperator`, defined and used in the same text.

Dashes, tildes and quotes are converted only in text that has a backslash
command somewhere. A WAEC stem's `------` blank is never touched.

### What cannot work

TikZ, pgfplots, `\includegraphics` and any package that draws. A diagram is an
image upload in the studio. `\mathcal`, `\mathfrak`, `\mathscr`, `\mathsf` and
`\mathtt` render in the ordinary font, because their font files are trimmed
from the build (`tools/site/trim_fonts.js`).

## `$` is currency, not maths

In stored text a lone `$` is a literal dollar sign.

WAEC questions are full of money. While `$...$` was treated as inline maths,
the text *between two prices* became an expression: "sold at `$4.50` and
`$3.00`" rendered `4.50 and ` as italic maths. A scan of the corpus found 49
unescaped `$`, every one currency, none maths.

**Authors who type `$x$` the Overleaf way are still fine.** The editor's LaTeX
mode converts `$...$` to `\(...\)` when the box loses focus
(`dollarMathToParens`), and `\$` stays a dollar.

## The editor: Normal and LaTeX modes

`MathField` and `MathToolbar` (`lib/core/widgets/math_field/`) are the boxes
used by the studio, the question bank, quiz and flashcard editors.

- **LaTeX** edits the stored text directly.
- **Normal** takes calculator-style typing and stores it as LaTeX
  (`plainToLatex`):
  - `x^2 + 1`, `(x+1)/(x-1)`, `sqrt(2)`;
  - `0.(3)` or `0.3 rec` for a recurring decimal;
  - `30 deg`, `>=`, `!=`, `+-`, `pi`, `log_2(8)`.

  Prose stays prose.
- A value Normal mode cannot show faithfully (a matrix, display maths) is
  read-only there, with a note. **Switching modes never rewrites a stored
  value.**
- The toolbar's buttons type at the cursor and, in LaTeX mode, wrap themselves
  in `\( \)` when used outside maths.

## Tests

- `test/tex_preprocess_test.dart` covers:
  - the shared cases, each idempotent and parsing;
  - the owner's `0.\overline{3}` case, with a control;
  - corpus strings left alone;
  - the renderers agreeing.
- `tools/site/tex_preprocess.test.js`: the JS mirror gives the same output for
  every shared case, and KaTeX renders it.
- `test/math_input_test.dart` and `test/math_field_test.dart`: Normal mode, the
  way back, and the toolbar.
- `test/currency_not_math_test.dart`: prices survive.
- `test/generated_latex_test.dart`: every expression in the generated corpus
  parses (with a control group of broken LaTeX).

## If something renders wrong

Copy the **exact** stored string, add it to
`test/fixtures/tex_preprocess_cases.json` with the output you expect, and make
both `tex_preprocess_test.dart` and `tex_preprocess.test.js` pass.
