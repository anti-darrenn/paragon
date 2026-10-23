import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/sound/sfx.dart';
import 'package:paragon/core/theme/app_theme.dart';
import 'package:paragon/core/widgets/motion/confetti.dart';
import 'package:paragon/core/widgets/session/session_frame.dart';
import 'package:paragon/core/widgets/session/session_summary.dart';
import 'package:paragon/core/widgets/ui/ui.dart';

Widget _app(Widget body, {bool still = false, Size? size}) => MaterialApp(
  theme: AppTheme.dark,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: still,
        size: size ?? MediaQuery.of(context).size,
      ),
      child: Scaffold(body: body),
    ),
  ),
);

void main() {
  tearDown(() => Sfx.debugSink = null);

  group('SessionKeys', () {
    test('A–E and 1–9 name options; other keys do not', () {
      expect(SessionKeys.optionFor(LogicalKeyboardKey.keyA), 0);
      expect(SessionKeys.optionFor(LogicalKeyboardKey.keyE), 4);
      expect(SessionKeys.optionFor(LogicalKeyboardKey.digit1), 0);
      expect(SessionKeys.optionFor(LogicalKeyboardKey.digit3), 2);
      expect(SessionKeys.optionFor(LogicalKeyboardKey.keyF), isNull);
      expect(SessionKeys.optionFor(LogicalKeyboardKey.enter), isNull);
    });

    testWidgets('a key picks an option and Enter acts', (tester) async {
      final picked = <int>[];
      var entered = 0;
      await tester.pumpWidget(
        _app(
          SessionKeys(
            optionCount: 4,
            onSelect: picked.add,
            onEnter: () => entered++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE); // only 4 options
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, [1, 3]);
      expect(entered, 1);
    });

    testWidgets('keys typed into a text field are left alone', (tester) async {
      final picked = <int>[];
      await tester.pumpWidget(
        _app(
          SessionKeys(
            optionCount: 4,
            onSelect: picked.add,
            child: const TextField(),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(picked, isEmpty);
    });
  });

  group('SessionActionBar', () {
    testWidgets('Check is disabled until something is chosen', (tester) async {
      await tester.pumpWidget(
        _app(
          const Align(
            alignment: Alignment.bottomCenter,
            child: SessionActionBar(
              verdict: SessionVerdict.none,
              label: 'Check',
              onPressed: null,
              optionCount: 4,
            ),
          ),
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('after checking it shows the verdict and goes on', (
      tester,
    ) async {
      var went = false;
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: SessionActionBar(
              verdict: SessionVerdict.wrong,
              label: 'Continue',
              onPressed: () => went = true,
              message: const Text('Not quite. The answer is B.'),
            ),
          ),
        ),
      );
      expect(find.text('Not quite. The answer is B.'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(went, isTrue);
    });
  });

  group('SessionLayout', () {
    testWidgets('pins the bar under a scrolling column when it can', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SessionLayout(
            header: const Text('header'),
            bar: const SizedBox(height: 60, child: Text('bar')),
            children: [for (var i = 0; i < 40; i++) Text('line $i')],
          ),
        ),
      );
      final screen = tester.getSize(find.byType(Scaffold));
      expect(
        tester.getBottomLeft(find.text('bar')).dy,
        lessThanOrEqualTo(screen.height),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('puts the bar inline when the height is unbounded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: SessionLayout(
              bar: const Text('bar'),
              children: const [Text('question')],
            ),
          ),
        ),
      );
      expect(find.text('bar'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('bar')).dy,
        greaterThan(tester.getTopLeft(find.text('question')).dy),
      );
    });
  });

  group('SessionSummary', () {
    test('celebrates a high score, a pass or a level up, and nothing less', () {
      expect(SessionSummary.isWorthCelebrating(correct: 8, total: 10), isTrue);
      expect(SessionSummary.isWorthCelebrating(correct: 7, total: 10), isFalse);
      expect(
        SessionSummary.isWorthCelebrating(
          correct: 2,
          total: 10,
          levelledUp: true,
        ),
        isTrue,
      );
      expect(SessionSummary.isWorthCelebrating(correct: 0, total: 0), isFalse);
    });

    Widget summary({required bool celebrate}) => SingleChildScrollView(
      child: SessionSummary(
        title: 'Session complete',
        correct: 9,
        total: 10,
        celebrate: celebrate,
        primary: AppButton(label: 'Done', onPressed: () {}),
      ),
    );

    testWidgets('plays the finish sound, or the celebration', (tester) async {
      final heard = <SfxCue>[];
      Sfx.debugSink = heard.add;
      await tester.pumpWidget(_app(summary(celebrate: false)));
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpWidget(_app(summary(celebrate: true)));
      await tester.pumpAndSettle();
      expect(heard, [SfxCue.finish, SfxCue.celebrate]);
      expect(find.text('9 / 10'), findsOneWidget);
    });

    testWidgets('no confetti under reduced motion', (tester) async {
      await tester.pumpWidget(_app(summary(celebrate: true), still: true));
      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });

  // Modes never merge: a test marked at the end shows no verdict and makes
  // no sound until it is submitted. These screens may use the frame, but
  // only its marked-at-the-end bar.
  test('tests marked at the end never use the instant-feedback bar', () {
    for (final path in [
      'lib/features/topic_test_screen.dart',
      'lib/features/challenge_screen.dart',
      'lib/features/waec_exam_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('SessionNavBar'), reason: path);
      expect(source, isNot(contains('SessionActionBar')), reason: path);
      expect(source, isNot(contains('Sfx.play')), reason: path);
      expect(source, isNot(contains('SegmentState.right')), reason: path);
    }
  });
}
