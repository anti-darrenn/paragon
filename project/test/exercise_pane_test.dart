import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/analytics_provider.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/lesson/exercise_pane.dart';

// ignore: subtype_of_sealed_class
class FakeUser implements User {
  FakeUser(this.uid, {this.isAnonymous = false});

  @override
  final String uid;
  @override
  final bool isAnonymous;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The in-lesson exercise, end to end, with a fake database so what it
/// writes — and what it must never write — can be read back.
///
/// The load-bearing assertion is that nothing reaches `progress`: mastery
/// at proficient opens drill on its own, so an exercise feeding it would
/// be a way around the topic test.
void main() {
  Question question(String id, String a, String b) => Question(
    id: id,
    topicId: 't1',
    subjectId: 's1',
    text: 'Question $id',
    options: [a, b, 'x$id', 'y$id'],
    correctIndex: 0,
    explanation: 'Because $a.',
    source: 'drill',
  );

  final questions = [question('q1', 'right1', 'wrong1'), question('q2', 'right2', 'wrong2')];

  const exercise = LearnResource(
    id: 'ex1',
    type: LearnResourceType.exercise,
    order: 1,
    title: 'Practise it',
    subjectId: 's1',
    topicId: 't1',
    questionCount: 2,
  );

  late FakeFirebaseFirestore db;
  late int finished;

  setUp(() {
    db = FakeFirebaseFirestore();
    finished = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    required User? user,
    LearnResource resource = exercise,
    List<Question>? bank,
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseQuestionsProvider.overrideWith(
            (ref, query) async => bank ?? questions,
          ),
          currentUserProvider.overrideWithValue(user),
          attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
          progressRepositoryProvider.overrideWithValue(ProgressRepository(db)),
          analyticsProvider.overrideWithValue(
            Analytics(
              instance: () => throw StateError('no analytics in tests'),
              isEnabled: () => false,
            ),
          ),
          ...extra,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExercisePane(
                resource: resource,
                onFinished: () => finished++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// q1 right first time; q2 wrong, then wrong again (revealed).
  Future<void> playSet(WidgetTester tester) async {
    await tester.tap(find.text('right1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Because right1.'), findsOneWidget);
    await tester.tap(find.text('Next question'));
    await tester.pump();

    await tester.tap(find.text('wrong2'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Not quite — try again.'), findsOneWidget);
    await tester.tap(find.text('xq2'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('The right answer is A.'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-in set records first tries once, as exercise', (
    tester,
  ) async {
    await pump(tester, user: FakeUser('u1'));
    await playSet(tester);

    expect(find.text('1 of 2 right first time'), findsOneWidget);
    expect(finished, 1);

    final attempts = await db.collection('attempts').get();
    expect(attempts.docs, hasLength(2));
    final byQuestion = {
      for (final d in attempts.docs) d['questionId'] as String: d.data(),
    };
    expect(byQuestion['q1']!['isCorrect'], isTrue);
    expect(byQuestion['q2']!['isCorrect'], isFalse);
    expect(byQuestion['q2']!['selectedIndex'], 1, reason: 'the first try, not the retry');
    expect(attempts.docs.every((d) => d['source'] == 'exercise'), isTrue);
    expect(attempts.docs.every((d) => d['userId'] == 'u1'), isTrue);
  });

  testWidgets('an exercise never touches the mastery counters', (tester) async {
    await pump(tester, user: FakeUser('u1'));
    await playSet(tester);
    expect((await db.collection('progress').get()).docs, isEmpty);
  });

  test('control: the check above would see a mastery write', () async {
    final control = FakeFirebaseFirestore();
    await ProgressRepository(control).addSession(
      uid: 'u1',
      topicId: 't1',
      subjectId: 's1',
      answered: 2,
      correct: 1,
    );
    expect((await control.collection('progress').get()).docs, isNotEmpty);
  });

  testWidgets('a guest set records nothing', (tester) async {
    await pump(tester, user: FakeUser('g1', isAnonymous: true));
    await playSet(tester);

    expect(find.textContaining('guest answers are not saved'), findsOneWidget);
    expect(finished, 1, reason: 'a guest still completes the item for the visit');
    expect((await db.collection('attempts').get()).docs, isEmpty);
  });

  testWidgets('an abandoned set records nothing', (tester) async {
    await pump(tester, user: FakeUser('u1'));
    await tester.tap(find.text('right1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect((await db.collection('attempts').get()).docs, isEmpty);
    expect(finished, 0);
  });

  testWidgets('a checked answer fits a phone screen', (tester) async {
    // Seen on an Android emulator: the report link and the Next button
    // shared a row and overflowed a 411-wide screen by 35px.
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, user: null);
    await tester.tap(find.text('right1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Next question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keys pick an option and Enter checks it', (tester) async {
    await pump(tester, user: null);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Correct!'), findsOneWidget);
  });

  testWidgets('pinned questions are served instead of the rotation', (
    tester,
  ) async {
    await pump(
      tester,
      user: null,
      resource: const LearnResource(
        id: 'ex2',
        type: LearnResourceType.exercise,
        order: 1,
        title: 'Pinned',
        subjectId: 's1',
        topicId: 't1',
        questionIds: ['p1'],
      ),
      extra: [
        pinnedQuestionsProvider.overrideWith(
          (ref, ids) async => [question('p1', 'pinnedRight', 'pinnedWrong')],
        ),
      ],
    );
    expect(find.text('pinnedRight'), findsOneWidget);
    expect(find.text('right1'), findsNothing);
  });

  testWidgets('an empty bank says so instead of showing nothing', (tester) async {
    await pump(tester, user: null, bank: const []);
    expect(find.textContaining('No practice questions'), findsOneWidget);
  });
}
