import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../lessons/lesson_doc.dart';
import 'full_latex_view.dart';
import 'lesson_blocks/lesson_block_view.dart';
import '../theme/app_palette.dart';

/// Renders a Learn-mode article: long-form prose with embedded maths.
///
/// ## Why this is not a markdown package
///
/// The obvious approach is `flutter_markdown` with a custom inline syntax
/// that swaps maths spans for `Math.tex` widgets. Two things rule it out.
///
/// `flutter_markdown` is **discontinued** — its own pub page points at a
/// community fork — and the credible alternatives are comparably stale.
/// That alone would be survivable. The deciding reason is the second: any
/// markdown package brings its own inline parser, and CLAUDE.md requires
/// that everything rendering maths in this app agrees about what a string
/// means. `MathText` and `FullLatexView` are already held to that, with a
/// documented dialect — `\(...\)` inline, `\[...\]` and `$$...$$` display,
/// a lone `$` is a dollar sign — that exists because treating `$` as a
/// delimiter parsed the text between two WAEC prices as an expression. A
/// second parser is exactly the divergence that rule is there to prevent.
///
/// So this splits **blocks** only, and hands every inline span to
/// [FullLatexView]. Articles therefore render maths through the same
/// scanner as questions, inherit its red-monospace fallback on a parse
/// error, and cannot drift from it.
///
/// ## The block grammar
///
/// Deliberately small. Blank lines separate blocks; within a block, line
/// breaks are preserved for lists and folded for paragraphs.
///
/// ```text
/// # Heading            h1  (one per article at most, by convention)
/// ## Heading           h2
/// ### Heading          h3
/// - item  /  * item    bullet list
/// 1. item              numbered list (the author's own numbers are used)
/// > quote              callout
/// ---                  horizontal rule
/// \[ ... \]            display maths, alone on its own block
/// $$ ... $$            display maths, alone on its own block
/// anything else        paragraph
/// ```
///
/// Inline `**bold**` and `*italic*` are **not** supported, and that is on
/// purpose: `*` and `_` appear inside maths constantly, and a markdown
/// emphasis pass would have to know where the maths is — which is the
/// coupling this design exists to avoid. Authors use `\textbf{...}` and
/// `\textit{...}`, which `FullLatexView` already handles everywhere else
/// in the app.
///
/// ## The lesson format
///
/// Everything above still holds for plain text. On top of it, the body is
/// parsed by `parseLessonDoc` (`lib/core/lessons/lesson_doc.dart`), which
/// adds fenced blocks — callouts, worked examples, quick checks, figures,
/// tables and the rest (`docs/LESSON_FORMAT.md`) — and hands plain runs
/// back to [parseArticleBlocks] unchanged, so an article that uses none of
/// them renders exactly as it always did.
class ArticleView extends StatelessWidget {
  const ArticleView({
    super.key,
    required this.body,
    this.textStyle,
    this.authorPreview = false,
    this.decorate,
  });

  final String body;

  /// Base style for paragraph text. Headings derive from `AppTheme`, not
  /// from this, so an article cannot accidentally restyle the app.
  final TextStyle? textStyle;

  /// True in the editor's preview: author to-dos are shown. Students never
  /// see them.
  final bool authorPreview;

  /// Wraps each top-level block; see [BlockDecorator].
  final BlockDecorator? decorate;

  /// The paragraph style an article uses unless given another. Callers
  /// that apply the student's reading settings (line spacing, font) start
  /// from this, so the defaults stay identical.
  static TextStyle defaultTextStyleOf(BuildContext context) => AppTheme.bodyLg
      .copyWith(color: context.palette.textPrimary, height: 1.6);

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? defaultTextStyleOf(context);

    final doc = parseLessonDoc(body);
    if (doc.isEmpty) return const SizedBox.shrink();

    return LessonBlocksColumn(
      blocks: doc.blocks,
      base: base,
      authorPreview: authorPreview,
      decorate: decorate,
    );
  }
}

/// What kind of block a chunk of article source is.
enum ArticleBlockKind { heading1, heading2, heading3, paragraph, bullets, numbers, quote, rule, displayMath }

/// One parsed block. Pure data — [parseArticleBlocks] is testable without
/// pumping a widget, which is the point of splitting it out.
class ArticleBlock {
  const ArticleBlock(this.kind, this.lines);

  final ArticleBlockKind kind;

  /// One entry per list item; a single joined entry for everything else.
  final List<String> lines;

  String get text => lines.isEmpty ? '' : lines.first;

  double get spacingBefore => switch (kind) {
    ArticleBlockKind.heading1 => 28,
    ArticleBlockKind.heading2 => 26,
    ArticleBlockKind.heading3 => 20,
    ArticleBlockKind.rule => 24,
    ArticleBlockKind.displayMath => 18,
    _ => 14,
  };
}

/// Splits article source into blocks.
///
/// Blank-line separated, with two exceptions that would otherwise need the
/// author to think about whitespace: consecutive list items form one list
/// without blank lines between them, and a heading or rule ends the block
/// before it even when no blank line follows.
List<ArticleBlock> parseArticleBlocks(String source) {
  final blocks = <ArticleBlock>[];
  final lines = source.replaceAll('\r\n', '\n').split('\n');

  // Accumulators for the block currently being read.
  var paragraph = <String>[];
  var quote = <String>[];
  var items = <String>[];
  ArticleBlockKind? listKind;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(
      ArticleBlock(ArticleBlockKind.paragraph, [paragraph.join(' ').trim()]),
    );
    paragraph = [];
  }

  // Consecutive `>` lines are one quote, wrapped the way a paragraph's
  // lines are — an author hard-wrapping a long callout means one box, not
  // one box per line. A blank line still separates two quotes.
  void flushQuote() {
    if (quote.isEmpty) return;
    blocks.add(ArticleBlock(ArticleBlockKind.quote, [quote.join(' ').trim()]));
    quote = [];
  }

  void flushList() {
    if (items.isEmpty) return;
    blocks.add(ArticleBlock(listKind!, items));
    items = [];
    listKind = null;
  }

  void flushAll() {
    flushParagraph();
    flushQuote();
    flushList();
  }

  for (var raw in lines) {
    final line = raw.trimRight();
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flushAll();
      continue;
    }

    // Horizontal rule. Checked before the bullet test so a line of "---"
    // is not read as an empty list item.
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      flushAll();
      blocks.add(const ArticleBlock(ArticleBlockKind.rule, ['']));
      continue;
    }

    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushAll();
      final kind = switch (heading.group(1)!.length) {
        1 => ArticleBlockKind.heading1,
        2 => ArticleBlockKind.heading2,
        _ => ArticleBlockKind.heading3,
      };
      blocks.add(ArticleBlock(kind, [heading.group(2)!.trim()]));
      continue;
    }

    // A display-maths block standing alone. Kept as its own block so it
    // can be centred and given room, rather than sitting inline in a
    // paragraph — `FullLatexView` renders the delimiters either way, but
    // a centred equation is what makes an article readable.
    if ((trimmed.startsWith(r'\[') && trimmed.endsWith(r'\]')) ||
        (trimmed.startsWith(r'$$') &&
            trimmed.endsWith(r'$$') &&
            trimmed.length > 4)) {
      flushAll();
      blocks.add(ArticleBlock(ArticleBlockKind.displayMath, [trimmed]));
      continue;
    }

    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      if (listKind != null && listKind != ArticleBlockKind.bullets) flushList();
      listKind = ArticleBlockKind.bullets;
      items.add(bullet.group(1)!.trim());
      continue;
    }

    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      flushParagraph();
      if (listKind != null && listKind != ArticleBlockKind.numbers) flushList();
      listKind = ArticleBlockKind.numbers;
      // The author's own number is kept rather than re-derived, so a list
      // that deliberately starts at 3 still reads as starting at 3.
      items.add('${numbered.group(1)}. ${numbered.group(2)!.trim()}');
      continue;
    }

    final quoted = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (quoted != null) {
      flushParagraph();
      flushList();
      quote.add(quoted.group(1)!.trim());
      continue;
    }

    flushQuote();
    flushList();
    paragraph.add(trimmed);
  }

  flushAll();
  return blocks;
}

/// Renders one block of the original article grammar. Public so the
/// lesson renderer draws basic blocks through exactly this code.
class ArticleBlockView extends StatelessWidget {
  const ArticleBlockView({super.key, required this.block, required this.base});

  final ArticleBlock block;
  final TextStyle base;

  TextStyle _headingStyle(Color color) => switch (block.kind) {
    ArticleBlockKind.heading1 => AppTheme.heading1.copyWith(color: color),
    ArticleBlockKind.heading2 => AppTheme.heading2.copyWith(color: color),
    _ => AppTheme.heading3.copyWith(color: color, fontWeight: FontWeight.w700),
  };

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case ArticleBlockKind.heading1:
      case ArticleBlockKind.heading2:
      case ArticleBlockKind.heading3:
        return FullLatexView(
          latex: block.text,
          textStyle: _headingStyle(context.palette.textPrimary),
        );

      case ArticleBlockKind.rule:
        return Container(height: 1, color: context.palette.border);

      case ArticleBlockKind.displayMath:
        // Horizontally scrollable: a wide equation must not force the
        // whole article to scroll sideways.
        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: FullLatexView(latex: block.text, textStyle: base),
          ),
        );

      case ArticleBlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border(
              left: BorderSide(color: AppColors.secondary, width: 3),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: FullLatexView(
            latex: block.text,
            textStyle: base.copyWith(color: context.palette.textSecondary),
          ),
        );

      case ArticleBlockKind.bullets:
      case ArticleBlockKind.numbers:
        final isBullets = block.kind == ArticleBlockKind.bullets;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < block.lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBullets) ...[
                    Padding(
                      // Nudged down to sit on the first line's baseline
                      // rather than its ascender.
                      padding: const EdgeInsets.only(top: 8, left: 4, right: 12),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(width: 4),
                  Expanded(
                    child: FullLatexView(
                      latex: block.lines[i],
                      textStyle: base,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );

      case ArticleBlockKind.paragraph:
        return FullLatexView(latex: block.text, textStyle: base);
    }
  }
}
