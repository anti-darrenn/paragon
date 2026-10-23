import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';

/// What a message, tag or toast means, and so its colour and icon.
enum Tone { neutral, info, success, warning, danger }

extension ToneLook on Tone {
  /// Words and icons in this tone, readable on the page in either theme.
  Color foreground(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      Tone.neutral => p.textSecondary,
      Tone.info => p.infoFg,
      Tone.success => p.successFg,
      Tone.warning => p.warningFg,
      Tone.danger => p.dangerFg,
    };
  }

  /// The bright colour a tinted fill or a border is made from.
  Color fill(BuildContext context) => switch (this) {
    Tone.neutral => context.palette.textSecondary,
    Tone.info => AppColors.accentBlue,
    Tone.success => AppColors.correct,
    Tone.warning => AppColors.warning,
    Tone.danger => AppColors.wrong,
  };

  IconData get icon => switch (this) {
    Tone.neutral => Icons.info_outline_rounded,
    Tone.info => Icons.info_outline_rounded,
    Tone.success => Icons.check_circle_outline_rounded,
    Tone.warning => Icons.warning_amber_rounded,
    Tone.danger => Icons.error_outline_rounded,
  };
}
