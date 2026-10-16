import 'package:flutter/material.dart';

import '../a11y/speech_text.dart';
import '../theme/app_colors.dart';
import 'math_text.dart';
import '../theme/app_palette.dart';

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
class AnswerOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final (border, fg) = switch (state) {
      AnswerOptionState.idle => (
        context.palette.outline,
        context.palette.onHigh,
      ),
      // Not white: the tile has no solid fill, and white vanished on light.
      AnswerOptionState.selected => (
        AppColors.primary,
        context.palette.textStrong,
      ),
      AnswerOptionState.correct => (AppColors.correct, AppColors.correct),
      AnswerOptionState.wrong => (AppColors.wrong, AppColors.wrong),
      AnswerOptionState.ruledOut => (
        context.palette.outlineFaint,
        context.palette.onLow,
      ),
    };
    final verdict = switch (state) {
      AnswerOptionState.correct => ', correct',
      AnswerOptionState.wrong => ', incorrect',
      AnswerOptionState.ruledOut => ', already tried',
      _ => '',
    };

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: state == AnswerOptionState.selected,
      inMutuallyExclusiveGroup: true,
      label: 'Option ${letter(index)}: ${speakText(text)}$verdict',
      // excludeSemantics drops the InkWell's own action, so the tap is
      // given here, or a screen reader could hear an option but never
      // choose it.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: state == AnswerOptionState.selected
                  ? AppColors.primary.withAlpha(26)
                  : null,
              border: Border.all(color: border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    letter(index),
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MathText(
                    text: text,
                    useLightRenderer: true,
                    style: TextStyle(color: fg, fontSize: 15),
                  ),
                ),
                if (state == AnswerOptionState.correct)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.correct,
                    size: 20,
                  ),
                if (state == AnswerOptionState.wrong)
                  const Icon(Icons.cancel, color: AppColors.wrong, size: 20),
              ],
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
  });

  final bool right;

  /// The right option, named after a wrong answer. Ignored when it is not
  /// a real index (`-1` is "no verified answer").
  final int correctIndex;

  final String wrongText;

  @override
  Widget build(BuildContext context) {
    final color = right ? AppColors.correct : AppColors.wrong;
    final answer = !right && correctIndex >= 0
        ? ' The answer is ${AnswerOption.letter(correctIndex)}.'
        : '';
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(
              right ? Icons.check_circle : Icons.cancel,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                right ? 'Correct.' : '$wrongText$answer',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
