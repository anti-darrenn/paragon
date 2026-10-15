import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/prefs/account_prefs.dart';
import 'package:paragon/core/providers/appearance_provider.dart';
import 'package:paragon/core/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme choice and the palette behind it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('dark is the default, and an unknown name reads as dark', () {
    expect(Appearance.parse(null), Appearance.dark);
    expect(Appearance.parse('neon'), Appearance.dark);
    expect(Appearance.parse('light'), Appearance.light);
  });

  test('stored names are the ones the rules accept', () {
    expect(Appearance.values.map((a) => a.name), ['dark', 'light', 'system']);
  });

  test('the account copy reads back', () {
    expect(appearanceFromPrefs({'theme': 'system'}), Appearance.system);
    expect(appearanceFromPrefs({'font': 'standard'}), isNull);
  });

  test('a choice is kept on the device', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(appearanceProvider.notifier).set(Appearance.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.theme'), 'light');
    expect(c.read(appearanceProvider).mode, ThemeMode.light);
  });

  // The refactor's promise: the dark palette is exactly the colours the
  // app used before, so moving widgets onto it changed nothing in dark.
  test('the dark palette is the old dark colours', () {
    const p = AppPalette.dark;
    expect(p.onHigh, Colors.white70);
    expect(p.onMedium, Colors.white54);
    // onLow alone was raised (from white38) to pass WCAG AA; see below.
    expect(p.outline, Colors.white24);
    expect(p.outlineFaint, Colors.white12);
    expect(p.textStrong, Colors.white);
  });

  group('small text passes WCAG AA (4.5:1)', () {
    double luminance(Color c) {
      double ch(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color fg, Color bg) {
      final a = luminance(Color.alphaBlend(fg, bg));
      final b = luminance(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    for (final (name, p) in [
      ('dark', AppPalette.dark),
      ('light', AppPalette.light),
    ]) {
      test('$name: secondary, onMedium and onLow text on background and '
          'surface', () {
        for (final bg in [p.background, p.surface]) {
          for (final fg in [p.textSecondary, p.onMedium, p.onLow]) {
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$name $fg on $bg',
            );
          }
        }
      });
    }

    test('control: the old white38 failed, so this test can fail', () {
      expect(
        contrast(Colors.white38, AppPalette.dark.background),
        lessThan(4.5),
      );
    });
  });

  testWidgets('context.palette follows the theme', (tester) async {
    late AppPalette seen;
    await tester.pumpWidget(
      MaterialApp(
        // AppTheme itself fetches Google Fonts, which tests cannot; the
        // extension is what is under test.
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: Builder(
          builder: (context) {
            seen = context.palette;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, AppPalette.light);
  });
}
