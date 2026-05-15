# LaTeX Rendering — Project Paragon

This document explains how LaTeX rendering is implemented in the app, what macros are supported, and how to enable full MathJax on the web.

Summary
- `FullLatexView` — full renderer using `flutter_tex` (MathJax) on mobile/desktop; uses a web-safe fallback on web.
- `MathText` — convenience widget that by default delegates to `FullLatexView`. It exposes `useLightRenderer` (opt-in) to use a lightweight, fast inline parser implemented with `flutter_math_fork` `Math.tex` and `TextSpan`/`WidgetSpan`.

Supported macros (current)
- Inline math: `$...$`, `$$...$$`, `\\(...\\)`, `\\[...\\]` (rendered by MathJax or `flutter_math_fork` math widget)
- Text macros (preprocessed): `\\textbf{...}`, `\\textit{...}`, `\\emph{...}` (rendered as bold/italic text)
- Vertical space: `\\vspace{<n>cm}` and `\\vspace(<n>cm)` (converted to a `SizedBox` with approximate pixel height)

Notes & limitations
- The preprocessor is intentionally small — it converts a handful of commonly-used text macros and leaves math delimiters for MathJax or KaTeX.
- Complex LaTeX environments (e.g. `\\begin{align}`, custom macro definitions) are not parsed. Those should be converted to images or simplified content.

Enabling full MathJax on web (optional)
Add MathJax to `web/index.html` before the Flutter script to allow `flutter_tex` and MathJax to work on web directly:

```html
<script>
window.MathJax = {
  tex: {inlineMath: [['$','$'], ['\\(','\\)']], displayMath: [['$$','$$'], ['\\[','\\]']]},
  options: {skipHtmlTags: ['script','noscript','style','textarea','pre']}
};
</script>
<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
```

If you prefer not to enable MathJax globally, the app includes a web fallback that uses `flutter_math_fork` to render math and converts `\\textbf`/`\\vspace` into native `Text` and layout widgets.

Testing
- A widget test is included in `test/latex_render_test.dart` that verifies the lightweight parser produces `TextSpan` and `WidgetSpan` nodes for `\\textbf` and `\\vspace`.

If you find a macro that is not rendering, paste the exact literal string from the database (copy-paste) and we'll add support for that pattern.
