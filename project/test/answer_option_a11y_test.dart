import 'dart:ui' show Tristate;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/lesson_progress.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/drill_screen.dart';
import 'package:paragon/features/topic_test_screen.dart';

/// Audit D1–D4 (2026-10-15), read from the accessibility tree: drill
/// options were four bare buttons with no name, the topic test's had no
/// letters, nothing said which was selected, and right or wrong was shown
/// by colour alone. Drill and the topic test now use `AnswerOption`.
void main() {
  const topicId = 't1';

  Question question(String id, {int correct = 1}) => Question(
    id: id,
    topicId: topicId,
    subjectId: 's1',
    text: 'What is 2 + 2?',
    options: const ['3', '4', '5', '6'],
    correctIndex: correct,
    explanation: 'Two and two make four.',
    source: 'waec',
    year: 2018,
  );

  SemanticsNode node(WidgetTester tester, String label) =>
      tester.getSemantics(find.bySemanticsLabel(label));

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('drill', () {
    Future<void> pump(WidgetTester tester) async {
      tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            drillQuestionsProvider(
              topicId,
            ).overrideWith((ref) async => [question('q0'), question('q1')]),
            currentUserProvider.overrideWithValue(null),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(FakeFirebaseFirestore()),
            ),
            drillAccessProvider(topicId).overrideWithValue(DrillAccess.allowed),
          ],
          child: const MaterialApp(home: DrillScreen(topicId: topicId)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('each option is named, lettered and selectable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      for (final (letter, text) in [('A', '3'), ('B', '4'), ('C', '5')]) {
        expect(
          node(tester, 'Option $letter: $text'),
          matchesSemantics(
            label: 'Option $letter: $text',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
        );
      }
      // The semantic tap chooses it, as a screen reader's double-tap would.
      tester.semantics.tap(find.semantics.byLabel('Option A: 3'));
      await tester.pump();
      expect(
        node(tester, 'Option A: 3').flagsCollection.isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('the verdict is said in words, announced, and names the '
        'right answer', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.text('3')); // wrong
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();
      expect(find.text('Not quite. The answer is B.'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsWidgets);
      expect(node(tester, 'Option A: 3, incorrect'), isNotNull);
      expect(node(tester, 'Option B: 4, correct'), isNotNull);
      final verdict = find.ancestor(
        of: find.text('Not quite. The answer is B.'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      );
      expect(verdict, findsOneWidget);
      handle.dispose();
    });
  });

  group('topic test', () {
    Future<void> pump(WidgetTester tester) async {
      tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topicTestQuestionsProvider(topicId).overrideWith(
              (ref) async => [question('q0'), question('q1', correct: 2)],
            ),
            topicTestProgressProvider.overrideWith(
              (ref) => Stream.value(TopicTestProgress.empty),
            ),
            topicResourcesProvider(topicId).overrideWith((ref) async => []),
            lessonProgressProvider.overrideWithValue(LessonProgress.empty),
            currentUserProvider.overrideWithValue(null),
            isGuestProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: TopicTestScreen(
              subjectId: 's1',
              unitId: 'u1',
              topicId: topicId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('options carry letters and a selected state, and no verdict', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      expect(node(tester, 'Option D: 6'), isNotNull);
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(
        node(tester, 'Option C: 5').flagsCollection.isSelected,
        Tristate.isTrue,
      );
      // Control: no right/wrong while the test is open.
      expect(find.bySemanticsLabel(RegExp(r'correct|incorrect')), findsNothing);
      handle.dispose();
    });

    testWidgets('after submitting, Review answers shows each answer marked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.text('4')); // q0 right
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3')); // q1 wrong (C is right)
      await tester.pump();
      await tester.tap(find.text('Submit test'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 correct'), findsOneWidget);

      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1 · right'), findsOneWidget);
      expect(find.text('Question 2 · wrong'), findsOneWidget);
      expect(find.bySemanticsLabel('Option A: 3, incorrect'), findsOneWidget);
      expect(find.bySemanticsLabel('Option C: 5, correct'), findsOneWidget);

      await tester.tap(find.text('Back to your result').first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 correct'), findsOneWidget);
      handle.dispose();
    });
  });
}
