import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/progress/course_progress.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/core/widgets/report_problem_button.dart';
import 'package:paragon/features/taster/taster_screen.dart';

/// App UX fixes from the 15 Oct 2026 audit that are pure enough to pin.
void main() {
  group('practised topics count topic tests, not only drill (C3, C4)', () {
    final drill = UserProgress.fromDocument({
      'topics': {
        'drilled': {'answered': 4, 'correct': 3, 'subjectId': 's'},
        'opened': {'answered': 0, 'correct': 0, 'subjectId': 's'},
      },
    });
    final tests = TopicTestProgress.fromDocument({
      'topics': {
        'tested': {'passed': true, 'bestScore': 80, 'attempts': 1},
        'failed': {'passed': false, 'bestScore': 40, 'attempts': 2},
        'drilled': {'passed': true, 'bestScore': 90, 'attempts': 1},
      },
    });

    test('a topic test or a drill answer each count, once', () {
      expect(practisedTopicIds(drill, tests), {'drilled', 'tested', 'failed'});
    });

    test('control: with no tests it is drill alone, as before', () {
      expect(
        practisedTopicIds(drill, TopicTestProgress.empty),
        drill.startedTopicIds.toSet(),
      );
      expect(practisedTopicIds(drill, TopicTestProgress.empty), {'drilled'});
    });
  });

  group('the taster leads with past questions (C14)', () {
    Question q(String id, {required bool past}) => Question(
      id: id,
      topicId: 't',
      subjectId: 's',
      text: id,
      options: const ['a', 'b'],
      correctIndex: 0,
      explanation: '',
      source: past ? 'waec' : 'drill',
      origin: past ? '' : 'ai_generated',
      year: past ? 2018 : null,
    );

    test('every question is a past one when there are enough', () {
      final pool = [
        for (var i = 0; i < 6; i++) q('g$i', past: false),
        for (var i = 0; i < 6; i++) q('p$i', past: true),
      ];
      for (var run = 0; run < 20; run++) {
        final picked = tasterQuestions(pool, 5);
        expect(picked, hasLength(5));
        expect(picked.every((q) => q.isPastQuestion), isTrue);
      }
    });

    test('practice only tops up a topic short of past questions', () {
      final pool = [
        q('p0', past: true),
        q('p1', past: true),
        for (var i = 0; i < 6; i++) q('g$i', past: false),
      ];
      final picked = tasterQuestions(pool, 5);
      expect(picked.take(2).every((q) => q.isPastQuestion), isTrue);
      expect(picked.skip(2).every((q) => q.isGenerated), isTrue);
    });
  });

  group(
    'the report sheet is honest about where the answer came from (C10)',
    () {
      Future<void> open(WidgetTester tester, {required bool generated}) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [currentUserProvider.overrideWithValue(null)],
            child: MaterialApp(
              home: Scaffold(
                body: ReportProblemButton(
                  questionId: 'q1',
                  isGenerated: generated,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.textContaining('Report a problem'));
        await tester.pumpAndSettle();
      }

      testWidgets('a past question does not blame a question bank', (
        tester,
      ) async {
        await open(tester, generated: false);
        expect(
          find.textContaining('checked as reports come in'),
          findsOneWidget,
        );
        expect(find.textContaining('public question bank'), findsNothing);
      });

      testWidgets('a practice question says it is ours', (tester) async {
        await open(tester, generated: true);
        expect(
          find.textContaining('Paragon practice question'),
          findsOneWidget,
        );
        expect(find.textContaining('public question bank'), findsNothing);
      });
    },
  );
}
