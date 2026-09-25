import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/providers/reading_settings_provider.dart';
import 'package:paragon/features/lesson/video_pane.dart';
import 'package:paragon/features/settings/reading_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading settings: defaults, persistence, the app-wide text scaler,
/// low-data video loading, and the settings screen.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A container whose stored prefs have been read, as after startup.
  Future<ProviderContainer> loaded() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(readingPrefsProvider.future);
    return c;
  }

  group('defaults and persistence', () {
    test('with nothing stored: 1.0 text, normal spacing, default font, '
        'low-data off', () async {
      final c = await loaded();
      final s = c.read(readingSettingsProvider);
      expect(s, ReadingSettings.defaults);
      expect(c.read(textScaleProvider), 1.0);
      expect(c.read(lineSpacingProvider), 1.0);
      expect(c.read(readingFontProvider), ReadingFont.standard);
      expect(c.read(lowDataModeProvider), isFalse);
    });

    test('changes persist and are restored by a fresh container', () async {
      final first = await loaded();
      final n = first.read(readingSettingsProvider.notifier);
      await n.setTextScaleStep(3);
      await n.setLineSpacing(LineSpacing.loose);
      await n.setFont(ReadingFont.hyperlegible);
      await n.setLowDataMode(true);

      final second = await loaded();
      expect(second.read(textScaleProvider), 1.3);
      expect(second.read(lineSpacingProvider), 1.3);
      expect(second.read(readingFontProvider), ReadingFont.hyperlegible);
      expect(second.read(lowDataModeProvider), isTrue);
    });

    test('reset clears storage, not just memory', () async {
      final first = await loaded();
      final n = first.read(readingSettingsProvider.notifier);
      await n.setTextScaleStep(4);
      await n.setLowDataMode(true);
      await n.reset();
      expect(first.read(readingSettingsProvider), ReadingSettings.defaults);

      final second = await loaded();
      expect(second.read(readingSettingsProvider), ReadingSettings.defaults);
    });

    test(
      'garbage in storage falls back to defaults instead of throwing',
      () async {
        SharedPreferences.setMockInitialValues({
          'reading.textScaleStep': 99,
          'reading.lineSpacing': 'enormous',
          'reading.font': 'comicSans',
        });
        final c = await loaded();
        expect(c.read(readingSettingsProvider), ReadingSettings.defaults);
      },
    );
  });

  group('app-wide text scaler', () {
    const system = TextScaler.linear(1.2);

    Future<TextScaler> scalerUnder(
      WidgetTester tester, {
      Map<String, Object> stored = const {},
    }) async {
      SharedPreferences.setMockInitialValues(stored);
      late TextScaler seen;
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: system),
            child: ReadingSettingsScope(
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.textScalerOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return seen;
    }

    testWidgets('control: nothing stored leaves the system scaler untouched', (
      tester,
    ) async {
      final seen = await scalerUnder(tester);
      expect(identical(seen, system), isTrue);
      expect(seen.scale(10), 12);
    });

    testWidgets('a stored size multiplies the system scaler, not replaces it', (
      tester,
    ) async {
      final seen = await scalerUnder(
        tester,
        stored: {'reading.textScaleStep': 4}, // 1.5
      );
      expect(seen.scale(10), closeTo(10 * 1.2 * 1.5, 1e-9));
    });
  });

  group('low-data video pane', () {
    const video = LearnResource(
      id: 'v',
      type: LearnResourceType.video,
      order: 1,
      title: 'A video',
      subjectId: 's1',
      topicId: 't1',
      youtubeId: 'abcdefghijk',
    );
    // Stands in for LessonVideoPlayer: the YouTube webview has no
    // platform implementation under flutter_test.
    Widget fakePlayer(String id) => Text('PLAYER $id');

    Future<void> pumpPane(WidgetTester tester, {required bool lowData}) async {
      SharedPreferences.setMockInitialValues({'reading.lowDataMode': lowData});
      // Settings already read, as app.dart guarantees: it holds the first
      // frame until they are, so no screen ever builds on the defaults.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(readingPrefsProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VideoPane(
                  resource: video,
                  isOffline: false,
                  playerBuilder: fakePlayer,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('control: low-data off builds the player straight away', (
      tester,
    ) async {
      await pumpPane(tester, lowData: false);
      expect(find.text('PLAYER abcdefghijk'), findsOneWidget);
      expect(find.text('Tap to load video'), findsNothing);
    });

    testWidgets('low-data on holds the player back until tapped', (
      tester,
    ) async {
      await pumpPane(tester, lowData: true);
      expect(find.text('Tap to load video'), findsOneWidget);
      expect(find.text('PLAYER abcdefghijk'), findsNothing);

      await tester.tap(find.text('Tap to load video'));
      await tester.pumpAndSettle();
      expect(find.text('PLAYER abcdefghijk'), findsOneWidget);
      expect(find.text('Tap to load video'), findsNothing);
    });
  });

  group('settings screen', () {
    Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReadingSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders the preview, with maths, and every control', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('reading-preview')), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Line spacing'), findsOneWidget);
      expect(find.text('Reading font'), findsOneWidget);
      expect(find.text('Low-data mode'), findsOneWidget);
      expect(find.text('Reset to defaults'), findsOneWidget);
    });

    testWidgets('choices apply, and Reset to defaults restores them', (
      tester,
    ) async {
      final c = await pumpScreen(tester);

      await tester.tap(find.text('Larger'));
      await tester.tap(find.text('Loose'));
      await tester.tap(find.byKey(const ValueKey('low-data-switch')));
      await tester.pumpAndSettle();
      expect(c.read(textScaleProvider), 1.3);
      expect(c.read(lineSpacingProvider), 1.3);
      expect(c.read(lowDataModeProvider), isTrue);

      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      expect(c.read(readingSettingsProvider), ReadingSettings.defaults);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('reading.')), isEmpty);
    });
  });
}
