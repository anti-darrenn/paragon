import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../a11y/speech_text.dart';
import '../latex/tex_preprocess.dart';

/// Renders a string containing mixed plain text and LaTeX math.
///
/// The source goes through [normalizeTex] first, so Overleaf-style input
/// works: bare commands (`0.\overline{3}`), `\emph`, lists, `tabular`,
/// `align`, `\ce{}`, `\SI{}{}`, macros. What is then drawn:
/// `\(...\)`, `\[...\]` and `$$...$$` as maths, `\textbf{}`, `\textit{}`,
/// `\underline{}`, `\texttt{}` (nested freely), `\vspace{}` and `\$`.
/// A lone `$` is a dollar sign.
class FullLatexView extends StatelessWidget {
  final String latex;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  /// Whether a maths expression wider than the line scrolls sideways in
  /// its own box (the default) or is laid out as it is.
  final bool scrollWideMath;

  const FullLatexView({
    super.key,
    required this.latex,
    this.textStyle,
    this.textAlign,
    this.scrollWideMath = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final source = normalizeTex(latex);
    final spans = latexSpans(
      source,
      effectiveStyle,
      scrollWideMath: scrollWideMath,
    );

    // Plain Text only when every span is unstyled text — and then the
    // *scanned* text, not the raw source. This used to test for math alone
    // and return `Text(s)`, which threw away the scanner's work on any line
    // without an equation: `\textbf{..}`, `\textit{..}`, `\vspace{..}` and
    // `\$` all showed as literal source. Found on a live article.
    final onlyPlain = spans.every(
      (sp) => sp is TextSpan && sp.style == effectiveStyle,
    );
    if (onlyPlain) {
      final text = spans.map((sp) => (sp as TextSpan).text ?? '').join();
      return Text(text, style: effectiveStyle, textAlign: textAlign);
    }
    return mathSemantics(
      source,
      RichText(
        text: TextSpan(style: effectiveStyle, children: spans),
        textAlign: textAlign ?? TextAlign.start,
      ),
    );
  }
}

/// [s] — already through [normalizeTex] — as inline spans in [style].
/// The one scanner behind both `FullLatexView` and `MathText`'s light
/// renderer, so the two cannot disagree about what a string means.
List<InlineSpan> latexSpans(
  String s,
  TextStyle style, {
  bool scrollWideMath = true,
}) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var pos = 0;
  final len = s.length;

  void flushPlain() {
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString(), style: style));
      buf.clear();
    }
  }

  // Math cannot wrap, so an expression wider than the line scrolls
  // sideways inside its own box instead of overflowing the screen. The
  // scroll view sizes to the math when it fits, so short expressions lay
  // out exactly as before. Found on a phone: a worked solution ran 50px
  // past the edge.
  void addMath(String content) {
    flushPlain();
    final math = Math.tex(
      content,
      textStyle: style,
      onErrorFallback: (e) => Text(
        content,
        style: style.copyWith(
          color: Colors.redAccent,
          fontFamily: 'monospace',
        ),
      ),
    );
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: scrollWideMath
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: math,
              )
            : math,
      ),
    );
  }

  while (pos < len) {
    // Escaped dollar: \$
    if (s.codeUnitAt(pos) == 92 && pos + 1 < len && s[pos + 1] == r'$') {
      buf.write(r'$');
      pos += 2;
      continue;
    }

    // \(...\) and \[...\]
    if (s.codeUnitAt(pos) == 92 &&
        pos + 1 < len &&
        (s[pos + 1] == '(' || s[pos + 1] == '[')) {
      final open = s[pos + 1];
      final close = open == '(' ? r'\)' : r'\]';
      final start = pos + 2;
      final end = s.indexOf(close, start);
      if (end != -1) {
        addMath(s.substring(start, end));
        pos = end + 2;
        continue;
      }
    }

    // $$...$$
    if (s.codeUnitAt(pos) == 36 &&
        pos + 1 < len &&
        s.codeUnitAt(pos + 1) == 36) {
      final start = pos + 2;
      final end = s.indexOf(r'$$', start);
      if (end != -1) {
        addMath(s.substring(start, end));
        pos = end + 2;
        continue;
      }
    }

    // A lone $ is currency, never a math delimiter.
    //
    // WAEC questions are full of money ("sold at $4.50 and $3.00"), and
    // treating $ as inline math made the text between two prices render as
    // math: the second price vanished into the span and the words between
    // them came out as italic variables. Six seeded Mathematics questions
    // read as nonsense because of it.
    //
    // Nothing is lost by dropping it. Every $ in the corpus is currency -
    // not one is math - and every generator emits \(...\), so inline math
    // arrives as \(...\) and display math as $$...$$, both still handled
    // above. The editor's LaTeX mode turns an author's `$x$` into \(x\) on
    // save (`dollarMathToParens`).
    if (s.codeUnitAt(pos) == 36) {
      buf.write(r'$');
      pos++;
      continue;
    }

    // \textbf{} \textit{} \underline{} \texttt{} — styled, nestable.
    final styled = _styledCommand(s, pos);
    if (styled != null) {
      final group = _extractBalanced(s, pos + styled.length);
      if (group != null) {
        flushPlain();
        spans.addAll(
          latexSpans(
            group.content,
            _styleFor(styled, style),
            scrollWideMath: scrollWideMath,
          ),
        );
        pos = group.end + 1;
        continue;
      }
    }

    // \vspace{...} or \vspace(...) — vertical space, in cm or pixels.
    if (s.startsWith(r'\vspace', pos) &&
        pos + 7 < len &&
        (s[pos + 7] == '{' || s[pos + 7] == '(')) {
      final closeChar = s[pos + 7] == '{' ? '}' : ')';
      final end = s.indexOf(closeChar, pos + 8);
      if (end != -1) {
        final inner = s.substring(pos + 8, end).trim();
        final height = inner.endsWith('cm')
            ? (double.tryParse(inner.substring(0, inner.length - 2)) ?? 0) *
                  37.7952755906
            : double.tryParse(inner) ?? 0;
        flushPlain();
        spans.add(WidgetSpan(child: SizedBox(height: height)));
        pos = end + 1;
        continue;
      }
    }

    buf.write(s[pos]);
    pos++;
  }

  flushPlain();
  return spans;
}

const _styledCommands = [r'\textbf{', r'\textit{', r'\underline{', r'\texttt{'];

/// The styled command starting at [pos], without its brace.
String? _styledCommand(String s, int pos) {
  if (s.codeUnitAt(pos) != 92) return null;
  for (final c in _styledCommands) {
    if (s.startsWith(c, pos)) return c.substring(0, c.length - 1);
  }
  return null;
}

TextStyle _styleFor(String command, TextStyle base) => switch (command) {
  r'\textbf' => base.copyWith(fontWeight: FontWeight.bold),
  r'\textit' => base.copyWith(fontStyle: FontStyle.italic),
  r'\underline' => base.copyWith(decoration: TextDecoration.underline),
  _ => base.copyWith(fontFamily: 'monospace'),
};

_BraceResult? _extractBalanced(String s, int openIdx) {
  if (openIdx < 0 || openIdx >= s.length || s[openIdx] != '{') return null;
  int depth = 1;
  final start = openIdx + 1;
  for (int i = start; i < s.length; i++) {
    if (s[i] == r'\' && i + 1 < s.length) {
      i++; // \{ and \} do not count
      continue;
    }
    if (s[i] == '{') {
      depth++;
    } else if (s[i] == '}') {
      depth--;
      if (depth == 0) return _BraceResult(s.substring(start, i), i);
    }
  }
  return null;
}

class _BraceResult {
  final String content;
  final int end;
  _BraceResult(this.content, this.end);
}

/// [child] — text with maths in it — as one accessible node, read as
/// words: "If F equals nine over five C plus thirty-two".
///
/// Without this a screen reader got the text runs between the maths and
/// nothing for the maths itself (`flutter_math_fork` exposes no
/// semantics): the live-site review heard "If F = " then "C + 32". The
/// words come from `speakText`, the read-aloud converter, so what a
/// screen reader says and what read-aloud says are the same.
Widget mathSemantics(String source, Widget child) => Semantics(
  label: speakText(source),
  excludeSemantics: true,
  child: child,
);
