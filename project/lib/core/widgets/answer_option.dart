import 'package:flutter/material.dart';

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
/// Shared so the in-lesson exercise does not grow a third copy of the tile
/// that drill and the topic test each build inline. Moving those two onto
/// it is a separate refactor.
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
      AnswerOptionState.idle => (context.palette.outline, context.palette.onHigh),
      AnswerOptionState.selected => (AppColors.primary, Colors.white),
      AnswerOptionState.correct => (AppColors.correct, AppColors.correct),
      AnswerOptionState.wrong => (AppColors.wrong, AppColors.wrong),
      AnswerOptionState.ruledOut => (context.palette.outlineFaint, context.palette.onLow),
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
      label: 'Option ${letter(index)}$verdict',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                  const Icon(Icons.check_circle, color: AppColors.correct, size: 20),
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
