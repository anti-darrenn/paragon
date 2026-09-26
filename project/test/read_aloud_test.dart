import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/features/study/read_aloud/read_aloud_hooks.dart';
import 'package:paragon/features/study/read_aloud/speech_engine.dart';
import 'package:paragon/features/study/read_aloud/speech_segments.dart';

/// A speech engine that records what it was asked to do. [finish] plays
/// the part of the platform saying an utterance ended.
class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({this.available = true, this.throwOnSpeak = false});

  final bool available;
  final bool throwOnSpeak;
  final spoken = <String>[];
  final calls = <String>[];
  final rates = <double>[];
  VoidCallback? _complete;

  void finish() => _complete?.call();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw Exception('no engine');
    spoken.add(text);
    calls.add('speak');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume(String text) async => calls.add('resume:$text');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setRate(double multiplier) async => rates.add(multiplier);

  @override
  set onComplete(VoidCallback? callback) => _complete = callback;

  @override
  set onError(void Function(Object error)? callback) {}
}

const _lesson = '''
# Number bases

A base is how many digits a system uses.

- Base two uses \\(0\\) and \\(1\\).
- Base ten uses ten digits.

::: definition Number base
The number of distinct digits.
:::

::: check
What is \\( 101_2 \\) in base ten?
- [ ] 3
- [x] 5
--- why
SECRET-WHY \\( 4 + 0 + 1 = 5 \\)
:::

::: tryit Convert
Convert \\( 110_2 \\).
--- hint
SECRET-HINT
--- answer
SECRET-ANSWER
:::

::: todo SECRET-TODO
:::

::: card
FRONT
---
SECRET-BACK
:::

| Base | Digits |
|---|---|
| 2 | 0, 1 |
''';

LearnResource _article(String body) => LearnResource(
  id: 'r1',
  type: LearnResourceType.article,
  order: 1,
  title: 'Number bases',
  subjectId: 's',
  topicId: 't',
  body: body,
);

void main() {
  group('lessonSpeechSegments', () {
    final doc = parseLessonDoc(_lesson);
    final segments = lessonSpeechSegments(doc);
    final texts = segments.map((s) => s.text).toList();

    test('reads blocks in order, with labels', () {
      expect(texts.first, 'Number bases');
      expect(texts, contains('A base is how many digits a system uses.'));
      expect(texts, contains('Base two uses 0 and 1.'));
      expect(texts, contains('Definition: Number base.'));
      expect(texts, contains('The number of distinct digits.'));
      expect(texts, contains('Try it: Convert.'));
      expect(texts, contains('Revision card: FRONT.'));
      expect(texts, contains('Table with columns: Base, Digits.'));
      expect(texts, contains('Row 1. Base: 2; Digits: 0, 1.'));
    });

    test('a quick check reads its question and options', () {
      expect(
        texts,
        contains('What is one zero one, base two in base ten?'),
      );
      expect(texts, contains('Option B: 5'));
    });

    test('CONTROL: hidden answers, hints, to-dos and card backs are silent',
        () {
      final all = texts.join('\n');
      for (final secret in [
        'SECRET-WHY',
        'SECRET-HINT',
        'SECRET-ANSWER',
        'SECRET-TODO',
        'SECRET-BACK',
      ]) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('every segment carries its top-level block key', () {
      final keys = doc.blocks.map((b) => b.key).toSet();
      for (final s in segments) {
        expect(keys, contains(s.blockKey));
      }
      // The two list items belong to one block.
      final listKey = segments
          .firstWhere((s) => s.text == 'Base ten uses ten digits.')
          .blockKey;
      expect(
        segments.where((s) => s.blockKey == listKey).length,
        2,
      );
    });

    test('videos are skipped', () {
      final withVideo = parseLessonDoc(
        'Before.\n\n::: video dQw4w9WgXcQ\n:::\n\nAfter.',
      );
      expect(
        lessonSpeechSegments(withVideo).map((s) => s.text),
        ['Before.', 'After.'],
      );
    });
  });

  group('ReadAloudButton', () {
    Future<FakeSpeechEngine> pump(
      WidgetTester tester, {
      FakeSpeechEngine? engine,
      String body = 'First paragraph.\n\nSecond paragraph.',
    }) async {
      final fake = engine ?? FakeSpeechEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [speechEngineProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: Scaffold(
              body: _Host(resource: _article(body)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    Finder byKey(String k) => find.byKey(ValueKey(k));

    testWidgets('Listen, Pause, Resume, Stop', (tester) async {
      final engine = await pump(tester);
      expect(byKey('readAloud.listen'), findsOneWidget);

      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();
      expect(engine.spoken, ['First paragraph.']);
      expect(byKey('readAloud.pause'), findsOneWidget);
      expect(byKey('readAloud.stop'), findsOneWidget);

      await tester.tap(byKey('readAloud.pause'));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'pause');
      expect(byKey('readAloud.resume'), findsOneWidget);

      // A completion arriving while paused is not a cue to read on.
      engine.finish();
      await tester.pumpAndSettle();
      expect(engine.spoken, ['First paragraph.']);

      await tester.tap(byKey('readAloud.resume'));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'resume:First paragraph.');
      expect(byKey('readAloud.pause'), findsOneWidget);

      await tester.tap(byKey('readAloud.stop'));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'stop');
      expect(byKey('readAloud.listen'), findsOneWidget);
    });

    testWidgets('reads on to the next segment, then returns to idle',
        (tester) async {
      final engine = await pump(tester);
      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();

      engine.finish();
      await tester.pumpAndSettle();
      expect(engine.spoken, ['First paragraph.', 'Second paragraph.']);

      engine.finish();
      await tester.pumpAndSettle();
      expect(byKey('readAloud.listen'), findsOneWidget);
    });

    testWidgets('the block being read is marked', (tester) async {
      final engine = await pump(tester);
      final doc = parseLessonDoc('First paragraph.\n\nSecond paragraph.');
      final firstKey = doc.blocks.first.key;
      final secondKey = doc.blocks.last.key;

      double opacity(String key) => tester
          .widget<AnimatedOpacity>(byKey('readAloud.mark.$key'))
          .opacity;

      expect(opacity(firstKey), 0);
      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();
      expect(opacity(firstKey), 1);
      expect(opacity(secondKey), 0);

      engine.finish();
      await tester.pumpAndSettle();
      expect(opacity(firstKey), 0);
      expect(opacity(secondKey), 1);
    });

    testWidgets('the chosen speed is applied', (tester) async {
      final engine = await pump(tester);
      await tester.tap(byKey('readAloud.speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5×').last);
      await tester.pumpAndSettle();
      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();
      expect(engine.rates.last, 1.5);
    });

    testWidgets('leaving the lesson stops the voice', (tester) async {
      final engine = await pump(tester);
      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [speechEngineProvider.overrideWithValue(engine)],
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.calls, contains('stop'));
    });

    testWidgets('no voices: shown disabled, with a reason', (tester) async {
      await pump(tester, engine: FakeSpeechEngine(available: false));
      expect(byKey('readAloud.listen'), findsNothing);
      final button = tester.widget<ButtonStyleButton>(
        byKey('readAloud.unavailable'),
      );
      expect(button.onPressed, isNull);
      expect(
        find.byTooltip(ReadAloudButton.unavailableMessage),
        findsOneWidget,
      );
    });

    testWidgets('a platform exception returns to idle, never crashes',
        (tester) async {
      await pump(tester, engine: FakeSpeechEngine(throwOnSpeak: true));
      await tester.tap(byKey('readAloud.listen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byKey('readAloud.listen'), findsOneWidget);
    });
  });
}

/// The button plus the article's blocks, decorated the way `ArticlePane`
/// decorates them.
class _Host extends ConsumerWidget {
  const _Host({required this.resource});
  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decorate = readAloudDecorator(ref, resource);
    final doc = parseLessonDoc(resource.body);
    return Column(
      children: [
        ReadAloudButton(resource: resource),
        for (final b in doc.blocks) decorate(b, Text(b.source)),
      ],
    );
  }
}
