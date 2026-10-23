import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// The colours confetti falls in when a screen gives none: the brand
/// orange and violet with the live-quiz tile colours.
const kConfettiColours = <Color>[
  AppColors.primary,
  AppColors.secondary,
  AppColors.roomBlue,
  AppColors.roomGreen,
  AppColors.medalGold,
  AppColors.roomRed,
];

/// Falling confetti, drawn, no package. Nothing at all with reduced motion.
///
/// Lay it over a screen in a `Stack` (it fills its box and ignores taps).
/// It falls once.
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.pieces = 90,
    this.colours = kConfettiColours,
  });

  final int pieces;
  final List<Color> colours;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  final _random = Random();
  late final _bits = [
    for (var i = 0; i < widget.pieces; i++)
      (
        x: _random.nextDouble(),
        delay: _random.nextDouble() * 0.5,
        speed: 0.6 + _random.nextDouble() * 0.6,
        spin: _random.nextDouble() * 6,
        colour: widget.colours[i % widget.colours.length],
      ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_bits, _c.value),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<
    ({double x, double delay, double speed, double spin, Color colour})
  >
  bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final p = ((t - b.delay) * b.speed).clamp(0.0, 1.2);
      if (p <= 0) continue;
      final y = p * size.height;
      final x = b.x * size.width + sin(p * 8 + b.spin) * 18;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * b.spin * 3);
      paint.color = b.colour.withAlpha(
        ((1 - (p - 0.8).clamp(0, 1)) * 255).round(),
      );
      canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
