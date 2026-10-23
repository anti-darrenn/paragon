import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// A score as a ring that fills when it appears, with the score written
/// in the middle ("7 / 10"). For results only: mastery is drawn by
/// `MasteryCircle` and `MasteryRing`, never by this.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.fraction,
    required this.label,
    this.caption,
    this.size = 148,
    this.color,
  });

  /// 0 to 1.
  final double fraction;

  /// The score, in the middle.
  final String label;

  /// Under the score, inside the ring ("correct").
  final String? caption;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colour = color ?? AppColors.primary;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: Motion.of(context, Motion.celebrate),
        curve: Motion.curve,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, colour, p.track, size * 0.075),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTheme.heading1.copyWith(
                  color: p.textStrong,
                  fontSize: size * 0.2,
                  height: 1.1,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: AppTheme.label.copyWith(color: p.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.colour, this.track, this.stroke);
  final double value;
  final Color colour, track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * pi, false, base);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * value,
      false,
      base
        ..color = colour
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.colour != colour || old.track != track;
}
