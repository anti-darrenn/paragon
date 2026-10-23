import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/core/theme/app_palette.dart';
import 'package:paragon/core/theme/tokens.dart';
import 'package:paragon/core/widgets/motion/confetti.dart';
import 'package:paragon/core/widgets/ui/ui.dart';

/// WCAG relative luminance and contrast, to pin the palette's text tones.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('palette text tones read on their own background (WCAG AA)', () {
    for (final (name, palette) in [
      ('dark', AppPalette.dark),
      ('light', AppPalette.light),
    ]) {
      test(name, () {
        for (final (tone, colour) in [
          ('primaryFg', palette.primaryFg),
          ('successFg', palette.successFg),
          ('dangerFg', palette.dangerFg),
          ('warningFg', palette.warningFg),
          ('infoFg', palette.infoFg),
        ]) {
          expect(
            contrast(colour, palette.background),
            greaterThanOrEqualTo(4.5),
            reason: '$name $tone on the background',
          );
          expect(
            contrast(colour, palette.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name $tone on a surface',
          );
        }
      });
    }

    // Control: the bright brand orange is exactly what fails on white, so
    // this test would catch the light palette pointing back at it.
    test('control: bright orange fails as text on white', () {
      expect(
        contrast(AppColors.primary, AppPalette.light.surface),
        lessThan(3),
      );
    });

    test('strong fills carry white text', () {
      expect(
        contrast(Colors.white, AppColors.successStrong),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Colors.white, AppColors.dangerStrong),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('reduced motion', () {
    testWidgets('Motion.of is zero when the device asks for less motion', (
      tester,
    ) async {
      late Duration still, moving;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              still = Motion.of(context, Motion.slow);
              return const SizedBox();
            },
          ),
          still: true,
        ),
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              moving = Motion.of(context, Motion.slow);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(still, Duration.zero);
      expect(moving, Motion.slow);
    });

    testWidgets('confetti draws nothing under reduced motion', (tester) async {
      await tester.pumpWidget(_app(const Confetti(), still: true));
      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      await tester.pumpWidget(_app(const Confetti(key: ValueKey('moving'))));
      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a skeleton holds still under reduced motion', (tester) async {
      await tester.pumpWidget(_app(const SkeletonBox(width: 40), still: true));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        _app(const SkeletonBox(key: ValueKey('moving'), width: 40)),
      );
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
