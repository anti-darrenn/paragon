import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../progress/mastery.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The mastery circle that sits at the right-hand end of a topic row.
///
/// Discrete by design — it shows a *level*, not a percentage. See
/// `mastery.dart` for why, and note the consequence for this widget: the
/// arc only ever takes one of five lengths, so there is nothing to animate
/// between and no risk of a ring that looks 63% full meaning nothing in
/// particular.
///
/// Colour comes from the subject accent rather than a fixed palette, so a
/// Physics page reads as teal throughout and a Mathematics page as red.
/// Level is carried by how much of the ring is filled and by the tick, not
/// by hue alone — a student who cannot distinguish the accent from the
/// track still sees a quarter-ring versus a full one, and the tooltip
/// names the level in words.
class MasteryCircle extends StatelessWidget {
  const MasteryCircle({
    super.key,
    required this.level,
    required this.accent,
    this.size = 22,
    this.showTooltip = true,
  });

  final MasteryLevel level;
  final Color accent;
  final double size;
  final bool showTooltip;

  /// How saturated the arc is at each level. A faint quarter-ring for a
  /// barely-touched topic keeps a long course page from looking busier
  /// than the student's actual progress warrants.
  double get _accentOpacity => switch (level) {
    MasteryLevel.notStarted => 0,
    MasteryLevel.attempted => 0.5,
    MasteryLevel.familiar => 0.75,
    MasteryLevel.proficient => 1,
    MasteryLevel.mastered => 1,
  };

  @override
  Widget build(BuildContext context) {
    final circle = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MasteryCirclePainter(
          fraction: level.ringFraction,
          accent: accent.withAlpha((_accentOpacity * 255).round()),
          track: AppColors.borderDark,
          // Only the top level fills the disc. That reserves one
          // unmistakable state for "done with this", which is the whole
          // point of having levels above proficient.
          filled: level == MasteryLevel.mastered,
          strokeWidth: size < 20 ? 2 : 2.5,
        ),
        child: level.isComplete
            ? Center(
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.58,
                  color: level == MasteryLevel.mastered
                      ? AppColors.backgroundDark
                      : accent,
                ),
              )
            : null,
      ),
    );

    if (!showTooltip) return circle;
    return Tooltip(message: level.label, child: circle);
  }
}

/// The continuous ring used above a collection of topics — a module, a
/// subject card, a whole course.
///
/// Continuous here and discrete on the topics is not an inconsistency: a
/// single topic has no meaningful percentage, but "how much of this course
/// have I taken to proficiency" does, and it is the number a student
/// actually wants from a page heading.
class MasteryRing extends StatelessWidget {
  const MasteryRing({
    super.key,
    required this.fraction,
    required this.accent,
    this.size = 56,
    this.label,
  });

  /// 0..1. Values outside are clamped rather than trusted.
  final double fraction;
  final Color accent;
  final double size;

  /// Overrides the centred percentage. Used where the number would be
  /// noise — a card that already states "12 of 43 topics" beneath it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = fraction.clamp(0.0, 1.0);
    final percent = (value * 100).round();

    return Tooltip(
      message: '$percent% mastered',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MasteryCirclePainter(
            fraction: value,
            accent: accent,
            track: AppColors.borderDark,
            filled: false,
            strokeWidth: size < 40 ? 3 : 4,
          ),
          child: Center(
            child: Text(
              label ?? '$percent%',
              style: AppTheme.caption.copyWith(
                color: value == 0
                    ? AppColors.textSecondaryDark
                    : AppColors.textPrimaryDark,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasteryCirclePainter extends CustomPainter {
  const _MasteryCirclePainter({
    required this.fraction,
    required this.accent,
    required this.track,
    required this.filled,
    required this.strokeWidth,
  });

  final double fraction;
  final Color accent;
  final Color track;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    if (filled) {
      canvas.drawCircle(
        centre,
        radius + strokeWidth / 2,
        Paint()..color = accent,
      );
      return;
    }

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );

    if (fraction <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Twelve o'clock, clockwise — the direction every progress dial the
      // student has ever seen turns.
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_MasteryCirclePainter old) {
    return old.fraction != fraction ||
        old.accent != accent ||
        old.track != track ||
        old.filled != filled ||
        old.strokeWidth != strokeWidth;
  }
}
