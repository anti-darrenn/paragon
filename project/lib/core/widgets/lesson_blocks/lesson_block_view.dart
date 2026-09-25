import 'package:flutter/material.dart';

import '../../../features/lesson/video_player.dart';
import '../../lessons/lesson_doc.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../article_view.dart';
import '../full_latex_view.dart';
import 'figure_block.dart';
import 'interactive_blocks.dart';

/// A list of lesson blocks, spaced the way articles always have been.
///
/// Used for the article itself and for every nested body (a callout's
/// contents, a worked example's steps), so nested text reads the same as
/// top-level text.
class LessonBlocksColumn extends StatelessWidget {
  const LessonBlocksColumn({
    super.key,
    required this.blocks,
    required this.base,
    this.authorPreview = false,
  });

  final List<LessonBlock> blocks;
  final TextStyle base;
  final bool authorPreview;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final b in blocks)
        if (authorPreview || b is! TodoBlock) b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) SizedBox(height: _spacingBefore(shown[i])),
          LessonBlockView(
            block: shown[i],
            base: base,
            authorPreview: authorPreview,
          ),
        ],
      ],
    );
  }

  static double _spacingBefore(LessonBlock b) =>
      b is BasicBlock ? b.block.spacingBefore : 20;
}

/// Renders one lesson block.
class LessonBlockView extends StatelessWidget {
  const LessonBlockView({
    super.key,
    required this.block,
    required this.base,
    this.authorPreview = false,
  });

  final LessonBlock block;
  final TextStyle base;
  final bool authorPreview;

  Widget _body(List<LessonBlock> blocks) => LessonBlocksColumn(
    blocks: blocks,
    base: base,
    authorPreview: authorPreview,
  );

  @override
  Widget build(BuildContext context) {
    final b = block;
    return switch (b) {
      BasicBlock() => ArticleBlockView(block: b.block, base: base),
      CalloutBlock() => CalloutBox(
        kind: b.kind,
        title: b.title,
        base: base,
        child: _body(b.body),
      ),
      ExampleBlock() => WorkedExampleView(
        block: b,
        base: base,
        authorPreview: authorPreview,
      ),
      TryItBlock() => TryItView(
        block: b,
        base: base,
        authorPreview: authorPreview,
      ),
      CheckBlock() => QuickCheckView(
        block: b,
        base: base,
        authorPreview: authorPreview,
      ),
      BankQuestionBlock() => BankQuestionView(block: b, base: base),
      CardBlock() => FlipCardView(front: b.front, back: b.back, base: base),
      FigureBlock() => FigureView(block: b, base: base),
      TableBlock() => LessonTableView(block: b, base: base),
      MoreBlock() => GoDeeperView(
        title: b.title,
        base: base,
        child: _body(b.body),
      ),
      VideoBlock() => _InlineVideo(youtubeId: b.youtubeId, base: base),
      TodoBlock() =>
        authorPreview
            ? _TodoNote(text: b.text, base: base)
            : const SizedBox.shrink(),
      UnknownBlock() => _body(b.body),
    };
  }
}

// ─── Callouts ─────────────────────────────────────────────────────────

(Color, IconData) calloutStyle(CalloutKind kind) => switch (kind) {
  CalloutKind.note => (AppColors.accentBlue, Icons.info_outline_rounded),
  CalloutKind.tip => (AppColors.correct, Icons.lightbulb_outline_rounded),
  CalloutKind.remember => (AppColors.secondary, Icons.bookmark_border_rounded),
  CalloutKind.mistake => (AppColors.wrong, Icons.error_outline_rounded),
  CalloutKind.exam => (AppColors.primary, Icons.school_outlined),
  CalloutKind.definition => (AppColors.secondary, Icons.menu_book_outlined),
  CalloutKind.formula => (AppColors.accentBlue, Icons.functions_rounded),
  CalloutKind.theorem => (AppColors.secondary, Icons.verified_outlined),
  CalloutKind.objectives => (AppColors.primary, Icons.flag_outlined),
  CalloutKind.summary => (AppColors.correct, Icons.checklist_rounded),
};

class CalloutBox extends StatelessWidget {
  const CalloutBox({
    super.key,
    required this.kind,
    required this.title,
    required this.base,
    required this.child,
  });

  final CalloutKind kind;
  final String title;
  final TextStyle base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (colour, icon) = calloutStyle(kind);
    // A definition's title is the term being defined: it leads, and the
    // kind becomes the small label. Everything else leads with the label.
    final label = kind.label.toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colour.withAlpha(22),
        border: Border(left: BorderSide(color: colour, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 8),
              Text(label, style: AppTheme.label.copyWith(color: colour)),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            FullLatexView(
              latex: title,
              textStyle: AppTheme.heading3.copyWith(
                color: AppColors.textPrimaryDark,
                fontSize: (base.fontSize ?? 16) + 1,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─── Go deeper ────────────────────────────────────────────────────────

class GoDeeperView extends StatefulWidget {
  const GoDeeperView({
    super.key,
    required this.title,
    required this.base,
    required this.child,
  });

  final String title;
  final TextStyle base;
  final Widget child;

  @override
  State<GoDeeperView> createState() => _GoDeeperViewState();
}

class _GoDeeperViewState extends State<GoDeeperView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FullLatexView(
                      latex: widget.title,
                      textStyle: widget.base.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

// ─── Tables ───────────────────────────────────────────────────────────

class LessonTableView extends StatelessWidget {
  const LessonTableView({super.key, required this.block, required this.base});

  final TableBlock block;
  final TextStyle base;

  Alignment _align(CellAlign a) => switch (a) {
    CellAlign.start => Alignment.centerLeft,
    CellAlign.center => Alignment.center,
    CellAlign.end => Alignment.centerRight,
  };

  Widget _cell(String text, CellAlign align, TextStyle style) => Container(
    alignment: _align(align),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: FullLatexView(latex: text, textStyle: style),
  );

  @override
  Widget build(BuildContext context) {
    final cellStyle = base.copyWith(height: 1.4);
    final headStyle = cellStyle.copyWith(fontWeight: FontWeight.w700);

    // Scrolls sideways on its own: a wide table must not make the whole
    // article scroll, the same rule display maths follows.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
          color: AppColors.borderDark,
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.surfaceDark),
            children: [
              for (var c = 0; c < block.header.length; c++)
                _cell(block.header[c], block.align[c], headStyle),
            ],
          ),
          for (final row in block.rows)
            TableRow(
              children: [
                for (var c = 0; c < row.length; c++)
                  _cell(row[c], block.align[c], cellStyle),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Video and to-do ──────────────────────────────────────────────────

class _InlineVideo extends StatelessWidget {
  const _InlineVideo({required this.youtubeId, required this.base});
  final String? youtubeId;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final id = youtubeId;
    if (id == null) {
      return Text(
        'This video is not available.',
        style: base.copyWith(color: AppColors.textSecondaryDark),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LessonVideoPlayer(videoId: id),
      ),
    );
  }
}

class _TodoNote extends StatelessWidget {
  const _TodoNote({required this.text, required this.base});
  final String text;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.construction_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'To do (students don\'t see this): $text',
              style: base.copyWith(color: AppColors.warning, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
