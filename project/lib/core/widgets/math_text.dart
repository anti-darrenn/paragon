import 'package:flutter/material.dart';

import 'full_latex_view.dart';

/// Renders a string containing mixed plain text and inline LaTeX: the
/// same dialect as [FullLatexView] (see there).
///
/// [useLightRenderer] lays maths out as it is, without the sideways-scroll
/// box `FullLatexView` gives a wide expression — for answer options and
/// other tight rows. Both go through the one scanner (`latexSpans`), so a
/// question cannot change meaning depending on which one drew it. Until
/// 2026-10-17 they were two hand-written scanners that differed (the light
/// one ended `\textbf{` at the first `}`).
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool useLightRenderer;

  const MathText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.useLightRenderer = false,
  });

  @override
  Widget build(BuildContext context) => FullLatexView(
    latex: text,
    textStyle: style ?? DefaultTextStyle.of(context).style,
    textAlign: textAlign,
    scrollWideMath: !useLightRenderer,
  );
}
