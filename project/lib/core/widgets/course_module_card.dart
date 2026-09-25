import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/learn_progress_repository.dart';

import '../progress/course_progress.dart';
import '../progress/mastery.dart';
import '../repositories/course_repository.dart';
import '../repositories/progress_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_top_nav.dart';
import 'mastery_indicator.dart';

/// The repeating unit of a course index page: one bordered card split into
/// a narrow title region and a wide grid of topic links.
///
/// Layout, wide (>= [kCompactBreakpoint]):
///
///   ┌──────────────┬──────────────────────────────────────────┐
///   │ MODULE TITLE │  topic      topic      topic             │
///   │ 6 topics     │  topic      topic      topic             │
///   └──────────────┴──────────────────────────────────────────┘
///     ~28%            ~72%, 3 columns
///
/// Below the breakpoint the two regions stack and the grid drops to one
/// column, because a 28% title column on a phone leaves ~90px for the
/// right-hand grid.
class CourseModuleCard extends StatelessWidget {
  const CourseModuleCard({
    super.key,
    required this.module,
    required this.accent,
    required this.index,
    required this.gridColumns,
    required this.onTopicTap,
    this.progress = UserProgress.empty,
  });

  final CourseModule module;

  /// The student's counters. Defaults to empty so a caller with no
  /// progress to show renders the same card with untouched rings rather
  /// than needing a second widget.
  final UserProgress progress;

  /// Subject accent from `AppColors.forSubject` — the only thing that
  /// changes between one subject's cards and another's.
  final Color accent;

  /// Zero-based position in the course, shown as "Module 1", "Module 2"…
  /// Units carry an `order` field but not a displayed number, and students
  /// navigate by position far more readily than by name alone.
  final int index;

  /// Number of columns in the topic grid, measured once by the page from
  /// its own width and passed down, so every card on a page breaks at the
  /// same count instead of each measuring itself.
  final int gridColumns;

  /// Null for placeholder topics — the card renders them inert.
  final void Function(CourseTopic topic)? onTopicTap;

  static const int _titleFlex = 28;
  static const int _gridFlex = 72;
  static const double _dividerWidth = 1;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      // ClipRRect so the tinted title band's corners follow the card's
      // rounding instead of squaring off inside it.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitleRegion(
                    module: module,
                    accent: accent,
                    index: index,
                    progress: progress,
                    paintBackground: true,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderDark,
                  ),
                  _TopicGrid(
                    module: module,
                    accent: accent,
                    columns: gridColumns,
                    progress: progress,
                    onTopicTap: onTopicTap,
                  ),
                ],
              )
            : Stack(
                children: [
                  // The tinted band and the divider are painted as a
                  // background layer sized to the card, rather than by
                  // stretching the title region itself.
                  //
                  // The obvious alternative — IntrinsicHeight with a
                  // stretched Row — is wrong here: intrinsic height is
                  // computed against a child's *max intrinsic width*, so a
                  // module title that fits on one line unconstrained but
                  // wraps to two at the real 28% column width is measured
                  // short, and the card overflows by exactly one line
                  // ("Atomic Structure and Bonding" did, by 13px).
                  // Painting the band behind the content decouples the two:
                  // the Stack takes its height from the content Row, and
                  // Positioned.fill follows whatever that turns out to be.
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          flex: _titleFlex,
                          child: ColoredBox(
                            color: accent.withAlpha((0.07 * 255).round()),
                          ),
                        ),
                        const SizedBox(
                          width: _dividerWidth,
                          child: ColoredBox(color: AppColors.borderDark),
                        ),
                        const Expanded(flex: _gridFlex, child: SizedBox()),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: _titleFlex,
                        child: _TitleRegion(
                          module: module,
                          accent: accent,
                          index: index,
                          progress: progress,
                          paintBackground: false,
                        ),
                      ),
                      // Matches the divider in the background row so the
                      // two layers stay in register.
                      const SizedBox(width: _dividerWidth),
                      Expanded(
                        flex: _gridFlex,
                        child: _TopicGrid(
                          module: module,
                          accent: accent,
                          columns: gridColumns,
                          progress: progress,
                          onTopicTap: onTopicTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _TitleRegion extends StatelessWidget {
  const _TitleRegion({
    required this.module,
    required this.accent,
    required this.index,
    required this.progress,
    required this.paintBackground,
  });

  final CourseModule module;
  final Color accent;
  final int index;
  final UserProgress progress;

  /// True only in the stacked (compact) layout, where nothing paints the
  /// tint behind this region. In the side-by-side layout the card's
  /// background layer does it, so painting here too would double the wash.
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    final topicCount = module.topics.length;
    final practisable = module.practisableTopicCount;
    final started = module.startedCountIn(progress);
    final showRing = !module.isPlaceholder && practisable > 0;

    return Container(
      // Accent wash — subtle enough that ten of these stacked down the page
      // don't read as ten coloured blocks, strong enough to tell Physics
      // apart from Economics at a glance.
      color: paintBackground ? accent.withAlpha((0.07 * 255).round()) : null,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Module ${index + 1}',
                  style: AppTheme.caption.copyWith(
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              // The module's own ring, trailing the label so it lands on
              // the same right-hand edge as the topic circles below it.
              if (showRing)
                MasteryRing(
                  fraction: module.masteryIn(progress),
                  accent: accent,
                  size: 34,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            module.name,
            style: AppTheme.heading3.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            module.isPlaceholder
                ? '$topicCount ${topicCount == 1 ? 'topic' : 'topics'} planned'
                : '$topicCount ${topicCount == 1 ? 'topic' : 'topics'} · '
                      '${module.questionCount} questions',
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
          // Only once there is something to report. "0 of 6 started" on
          // every card of a course nobody has opened is a wall of zeroes,
          // and the empty rings already say as much.
          if (showRing && started > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$started of $practisable started',
              style: AppTheme.caption.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({
    required this.module,
    required this.accent,
    required this.columns,
    required this.progress,
    required this.onTopicTap,
  });

  final CourseModule module;
  final Color accent;
  final int columns;
  final UserProgress progress;
  final void Function(CourseTopic topic)? onTopicTap;

  static const double _columnGap = 24;
  static const double _rowGap = 18;

  @override
  Widget build(BuildContext context) {
    final rows = <List<CourseTopic?>>[];

    for (var i = 0; i < module.topics.length; i += columns) {
      final row = module.topics.skip(i).take(columns).toList();
      // Pad the last row so its cells keep the same width as every other
      // row's — otherwise two leftover topics would stretch across three
      // columns' worth of space.
      rows.add([
        ...row,
        ...List<CourseTopic?>.filled(columns - row.length, null),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: _rowGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _columnGap),
                  Expanded(
                    child: rows[r][c] == null
                        ? const SizedBox.shrink()
                        : TopicLink(
                            topic: rows[r][c]!,
                            accent: accent,
                            level: rows[r][c]!.levelIn(progress),
                            onTap: onTopicTap,
                          ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One topic link inside a module card. Live topics are tappable and
/// highlight on hover; placeholder topics are dimmed and inert, with a
/// tooltip saying why.
class TopicLink extends StatefulWidget {
  const TopicLink({
    super.key,
    required this.topic,
    required this.accent,
    required this.onTap,
    this.level = MasteryLevel.notStarted,
  });

  final CourseTopic topic;
  final Color accent;

  /// Drawn as a circle at the right-hand end of the row. Placeholder
  /// topics never show one — there is nothing to have practised.
  final MasteryLevel level;

  final void Function(CourseTopic topic)? onTap;

  @override
  State<TopicLink> createState() => _TopicLinkState();
}

/// "2 of 6 lessons" under a topic that has Learn content.
///
/// The denominator is `topics.lessonCount`, stored so this page does not
/// need one resources query per topic; the numerator comes from the one
/// `learn/{uid}` listener. Capped at the denominator, since a completion
/// can outlive a lesson that was later unpublished.
class _LessonsLine extends ConsumerWidget {
  const _LessonsLine({required this.topic, required this.accent});

  final CourseTopic topic;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref
        .watch(lessonProgressProvider)
        .forTopic(topic.id)
        .completed
        .length
        .clamp(0, topic.lessonCount);
    return Text(
      '$done of ${topic.lessonCount} ${topic.lessonCount == 1 ? 'lesson' : 'lessons'}',
      style: AppTheme.caption.copyWith(
        color: done == topic.lessonCount
            ? AppColors.correct
            : done > 0
            ? accent
            : AppColors.textSecondaryDark.withAlpha((0.75 * 255).round()),
      ),
    );
  }
}

class _TopicLinkState extends State<TopicLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = !widget.topic.isPlaceholder && widget.onTap != null;
    final nameColor = !isInteractive
        ? AppColors.textSecondaryDark
        : _isHovered
        ? widget.accent
        : AppColors.textPrimaryDark;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Nudges the marker onto the first line's optical centre.
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isInteractive
                  ? widget.accent.withAlpha((_isHovered ? 255 : 130))
                  : AppColors.borderDark,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.topic.name,
                style: AppTheme.bodyMd.copyWith(
                  color: nameColor,
                  height: 1.35,
                  decoration: _isHovered && isInteractive
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: widget.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.topic.isPlaceholder
                    ? 'Coming soon'
                    : widget.level.isStarted
                    // Once a student has worked on a topic, how far they
                    // have got matters more to them than how much material
                    // is left in it.
                    ? widget.level.label
                    : '${widget.topic.questionCount} questions',
                style: AppTheme.caption.copyWith(
                  color: widget.level.isStarted
                      ? widget.accent
                      : AppColors.textSecondaryDark.withAlpha(
                          (0.75 * 255).round(),
                        ),
                ),
              ),
              if (!widget.topic.isPlaceholder && widget.topic.lessonCount > 0)
                _LessonsLine(topic: widget.topic, accent: widget.accent),
            ],
          ),
        ),
        // The mastery circle, right-aligned on every row so the column of
        // them reads down the card as a single progress column.
        if (!widget.topic.isPlaceholder) ...[
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: MasteryCircle(level: widget.level, accent: widget.accent),
          ),
        ],
      ],
    );

    if (!isInteractive) {
      return Tooltip(
        message: 'This topic has not been written yet.',
        child: Opacity(opacity: 0.65, child: content),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap!(widget.topic),
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}
