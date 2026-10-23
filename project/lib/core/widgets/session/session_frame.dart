/// The frame every question session sits in — drill, exercises, quick
/// quizzes, mistakes practice, the taster, and (marked at the end) the
/// topic test, unit test and course challenge:
///
/// - [SessionLayout]: a pinned progress header, the question in a readable
///   column, and a bar pinned to the bottom.
/// - [SessionHeader]: "Question 3 of 10" over segmented progress.
/// - [QuestionCard]: the question itself, in a card.
/// - [FeedbackPanel]: the worked answer, after a question is checked.
/// - [SessionKeys]: A–E or 1–5 choose an option; Enter checks or goes on.
/// - [SessionActionBar]: Check, then the verdict and Continue
///   (instant feedback).
/// - [SessionNavBar]: Back and Next (marked at the end — no verdicts).
///
/// None of it reads a provider, so a session works without a ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../full_latex_view.dart';
import '../nav/nav_destinations.dart';
import '../question_image.dart';
import '../question_source_badge.dart';
import '../ui/ui.dart';

/// The reading width of a question session.
const double kSessionMaxWidth = 720;

/// Height of the bar pinned under a session, so overlays (the study
/// tools) can sit above it.
const double kSessionBarHeight = 76;

/// A session's page: [header] pinned at the top, [children] scrolling in
/// a centred column, [bar] pinned at the bottom.
///
/// Where the height is unbounded (inside another scroll view, as an
/// exercise in a lesson is) it lays everything out in one column with the
/// bar after the content, so it works embedded too.
class SessionLayout extends StatelessWidget {
  const SessionLayout({
    super.key,
    this.header,
    required this.children,
    this.bar,
    this.controller,
    this.maxWidth = kSessionMaxWidth,
  });

  final Widget? header;
  final List<Widget> children;
  final Widget? bar;
  final ScrollController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    Widget column(Widget child, {EdgeInsets? padding}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              if (header != null) const SizedBox(height: 16),
              content,
              if (bar != null) ...[const SizedBox(height: 16), bar!],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              column(
                header!,
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                child: column(content),
              ),
            ),
            ?bar,
          ],
        );
      },
    );
  }
}

/// "Question 3 of 10", an optional [note] beside it, and segmented
/// progress beneath.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.index,
    required this.total,
    required this.states,
    this.note,
  });

  /// Zero-based index of the question on screen.
  final int index;
  final int total;
  final List<SegmentState> states;

  /// "Marked at the end", "3 answered".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Question ${index + 1} of $total',
              style: AppTheme.label.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '· ${note!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SegmentedProgress(
          states: states,
          current: index,
          semanticsLabel: 'Question ${index + 1} of $total',
        ),
      ],
    );
  }
}

/// The question: where it is from, how hard it is, its stem and its
/// diagram, in a card. The options sit below it, outside the card.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    this.showSource = true,
    this.showDifficulty = true,
  });

  final Question question;
  final bool showSource;
  final bool showDifficulty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSource)
              QuestionSourceBadge(
                question: question,
                showDifficulty: showDifficulty,
              ),
            FullLatexView(
              latex: question.text,
              textStyle: AppTheme.questionStem.copyWith(
                color: context.palette.textStrong,
              ),
            ),
            QuestionImage(assetId: question.imageId),
          ],
        ),
      ),
    );
  }
}

/// The worked answer, shown once a question is checked. Edged in the
/// verdict's colour — it used to be green even after a wrong answer.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.question,
    required this.right,
    this.missingNote = 'No worked answer yet for this question.',
  });

  final Question question;
  final bool right;

  /// Said when there is no worked answer (about one past question in five,
  /// audit B1), rather than leaving a gap. Null says nothing.
  final String? missingNote;

  bool get hasWorking =>
      question.explanation.trim().isNotEmpty ||
      question.explanationImageId != null;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (!hasWorking) {
      if (missingNote == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(
          missingNote!,
          style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
        ),
      );
    }
    final edge = right ? AppColors.correct : AppColors.wrong;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: p.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Worked answer',
                            style: AppTheme.label.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (question.explanation.trim().isNotEmpty)
                        FullLatexView(
                          latex: question.explanation,
                          textStyle: AppTheme.bodyMd.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      QuestionImage.workedAnswer(
                        assetId: question.explanationImageId,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard control for a session: A–E or 1–9 pick an option, Enter
/// checks or goes on. Ignores keys while a text field has focus, so typing
/// in the calculator never picks an answer.
class SessionKeys extends StatelessWidget {
  const SessionKeys({
    super.key,
    required this.child,
    required this.optionCount,
    this.onSelect,
    this.onEnter,
  });

  final Widget child;
  final int optionCount;

  /// Null while options cannot be picked.
  final ValueChanged<int>? onSelect;

  /// Null while Enter has nothing to do.
  final VoidCallback? onEnter;

  /// The option a key names: 0 for A or 1, 1 for B or 2, …; null otherwise.
  static int? optionFor(LogicalKeyboardKey key) {
    final label = key.keyLabel.toUpperCase();
    if (label.length != 1) return null;
    final c = label.codeUnitAt(0);
    if (c >= 0x41 && c <= 0x45) return c - 0x41; // A–E
    if (c >= 0x31 && c <= 0x39) return c - 0x31; // 1–9
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null &&
            (focused.widget is EditableText ||
                focused.findAncestorWidgetOfExactType<EditableText>() !=
                    null)) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final i = optionFor(key);
        if (i != null && i < optionCount && onSelect != null) {
          onSelect!(i);
          return KeyEventResult.handled;
        }
        if ((key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter) &&
            onEnter != null) {
          onEnter!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Where an instant-feedback question stands.
enum SessionVerdict {
  /// Not checked yet.
  none,
  right,
  wrong,

  /// Wrong, with another try allowed (exercises).
  retry,
}

/// The bar under an instant-feedback question: Check, then the verdict in
/// words and an icon with Continue, tinted green or red.
class SessionActionBar extends StatelessWidget {
  const SessionActionBar({
    super.key,
    required this.verdict,
    required this.label,
    required this.onPressed,
    this.message,
    this.optionCount,
  });

  final SessionVerdict verdict;

  /// "Check", "Continue", "See results".
  final String label;

  /// Null disables the button (nothing chosen yet).
  final VoidCallback? onPressed;

  /// What the verdict says — usually an [AnswerVerdict]. Shown once the
  /// question is checked.
  final Widget? message;

  /// For the keyboard hint shown before checking, on a wide screen.
  final int? optionCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = switch (verdict) {
      SessionVerdict.right => AppColors.correct,
      SessionVerdict.wrong => AppColors.wrong,
      SessionVerdict.retry => AppColors.warning,
      SessionVerdict.none => null,
    };
    final tone = switch (verdict) {
      SessionVerdict.right => ButtonTone.success,
      SessionVerdict.wrong => ButtonTone.destructive,
      _ => ButtonTone.primary,
    };
    final wide = navLayoutFor(context) == NavLayout.topBar;
    final letters = optionCount == null
        ? null
        : 'A–${String.fromCharCode(64 + optionCount!.clamp(1, 9))}';
    final Widget? lead = verdict != SessionVerdict.none
        ? message
        : (wide && letters != null
              ? Text(
                  '$letters or 1–${optionCount!} to choose · Enter to check',
                  style: AppTheme.label.copyWith(color: p.textSecondary),
                )
              : null);
    final button = AppButton(
      label: label,
      tone: tone,
      onPressed: onPressed,
      expand: !wide,
    );
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.curve,
      decoration: BoxDecoration(
        color: tint == null
            ? p.surface
            : Color.alphaBlend(tint.withAlpha(30), p.surface),
        border: Border(top: BorderSide(color: tint ?? p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSessionMaxWidth + 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: lead ?? const SizedBox()),
                        const SizedBox(width: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 160),
                          child: button,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (lead != null) ...[lead, const SizedBox(height: 10)],
                        button,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar under a question marked at the end: Back and Next, no verdict.
class SessionNavBar extends StatelessWidget {
  const SessionNavBar({
    super.key,
    required this.nextLabel,
    required this.onNext,
    this.onBack,
    this.backLabel = 'Back',
    this.nextLoading = false,
  });

  final String nextLabel;
  final VoidCallback? onNext;

  /// Null on the first question.
  final VoidCallback? onBack;
  final String backLabel;
  final bool nextLoading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSessionMaxWidth + 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  AppButton(
                    label: backLabel,
                    tone: ButtonTone.secondary,
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: nextLabel,
                      onPressed: onNext,
                      loading: nextLoading,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
