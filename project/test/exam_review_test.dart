import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/exam/exam_result.dart';
import 'package:paragon/core/exam/waec_grade.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/exam_result_repository.dart';
import 'package:paragon/core/widgets/answer_option.dart';
import 'package:paragon/features/exam_review_screen.dart';

Question _q(String id, String topic) => Question(
  id: id,
  topicId: topic,
  subjectId: 's1',
  text: 'Stem $id',
  options: ['right$id', 'wrong$id', 'other$id', 'last$id'],
  correctIndex: 0,
  explanation: 'Working for $id.',
  source: 'waec',
);

void main() {
  final questions = [
    _q('q1', 'algebra'),
    _q('q2', 'geometry'),
    _q('q3', 'geometry'),
  ];
  final review = ExamReview(
    ExamResult.fromSitting(
      id: 'e1',
      subjectId: 's1',
      questions: questions,
      answers: {0: 0, 1: 1}, // q1 right, q2 wrong, q3 unanswered
      timed: true,
      durationSeconds: 600,
    ),
    {for (final q in questions) q.id: q},
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          courseProvider.overrideWith(
            (ref, key) async => throw StateError('offline'),
          ),
        ],
        child: MaterialApp(
          home: ExamReviewScreen(examId: 'e1', initial: review),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('score, the estimate and what it is not', (tester) async {
    await pump(tester);
    expect(find.text('1 / 3  (33%)'), findsOneWidget);
    expect(find.text('F9'), findsOneWidget);
    expect(find.text('Estimated grade: Fail'), findsOneWidget);
    expect(find.text(kGradeEstimateNote), findsOneWidget);
    expect(find.text('2 of 3 answered · 10 minutes'), findsOneWidget);
  });

  testWidgets('every question is marked and none can be re-answered', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Question 1 · Right'), findsOneWidget);
    expect(find.textContaining('Question 2 · Wrong'), findsOneWidget);
    expect(find.textContaining('Question 3 · Not answered'), findsOneWidget);
    final options = tester.widgetList<AnswerOption>(find.byType(AnswerOption));
    expect(options, hasLength(12));
    expect(options.every((o) => o.onTap == null), isTrue);
    expect(
      options.where((o) => o.state == AnswerOptionState.wrong),
      hasLength(1),
    );
  });

  testWidgets('weak topics are listed even when names cannot load', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Work on these next'), findsOneWidget);
    expect(find.text('0 of 2 right'), findsOneWidget); // geometry
    expect(
      find.text('0 of 1 right'),
      findsNothing,
      reason: 'algebra was perfect',
    );
  });

  testWidgets('"Missed" shows only wrong and unanswered questions', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Missed 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 ·'), findsNothing);
    expect(find.textContaining('Question 2 ·'), findsOneWidget);
    expect(find.textContaining('Question 3 ·'), findsOneWidget);
  });
}
