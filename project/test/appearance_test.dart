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
    expect(p.onLow, Colors.white38);
    expect(p.outline, Colors.white24);
    expect(p.outlineFaint, Colors.white12);
    expect(p.textStrong, Colors.white);
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
