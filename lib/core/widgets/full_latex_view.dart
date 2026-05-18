import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders a string containing mixed plain text and LaTeX math.
/// Supports: $...$  $$...$$  \(...\)  \[...\]  \textbf{}  \textit{}
class FullLatexView extends StatelessWidget {
  final String latex;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  const FullLatexView({
    super.key,
    required this.latex,
    this.textStyle,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final s = latex;
    final spans = <InlineSpan>[];
    final buf = StringBuffer();
    int pos = 0;
    final len = s.length;

    void flushPlain() {
      if (buf.isNotEmpty) {
        spans.add(TextSpan(text: buf.toString(), style: effectiveStyle));
        buf.clear();
      }
    }

    bool isEscaped(int index) {
      int k = index - 1;
      int count = 0;
      while (k >= 0 && s.codeUnitAt(k) == 92) {
        count++;
        k--;
      }
      return count.isOdd;
    }

    Widget mathWidget(String content) => Math.tex(
          content,
          textStyle: effectiveStyle,
          onErrorFallback: (e) => Text(
            content,
            style: effectiveStyle.copyWith(
                color: Colors.redAccent, fontFamily: 'monospace'),
          ),
        );

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
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: mathWidget(s.substring(start, end)),
          ));
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
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: mathWidget(s.substring(start, end)),
          ));
          pos = end + 2;
          continue;
        }
      }

      // $...$
      if (s.codeUnitAt(pos) == 36) {
        int j = pos + 1;
        while (j < len) {
          if (s.codeUnitAt(j) == 36 && !isEscaped(j)) break;
          j++;
        }
        if (j < len) {
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: mathWidget(s.substring(pos + 1, j)),
          ));
          pos = j + 1;
          continue;
        }
        buf.write(r'$');
        pos++;
        continue;
      }

      // \textbf{...} and \textit{...}
      if (s.startsWith(r'\textbf{', pos) || s.startsWith(r'\textit{', pos)) {
        final isBold = s.startsWith(r'\textbf{', pos);
        final result = _extractBalanced(s, s.indexOf('{', pos));
        if (result != null) {
          flushPlain();
          spans.add(TextSpan(
            text: result.content,
            style: isBold
                ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
                : effectiveStyle.copyWith(fontStyle: FontStyle.italic),
          ));
          pos = result.end + 1;
          continue;
        }
      }

      // \vspace{...} — insert vertical space
      if (s.startsWith(r'\vspace{', pos)) {
        final result = _extractBalanced(s, s.indexOf('{', pos));
        if (result != null) {
          final inner = result.content.trim();
          double height = 0;
          if (inner.endsWith('cm')) {
            height = (double.tryParse(inner.replaceAll('cm', '')) ?? 0) * 37.8;
          } else {
            height = double.tryParse(inner) ?? 0;
          }
          flushPlain();
          spans.add(WidgetSpan(
            child: SizedBox(height: height),
          ));
          pos = result.end + 1;
          continue;
        }
      }

      buf.write(s[pos]);
      pos++;
    }

    flushPlain();

    final hasMath = spans.any((sp) => sp is WidgetSpan);
    if (!hasMath) {
      return Text(s, style: effectiveStyle, textAlign: textAlign);
    }
    return RichText(
      text: TextSpan(style: effectiveStyle, children: spans),
      textAlign: textAlign ?? TextAlign.start,
    );
  }

  _BraceResult? _extractBalanced(String s, int openIdx) {
    if (openIdx < 0 || openIdx >= s.length || s[openIdx] != '{') return null;
    int depth = 1;
    final start = openIdx + 1;
    for (int i = start; i < s.length; i++) {
      if (s[i] == '{') {
        depth++;
      } else if (s[i] == '}') {
        depth--;
        if (depth == 0) return _BraceResult(s.substring(start, i), i);
      }
    }
    return null;
  }
}

class _BraceResult {
  final String content;
  final int end;
  _BraceResult(this.content, this.end);
}