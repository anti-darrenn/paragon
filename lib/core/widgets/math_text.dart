import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'full_latex_view.dart';

/// Renders a string containing mixed plain text and inline LaTeX.
/// Supports: `$...$`, `$$...$$`, `\(...\)`, `\[...\]`.
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
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    final s = text;
    if (!useLightRenderer) {
      return FullLatexView(latex: s, textStyle: effectiveStyle, textAlign: textAlign);
    }
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
      // Returns true if the character at `index` is escaped by an
      // odd number of preceding backslashes.
      int k = index - 1;
      int count = 0;
      while (k >= 0 && s.codeUnitAt(k) == 92) {
        count++;
        k--;
      }
      return count.isOdd;
    }

    while (pos < len) {
      // Handle escaped dollar: \$
      if (s.codeUnitAt(pos) == 92 && pos + 1 < len && s[pos + 1] == r'$') {
        buf.write(r'$');
        pos += 2;
        continue;
      }

      // Handle \( ... \) and \[ ... \]
      if (s.codeUnitAt(pos) == 92 && pos + 1 < len && (s[pos + 1] == '(' || s[pos + 1] == '[')) {
        final open = s[pos + 1];
        final close = open == '(' ? r'\)' : r'\]';
        final start = pos + 2;
        final end = s.indexOf(close, start);
        if (end != -1) {
          final mathContent = s.substring(start, end);
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              mathContent,
              textStyle: effectiveStyle,
              onErrorFallback: (FlutterMathException err) => Text(
                mathContent,
                style: effectiveStyle.copyWith(
                  color: Colors.redAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ));
          pos = end + 2; // skip the closing \) or \]
          continue;
        }
        // If no closing found, fall through and treat literally
      }

      // Handle $$ ... $$
      if (s.codeUnitAt(pos) == 36 && pos + 1 < len && s.codeUnitAt(pos + 1) == 36) {
        final start = pos + 2;
        final end = s.indexOf(r'$$', start);
        if (end != -1) {
          final mathContent = s.substring(start, end);
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              mathContent,
              textStyle: effectiveStyle,
              onErrorFallback: (FlutterMathException err) => Text(
                mathContent,
                style: effectiveStyle.copyWith(
                  color: Colors.redAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ));
          pos = end + 2;
          continue;
        }
      }

      // Handle single $ ... $
      if (s.codeUnitAt(pos) == 36) {
        int j = pos + 1;
        while (j < len) {
          if (s.codeUnitAt(j) == 36 && !isEscaped(j)) break;
          j++;
        }
        if (j < len && s.codeUnitAt(j) == 36) {
          final mathContent = s.substring(pos + 1, j);
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              mathContent,
              textStyle: effectiveStyle,
              onErrorFallback: (FlutterMathException err) => Text(
                mathContent,
                style: effectiveStyle.copyWith(
                  color: Colors.redAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ));
          pos = j + 1;
          continue;
        }
        // no closing $, treat as literal
        buf.write('\$');
        pos++;
        continue;
      }

      // Handle simple text-mode LaTeX macros like \textbf{...}, \textit{...}
      if (s.startsWith(r'\textbf{', pos) || s.startsWith(r'\textit{', pos)) {
        final isBold = s.startsWith(r'\textbf{', pos);
        final macroLen = isBold ? r'\textbf{'.length : r'\textit{'.length;
        final start = pos + macroLen;
        final end = s.indexOf('}', start);
        if (end != -1) {
          final inner = s.substring(start, end);
          flushPlain();
          spans.add(TextSpan(
            text: inner,
            style: isBold
                ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
                : effectiveStyle.copyWith(fontStyle: FontStyle.italic),
          ));
          pos = end + 1;
          continue;
        }
      }

      // Handle \vspace{<number>cm} or \vspace(<number>cm)
      if (s.startsWith(r'\vspace', pos) || s.startsWith(r'\vspace', pos)) {
        final braceIdx = s.indexOf('{', pos);
        final parenIdx = s.indexOf('(', pos);
        int parseStart = -1;
        bool isParen = false;
        if (braceIdx != -1 && (parenIdx == -1 || braceIdx < parenIdx)) {
          parseStart = braceIdx;
          isParen = false;
        } else if (parenIdx != -1) {
          parseStart = parenIdx;
          isParen = true;
        }
        if (parseStart != -1) {
          String inner;
          if (isParen) {
            final end = s.indexOf(')', parseStart + 1);
            if (end == -1) {
              buf.write(s[pos]);
              pos++;
              continue;
            }
            inner = s.substring(parseStart + 1, end).trim();
            pos = end + 1;
          } else {
            final end = s.indexOf('}', parseStart + 1);
            if (end == -1) {
              buf.write(s[pos]);
              pos++;
              continue;
            }
            inner = s.substring(parseStart + 1, end).trim();
            pos = end + 1;
          }
          double height = 0;
          if (inner.endsWith('cm')) {
            final numStr = inner.substring(0, inner.length - 2);
            final val = double.tryParse(numStr) ?? 0;
            height = val * 37.7952755906;
          } else {
            height = double.tryParse(inner) ?? 0;
          }
          flushPlain();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(height: height),
          ));
          continue;
        }
      }

      // Default: accumulate plain text
      buf.write(s[pos]);
      pos++;
    }

    flushPlain();

    // If there's no WidgetSpan (i.e., no math segments) return regular Text
    final hasMath = spans.any((sp) => sp is WidgetSpan);
    if (!hasMath) {
      return Text(s, style: effectiveStyle, textAlign: textAlign);
    }

    return RichText(
      text: TextSpan(style: effectiveStyle, children: spans),
      textAlign: textAlign,
    );
  }
}
