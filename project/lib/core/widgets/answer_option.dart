import 'package:flutter/material.dart';

import '../a11y/speech_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'math_text.dart';

/// How one multiple-choice option currently reads.
enum AnswerOptionState {
  idle,
  selected,
  correct,
  wrong,

  /// Tried and wrong earlier in this question; no longer pickable.
  ruledOut,
}

/// One multiple-choice option, with the letter label the stored data
/// deliberately leaves out (`questions.options` holds bare text).
///
/// Every multiple-choice question a student answers with feedback uses it:
/// drill, the topic test, exercises, the taster, mistakes practice and the
/// unit test. Only the WAEC exam keeps its own tile, with the same
/// semantics. One widget means one answer to "what does a screen reader
/// hear": "Option B: 4, selected", then "Option B: 4, incorrect" (audit
/// D1–D4, 2026-10-15; drill options used to have no name at all).
class AnswerOption extends StatefulWidget {
  const AnswerOption({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    this.onTap,
  });

  final int index;
  final String text;
  final AnswerOptionState state;

  /// Null when the option cannot be picked right now.
  final VoidCallback? onTap;

  static String letter(int index) => String.fromCharCode(65 + index);

  @override
  State<AnswerOption> createState() => _AnswerOptionState();
}

class _AnswerOptionState extends State<AnswerOption>
    with SingleTickerProviderStateMixin {
  bool _focused = false;

  /// A one-off swell when this option is revealed as the right one.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void didUpdateWidget(AnswerOption old) {
    super.didUpdateWidget(old);
    if (widget.state == AnswerOptionState.correct &&
        old.state != AnswerOptionState.correct &&
        !reduceMotion(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = widget.state;
    final index = widget.index;
    final letter = AnswerOption.letter(index);

    // Border, fill tint, words, and the letter badge's fill and letter.
    final (
      Color border,
      Color? tint,
      Color fg,
      Color badge,
      Color badgeFg,
    ) = switch (state) {
      AnswerOptionState.idle => (
        p.outline,
        null,
        p.textPrimary,
        p.track,
        p.textPrimary,
      ),
      // Not white: the tile has no solid fill, and white vanished on light.
      AnswerOptionState.selected => (
        AppColors.primary,
        AppColors.primary,
        p.textStrong,
        AppColors.primary,
        AppColors.onPrimary,
      ),
      AnswerOptionState.correct => (
        AppColors.correct,
        AppColors.correct,
        p.successFg,
        AppColors.successStrong,
        Colors.white,
      ),
      AnswerOptionState.wrong => (
        AppColors.wrong,
        AppColors.wrong,
        p.dangerFg,
        AppColors.dangerStrong,
        Colors.white,
      ),
      AnswerOptionState.ruledOut => (
        p.outlineFaint,
        null,
        p.onLow,
        p.outlineFaint,
        p.onLow,
      ),
    };
    final verdict = switch (state) {
      AnswerOptionState.correct => ', correct',
      AnswerOptionState.wrong => ', incorrect',
      AnswerOptionState.ruledOut => ', already tried',
      _ => '',
    };
    final fill = tint == null
        ? (state == AnswerOptionState.ruledOut ? Colors.transparent : p.surface)
        : Color.alphaBlend(tint.withAlpha(28), p.surface);
    final radius = BorderRadius.circular(Radii.md);

    // The gap below sits outside the tappable area, so the ripple stays
    // inside the border.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        selected: state == AnswerOptionState.selected,
        inMutuallyExclusiveGroup: true,
        label: 'Option $letter: ${speakText(widget.text)}$verdict',
        // excludeSemantics drops the InkWell's own action, so the tap is
        // given here, or a screen reader could hear an option but never
        // choose it.
        onTap: widget.onTap,
        excludeSemantics: true,
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: _focused ? p.textStrong : border,
                width: _focused ? 2 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (f) => setState(() => _focused = f),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badge,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        letter,
                        style: AppTheme.bodyMd.copyWith(
                          color: badgeFg,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MathText(
                        text: widget.text,
                        useLightRenderer: true,
                        style: AppTheme.bodyLg.copyWith(color: fg, height: 1.4),
                      ),
                    ),
                    if (state == AnswerOptionState.correct) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: p.successFg, size: 22),
                    ],
                    if (state == AnswerOptionState.wrong) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.cancel, color: p.dangerFg, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Correct." or "Not quite. The answer is B." under a marked question,
/// in words and an icon, not only the option's colour (audit D3), and
/// announced: a live region is read as soon as it appears, so a screen
/// reader user hears the verdict without hunting for it.
class AnswerVerdict extends StatelessWidget {
  const AnswerVerdict({
    super.key,
    required this.right,
    required this.correctIndex,
    this.wrongText = 'Not quite.',
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final bool right;

  /// The right option, named after a wrong answer. Ignored when it is not
  /// a real index (`-1` is "no verified answer").
  final int correctIndex;

  final String wrongText;

  /// None inside a session's action bar, which spaces it itself.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = right ? context.palette.successFg : context.palette.dangerFg;
    final answer = !right && correctIndex >= 0
        ? ' The answer is ${AnswerOption.letter(correctIndex)}.'
        : '';
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Icon(
              right ? Icons.check_circle : Icons.cancel,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                right ? 'Correct.' : '$wrongText$answer',
                style: AppTheme.bodyLg.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
