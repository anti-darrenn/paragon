import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/progress/mastery.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/drill_screen.dart';

/// The drill session summary, and the one calculation in it that is easy
/// to get quietly wrong.
///
/// `_flushSession` writes to the same document `userProgressProvider`
/// watches, so reading the level back after the write races the stream —
/// and when the read wins, the session is counted twice and the student is
/// told they reached a level they did not. The screen therefore computes
/// the new level from where the topic stood *before* the session plus what
/// was just answered. These tests pin that.
void main() {
  const topicId = 't1';

  Question question(String id) => Question(
    id: id,
    topicId: topicId,
    subjectId: 's1',
    text: 'What is 2 + 2?',
    options: const ['3', '4', '5', '6'],
    correctIndex: 1,
    explanation: '',
    source: 'drill',
  );

  Future<void> pumpDrill(
    WidgetTester tester, {
    required int questionCount,
    required TopicProgress starting,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drillQuestionsProvider(topicId).overrideWith(
            (ref) async => [
              for (var i = 0; i < questionCount; i++) question('q$i'),
            ],
          ),
          userProgressProvider.overrideWith(
            (ref) => Stream.value(
              UserProgress.fromDocument({
                'topics': {
                  topicId: {
                    'answered': starting.answered,
                    'correct': starting.correct,
                    'subjectId': 's1',
                  },
                },
              }),
            ),
          ),
          // Signed out: no attempt or progress writes happen at all. The
          // session tally and the summary are independent of them, which
          // is what makes this testable without Firebase.
          currentUserProvider.overrideWithValue(null),
          // Held unconditionally by the screen (Riverpod 3 bans `ref` in
          // dispose, so it has to be captured up front), and the real one
          // reaches for FirebaseFirestore.instance.
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(FakeFirebaseFirestore()),
          ),
          // Past the topic-test gate, so these tests stay about the
          // summary. Signed out reads as `signedOut` and would render the
          // locked state instead of a single question — correct behaviour,
          // and not what this file is measuring. The group at the bottom
          // pumps WITHOUT this override, so the gate cannot quietly break
          // behind it.
          drillAccessProvider(
            topicId,
          ).overrideWithValue(DrillAccess.allowed),
        ],
        child: const MaterialApp(home: DrillScreen(topicId: topicId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Answers every question correctly and stops on the summary.
  Future<void> answerAll(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(i == count - 1 ? 'See results' : 'Next Question'),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('reports the session score instead of just popping', (
    tester,
  ) async {
    await pumpDrill(tester, questionCount: 2, starting: const TopicProgress());
    await answerAll(tester, 2);

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100% correct'), findsOneWidget);
  });

  testWidgets('a level gained is measured from before the session', (
    tester,
  ) async {
    // 19 answered at 17 correct is familiar. Two more correct takes it to
    // 21/19 — proficient. Reading the stored document back after the write
    // would give 21+2 and overstate it.
    await pumpDrill(
      tester,
      questionCount: 2,
      starting: const TopicProgress(answered: 19, correct: 17),
    );
    await answerAll(tester, 2);

    expect(find.text('Now proficient'), findsOneWidget);
    expect(find.text('Up from familiar in this topic.'), findsOneWidget);
  });

  testWidgets('a short session earns only the first rung', (tester) async {
    await pumpDrill(tester, questionCount: 2, starting: const TopicProgress());
    await answerAll(tester, 2);

    // Two right answers only reaches "attempted" — the first rung, not a
    // level the student should read as progress toward proficiency.
    expect(find.text('Now attempted'), findsOneWidget);
  });

  testWidgets('practise again starts a clean session', (tester) async {
    await pumpDrill(tester, questionCount: 2, starting: const TopicProgress());
    await answerAll(tester, 2);

    await tester.tap(find.text('Practise again'));
    await tester.pumpAndSettle();

    // Back to the first question, with the tally reset — otherwise the
    // second session's summary would report both sessions.
    expect(find.text('Session complete'), findsNothing);
    expect(find.text('Question 1 of 2'), findsOneWidget);

    await answerAll(tester, 2);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  group('the topic-test gate', () {
    /// Same screen, same overrides, minus the access override — so what
    /// this asserts is the real provider's verdict, not a stub's.
    Future<void> pumpGated(
      WidgetTester tester, {
      required DrillAccess access,
      bool hasLesson = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            drillQuestionsProvider(
              topicId,
            ).overrideWith((ref) async => [question('q0')]),
            currentUserProvider.overrideWithValue(null),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(FakeFirebaseFirestore()),
            ),
            drillAccessProvider(topicId).overrideWithValue(access),
            topicResourcesProvider(topicId).overrideWith(
              (ref) async => hasLesson
                  ? [
                      const LearnResource(
                        id: 'a1',
                        type: LearnResourceType.article,
                        order: 10,
                        title: 'Intro',
                        subjectId: 's1',
                        topicId: topicId,
                        body: 'Some prose.',
                      ),
                    ]
                  : const <LearnResource>[],
            ),
          ],
          child: const MaterialApp(
            home: DrillScreen(
              topicId: topicId,
              subjectId: 's1',
              unitId: 'u1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a locked topic shows the test prompt, not a question', (
      tester,
    ) async {
      await pumpGated(tester, access: DrillAccess.testRequired);

      expect(find.text('Pass the topic test first'), findsOneWidget);
      expect(find.text('Take the topic test'), findsOneWidget);
      // The thing that matters: no question leaks through the gate.
      expect(find.text('What is 2 + 2?'), findsNothing);
      expect(find.text('Submit Answer'), findsNothing);
    });

    testWidgets('a guest is told to get an account, not to take a test', (
      tester,
    ) async {
      // Taking a test would be a dead end for a guest — the result dies
      // with the session — so the guest branch must not offer it.
      await pumpGated(tester, access: DrillAccess.guestBlocked);

      expect(find.text('Drill needs an account'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Take the topic test'), findsNothing);
      expect(find.text('What is 2 + 2?'), findsNothing);
    });

    testWidgets('a topic with no lesson does not claim one exists', (
      tester,
    ) async {
      // The screen used to tell every locked student that "the lesson
      // above covers everything it asks". One topic of 216 has a lesson,
      // and there is nothing above this screen — so for almost everyone
      // that sentence was false, and two students were sent to study
      // material that does not exist. The gate may ask for 80%; it may not
      // invent the teaching it is testing.
      await pumpGated(tester, access: DrillAccess.testRequired);

      expect(find.textContaining('lesson'), findsNothing);
      // It still has to say something useful about where the test comes
      // from, or the refusal is just a wall.
      expect(find.textContaining('past-paper'), findsOneWidget);
    });

    testWidgets('a topic that does have a lesson may point at it', (
      tester,
    ) async {
      // The control for the test above: proves it is detecting the absent
      // lesson rather than copy that never mentions one.
      await pumpGated(
        tester,
        access: DrillAccess.testRequired,
        hasLesson: true,
      );

      expect(find.textContaining('lesson for this topic'), findsOneWidget);
    });

    testWidgets('an allowed topic renders the question as before', (
      tester,
    ) async {
      // The control for this group: proves the two assertions above are
      // detecting the gate rather than a screen that renders nothing.
      await pumpGated(tester, access: DrillAccess.allowed);

      expect(find.text('What is 2 + 2?'), findsOneWidget);
      expect(find.text('Pass the topic test first'), findsNothing);
    });
  });
}
