import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/analytics_provider.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/drill_screen.dart';

// ignore: subtype_of_sealed_class
class FakeUser implements User {
  FakeUser(this.uid);

  @override
  final String uid;
  @override
  bool get isAnonymous => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hints in drill: offered from the explanation, never its last step, and
/// a right answer after one is recorded truthfully but not counted toward
/// mastery — otherwise hints would be a way to farm levels, and mastery
/// at proficient opens drill on its own.
void main() {
  const topicId = 't1';

  Question question(String id) => Question(
    id: id,
    topicId: topicId,
    subjectId: 's1',
    text: 'What is 2 + 2?',
    options: const ['3', '4', '5', '6'],
    correctIndex: 1,
    explanation: 'Start from 2.\n\nAdd 2 more.\n\nSo it is 4.',
    source: 'drill',
  );

  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  Future<void> pumpDrill(WidgetTester tester) async {
    // tall enough that hints, explanation and buttons all fit: a tap on
    // an off-screen button silently misses
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drillQuestionsProvider(
            topicId,
          ).overrideWith((ref) async => [question('q0'), question('q1')]),
          userProgressProvider.overrideWith(
            (ref) => Stream.value(UserProgress.fromDocument(const {})),
          ),
          currentUserProvider.overrideWithValue(FakeUser('u1')),
          attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
          progressRepositoryProvider.overrideWithValue(ProgressRepository(db)),
          analyticsProvider.overrideWithValue(
            Analytics(
              instance: () => throw StateError('no analytics in tests'),
              isEnabled: () => false,
            ),
          ),
          drillAccessProvider(topicId).overrideWithValue(DrillAccess.allowed),
        ],
        child: const MaterialApp(home: DrillScreen(topicId: topicId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool last}) async {
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(last ? 'See results' : 'Next Question'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> topicCounters() async {
    final doc = await db.collection('progress').doc('u1').get();
    return (doc.data()!['topics'] as Map)[topicId] as Map<String, dynamic>;
  }

  testWidgets('hints reveal every step but the last, one at a time', (
    tester,
  ) async {
    await pumpDrill(tester);
    expect(find.text('Get a hint'), findsOneWidget);

    await tester.tap(find.text('Get a hint'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Start from 2.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Next hint (2 of 2)'), findsOneWidget);

    await tester.tap(find.text('Next hint (2 of 2)'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Add 2 more.', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Next hint'), findsNothing);
    expect(
      find.textContaining('So it is 4.', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('a right answer after a hint is recorded but not mastered', (
    tester,
  ) async {
    await pumpDrill(tester);
    await tester.tap(find.text('Get a hint'));
    await tester.pumpAndSettle();
    await answer(tester, last: false); // q0: right, with a hint
    await answer(tester, last: true); // q1: right, alone

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100% correct · 1 with hints'), findsOneWidget);

    final attempts = {
      for (final d in (await db.collection('attempts').get()).docs)
        d['questionId']: d.data(),
    };
    expect(attempts['q0']!['isCorrect'], isTrue, reason: 'recorded truthfully');
    expect(attempts['q0']!['hintsUsed'], 1);
    expect(attempts['q1']!.containsKey('hintsUsed'), isFalse);

    final counters = await topicCounters();
    expect(counters['answered'], 2);
    expect(counters['correct'], 1, reason: 'the hinted answer is not counted');
  });

  testWidgets('CONTROL: without hints both right answers count', (
    tester,
  ) async {
    await pumpDrill(tester);
    await answer(tester, last: false);
    await answer(tester, last: true);

    expect(find.text('100% correct'), findsOneWidget);
    final counters = await topicCounters();
    expect(counters['correct'], 2);
  });
}
