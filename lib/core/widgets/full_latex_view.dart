import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_tex/flutter_tex.dart';

/// Renders full LaTeX content (text + math) using a WebView + MathJax backend.
///
/// This widget includes a small preprocessor that converts common text-mode
/// macros like `\textbf{}`, `\textit{}` and `\vspace{...}` into HTML so
/// they render as expected in the WebView. Math delimiters (`$$...$$`, `$...$`,
/// `\(...\)` and `\[...\]`) are left intact for MathJax to process.
class FullLatexView extends StatelessWidget {
  final String latex;
  final TeXViewStyle? style;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  const FullLatexView({
    super.key,
    required this.latex,
    this.style,
    this.textStyle,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // On web, `flutter_tex`'s JS hooks may not be available or require
    // additional index.html setup. Use a lightweight parser + `flutter_math_fork`
    // fallback on web to avoid WebView/JS init errors. On mobile/desktop use
    // the full TeXView (MathJax) renderer.
    if (kIsWeb) {
      return _buildWebFallback(context);
    }

    final html = _convertLatexToHtml(latex);
    return TeXView(
      child: TeXViewDocument(html),
      style: style ?? const TeXViewStyle(margin: TeXViewMargin.all(8)),
      loadingWidgetBuilder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildWebFallback(BuildContext context) {
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

    while (pos < len) {
      // escaped dollar
      if (s.codeUnitAt(pos) == 92 && pos + 1 < len && s[pos + 1] == r'$') {
        buf.write(r'$');
        pos += 2;
        continue;
      }

      // \(...\) and \[...\]
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
                style: effectiveStyle.copyWith(color: Colors.redAccent, fontFamily: 'monospace'),
              ),
            ),
          ));
          pos = end + 2;
          continue;
        }
      }

      // $$...$$
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
                style: effectiveStyle.copyWith(color: Colors.redAccent, fontFamily: 'monospace'),
              ),
            ),
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
                style: effectiveStyle.copyWith(color: Colors.redAccent, fontFamily: 'monospace'),
              ),
            ),
          ));
          pos = j + 1;
          continue;
        }
        buf.write('\$');
        pos++;
        continue;
      }

      // simple text-mode macros: support single or double-escaped backslashes
      if (s.startsWith(r'\\textbf{', pos) || s.startsWith(r'\\textit{', pos) || s.startsWith(r'\textbf{', pos) || s.startsWith(r'\textit{', pos)) {
        final isBold = s.startsWith(r'\\textbf{', pos) || s.startsWith(r'\textbf{', pos);
        final parseStart = s.indexOf('{', pos);
        if (parseStart != -1) {
          final parsed = _extractBalanced(s, parseStart);
          if (parsed != null) {
            final inner = parsed.content;
            flushPlain();
            spans.add(TextSpan(
              text: inner,
              style: isBold
                  ? effectiveStyle.copyWith(fontWeight: FontWeight.bold)
                  : effectiveStyle.copyWith(fontStyle: FontStyle.italic),
            ));
            pos = parsed.end + 1;
            continue;
          }
        }
      }

      // \vspace with either braces or parentheses; support single or double backslash
      if (s.startsWith(r'\\vspace', pos) || s.startsWith(r'\vspace', pos)) {
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
              // malformed, fall through
              buf.write(s[pos]);
              pos++;
              continue;
            }
            inner = s.substring(parseStart + 1, end).trim();
            pos = end + 1;
          } else {
            final parsed = _extractBalanced(s, parseStart);
            if (parsed == null) {
              buf.write(s[pos]);
              pos++;
              continue;
            }
            inner = parsed.content.trim();
            pos = parsed.end + 1;
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
          spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox(height: height)));
          continue;
        }
      }

      buf.write(s[pos]);
      pos++;
    }

    if (buf.isNotEmpty) {
      flushPlain();
    }

    final hasMath = spans.any((sp) => sp is WidgetSpan);
    if (!hasMath) {
      return Text(s, style: effectiveStyle, textAlign: textAlign);
    }

    return RichText(text: TextSpan(style: effectiveStyle, children: spans), textAlign: textAlign ?? TextAlign.start);
  }

  // Convert a LaTeX string into HTML while preserving math delimiters.
  String _convertLatexToHtml(String src) {
    // Very small preprocessor: finds simple macros and converts them
    // to HTML equivalents. It does not try to be a full LaTeX parser.
    final buffer = StringBuffer();
    int pos = 0;
    final len = src.length;

    while (pos < len) {
      // Handle \textbf{...} and \textit{...}
      if (src.startsWith(r'\\textbf{', pos) || src.startsWith(r'\\textit{', pos)) {
        // The source may contain double-escaped backslashes (e.g., from JSON),
        // so accept both single and double backslashes.
        final isDoubleSlash = src.startsWith(r'\\', pos);
        final macro = isDoubleSlash ? src.substring(pos + 2, pos + 8) : src.substring(pos + 1, pos + 7);
        final isBold = macro.contains('textbf');
        // (macroLen removed) we parse braces directly below
        final parseStart = src.indexOf('{', pos);
        if (parseStart == -1) {
          buffer.write(src[pos]);
          pos++;
          continue;
        }
        final parsed = _extractBalanced(src, parseStart);
        if (parsed == null) {
          buffer.write(src[pos]);
          pos++;
          continue;
        }
        final inner = _convertLatexToHtml(parsed.content);
        buffer.write(isBold ? '<strong>$inner</strong>' : '<em>$inner</em>');
        pos = parsed.end + 1;
        continue;
      }

      // Handle single-escaped macros like \textbf{...}
      if (src.startsWith(r'\textbf{', pos) || src.startsWith(r'\textit{', pos)) {
        final isBold = src.startsWith(r'\textbf{', pos);
        final parseStart = pos + (isBold ? r'\textbf{'.length : r'\textit{'.length) - 1;
        final parsed = _extractBalanced(src, parseStart);
        if (parsed == null) {
          buffer.write(src[pos]);
          pos++;
          continue;
        }
        final inner = _convertLatexToHtml(parsed.content);
        buffer.write(isBold ? '<strong>$inner</strong>' : '<em>$inner</em>');
        pos = parsed.end + 1;
        continue;
      }

      // Handle \vspace{..} or \vspace(...)
      if (src.startsWith(r'\\vspace', pos) || src.startsWith(r'\vspace', pos)) {
        final braceIdx = src.indexOf('{', pos);
        final parenIdx = src.indexOf('(', pos);
        int parseStart = -1;
        bool isParen = false;
        if (braceIdx != -1 && (parenIdx == -1 || braceIdx < parenIdx)) {
          parseStart = braceIdx;
          isParen = false;
        } else if (parenIdx != -1) {
          parseStart = parenIdx;
          isParen = true;
        }
        if (parseStart == -1) {
          buffer.write(src[pos]);
          pos++;
          continue;
        }
        String inner;
        if (isParen) {
          final end = src.indexOf(')', parseStart + 1);
          if (end == -1) {
            buffer.write(src[pos]);
            pos++;
            continue;
          }
          inner = src.substring(parseStart + 1, end).trim();
          pos = end + 1;
        } else {
          final parsed = _extractBalanced(src, parseStart);
          if (parsed == null) {
            buffer.write(src[pos]);
            pos++;
            continue;
          }
          inner = parsed.content.trim();
          pos = parsed.end + 1;
        }
        double px = 0;
        if (inner.endsWith('cm')) {
          final num = double.tryParse(inner.substring(0, inner.length - 2)) ?? 0;
          px = num * 37.7952755906;
        } else {
          px = double.tryParse(inner) ?? 0;
        }
        buffer.write('<div style="height:${px}px"></div>');
        continue;
      }

      // Default: write one char, escaping HTML-special characters
      final ch = src[pos];
      if (ch == '&') {
        buffer.write('&amp;');
      } else if (ch == '<') {
        buffer.write('&lt;');
      } else if (ch == '>') {
        buffer.write('&gt;');
      } else {
        buffer.write(ch);
      }
      pos++;
    }

    // Wrap the content so MathJax/KaTeX can find delimiters in the HTML
    final css = _cssFromTextStyle(textStyle, textAlign);
    return '<div style="$css">${buffer.toString()}</div>';
  }

  String _cssFromTextStyle(TextStyle? ts, TextAlign? ta) {
    final parts = <String>[];
    if (ts != null) {
      if (ts.fontSize != null) {
        parts.add('font-size:${ts.fontSize}px');
      }
      if (ts.color != null) {
        parts.add('color:${_colorToHex(ts.color!)}');
      }
      if (ts.fontStyle == FontStyle.italic) {
        parts.add('font-style:italic');
      }
      if (ts.fontWeight != null) {
        final fw = ts.fontWeight!;
        if (fw == FontWeight.w900) {
          parts.add('font-weight:900');
        } else if (fw == FontWeight.w800) {
          parts.add('font-weight:800');
        } else if (fw == FontWeight.w700) {
          parts.add('font-weight:700');
        } else if (fw == FontWeight.w600) {
          parts.add('font-weight:600');
        } else if (fw == FontWeight.w500) {
          parts.add('font-weight:500');
        } else if (fw == FontWeight.w400) {
          parts.add('font-weight:400');
        }
      }
      if (ts.fontFamily != null) {
        parts.add('font-family:${ts.fontFamily}');
      }
    }
    if (ta != null) {
      final align = ta == TextAlign.center
          ? 'center'
          : (ta == TextAlign.right ? 'right' : (ta == TextAlign.justify ? 'justify' : 'left'));
      parts.add('text-align:$align');
    }
    return parts.join(';');
  }

  String _colorToHex(Color c) {
    final rInt = ((c.r * 255.0).round()).clamp(0, 255).toInt();
    final gInt = ((c.g * 255.0).round()).clamp(0, 255).toInt();
    final bInt = ((c.b * 255.0).round()).clamp(0, 255).toInt();
    final r = rInt.toRadixString(16).padLeft(2, '0');
    final g = gInt.toRadixString(16).padLeft(2, '0');
    final b = bInt.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  // Helper: extract balanced {...} starting at openBrace index; returns inner content and index of closing brace.
  _BraceParseResult? _extractBalanced(String s, int openBraceIndex) {
    if (openBraceIndex < 0 || openBraceIndex >= s.length || s[openBraceIndex] != '{') {
      return null;
    }
    int depth = 0;
    int i = openBraceIndex;
    final start = openBraceIndex + 1;
    for (; i < s.length; i++) {
      final c = s[i];
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        if (depth == 0) {
          // closing brace for the initial {
          return _BraceParseResult(s.substring(start, i), i);
        }
        depth--;
      }
    }
    return null;
  }
}

class _BraceParseResult {
  final String content;
  final int end;
  _BraceParseResult(this.content, this.end);
}
