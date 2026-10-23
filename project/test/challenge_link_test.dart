import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/challenge/challenge_link.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/core/widgets/question_runner.dart';
import 'package:paragon/features/challenge_link/challenge_link_screen.dart';

class _Guest implements User {
  @override
  String get uid => 'friend';
  @override
  bool get isAnonymous => true;
  @override
  String? get displayName => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Question _q(String id, int correct) => Question(
  id: id,
  topicId: 't1',
  subjectId: 's1',
  text: 'Question $id',
  options: const ['w', 'x', 'y', 'z'],
  correctIndex: correct,
  explanation: '',
  source: 'drill',
  vetted: true,
);

void main() {
  group('pure helpers', () {
    test('the challenger is a first name or "A friend", never more', () {
      expect(challengerName('Ada Obi'), 'Ada');
      expect(challengerName('  Tunde  '), 'Tunde');
      expect(challengerName(null), 'A friend');
      expect(challengerName(''), 'A friend');
      expect(challengerName('ada@example.com'), 'A friend');
      expect(challengerName('x' * 40).length, 30);
    });

    test('a challenge takes the first ten answers and their score', () {
      final answered = [
        for (var i = 0; i < 14; i++) (questionId: 'q$i', correct: i.isEven),
      ];
      final c = challengeFrom(answered);
      expect(c.ids, [for (var i = 0; i < 10; i++) 'q$i']);
      expect(c.score, 5);
    });

    test('score line', () {
      expect(
        scoreLine(mine: 8, theirs: 7, total: 10, name: 'Ada'),
        'You 8/10 · Ada 7/10. You win!',
      );
      expect(
        scoreLine(mine: 7, theirs: 7, total: 10, name: 'Ada'),
        contains('draw'),
      );
      expect(
        scoreLine(mine: 2, theirs: 7, total: 10, name: 'Ada'),
        contains('Ada wins'),
      );
    });
  });

  testWidgets('the runner gives instant feedback and reports every answer', (
    tester,
  ) async {
    List<({Question question, int selected, bool correct})>? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuestionRunner(
              questions: [_q('a', 1), _q('b', 2)],
              onFinished: (r) => got = r,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('x')); // right
    await tester.pump();
    // Choosing is not answering: nothing is marked until Check.
    expect(find.text('Correct.'), findsNothing);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Correct.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('w')); // wrong
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    // Says which one was right, not only that this one was wrong.
    expect(find.text('Not quite. The answer is C.'), findsOneWidget);
    await tester.tap(find.text('See results'));
    expect(got!.map((r) => r.correct), [true, false]);
  });

  testWidgets('a friend plays a challenge as a guest; it is recorded as '
      'challenge_link and never touches progress', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('questions').doc('q1').set(_q('q1', 0).toJson());
    await db.collection('questions').doc('q2').set(_q('q2', 0).toJson());
    await db.collection('challenges').doc('c1').set({
      'userId': 'ada',
      'name': 'Ada',
      'subjectId': 's1',
      'topicId': 't1',
      'topicName': 'Indices',
      'questionIds': ['q1', 'q2'],
      'score': 1,
      'total': 2,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          challengeRepositoryProvider.overrideWithValue(
            ChallengeRepository(db),
          ),
          attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
          currentUserProvider.overrideWithValue(_Guest()),
          isGuestProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: ChallengeLinkScreen(id: 'c1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada challenges you'), findsOneWidget);
    expect(find.textContaining('Ada scored 1/2 on Indices'), findsOneWidget);

    await tester.tap(find.text('Answer 2 questions'));
    await tester.pumpAndSettle();
    for (final _ in [1, 2]) {
      await tester.tap(find.text('w')); // option A, right
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(
        find.text('Continue').evaluate().isNotEmpty
            ? find.text('Continue')
            : find.text('See results'),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('You 2/2 · Ada 1/2. You win!'), findsOneWidget);
    expect(find.text('Learn Indices'), findsOneWidget);

    final attempts = await db.collection('attempts').get();
    expect(attempts.docs, hasLength(2));
    expect(attempts.docs.map((d) => d['source']).toSet(), {'challenge_link'});
    // Control: progress is a different collection, and nothing reached it.
    expect((await db.collection('progress').get()).docs, isEmpty);
    expect(UserProgress.empty.forTopic('t1').answered, 0);
  });
}
