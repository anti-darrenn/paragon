import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/progress/mistakes.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/mistakes_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/mistakes/mistakes_practice_screen.dart';

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

Future<void> _attempt(
  FakeFirebaseFirestore db,
  String q,
  bool correct,
  int minute, {
  String user = 'u1',
}) => db.collection('attempts').add({
  'userId': user,
  'questionId': q,
  'topicId': 't1',
  'subjectId': 's1',
  'selectedIndex': correct ? 0 : 1,
  'isCorrect': correct,
  'source': 'drill',
  'timestamp': Timestamp.fromDate(DateTime(2026, 9, 27, 10, minute)),
});

Future<void> _question(
  FakeFirebaseFirestore db,
  String id, {
  bool hasAnswer = true,
}) => db.collection('questions').doc(id).set({
  'topicId': 't1',
  'subjectId': 's1',
  'text': 'Question $id',
  'options': ['right$id', 'wrong$id', 'x', 'y'],
  'correctIndex': 0,
  'explanation': 'Because right$id.',
  'source': 'drill',
  'hasAnswer': hasAnswer,
});

void main() {
  group('mistakesProvider', () {
    late FakeFirebaseFirestore db;

    Future<List<String>> notebook() async {
      final c = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(FakeUser('u1')),
          mistakesRepositoryProvider.overrideWithValue(MistakesRepository(db)),
        ],
      );
      addTearDown(c.dispose);
      final entries = await c.read(mistakesProvider.future);
      return [for (final e in entries) e.question.id];
    }

    setUp(() async {
      db = FakeFirebaseFirestore();
      for (final id in ['q1', 'q2', 'q3', 'q4']) {
        await _question(db, id);
      }
    });

    test(
      'lists questions whose latest answer was wrong, newest first',
      () async {
        await _attempt(db, 'q1', false, 1);
        await _attempt(db, 'q2', false, 2);
        await _attempt(db, 'q3', true, 3);
        expect(await notebook(), ['q2', 'q1']);
      },
    );

    test(
      'a later right answer clears one; CONTROL: a later wrong keeps it',
      () async {
        await _attempt(db, 'q1', false, 1);
        await _attempt(db, 'q1', true, 2); // cleared
        await _attempt(db, 'q2', true, 3);
        await _attempt(db, 'q2', false, 4); // reopened
        expect(await notebook(), ['q2']);
      },
    );

    test('a retired or deleted question is left out', () async {
      await _question(db, 'q3', hasAnswer: false);
      await _attempt(db, 'q3', false, 1);
      await _attempt(db, 'gone', false, 2);
      await _attempt(db, 'q4', false, 3);
      expect(await notebook(), ['q4']);
    });

    test("another student's mistakes are not listed", () async {
      await _attempt(db, 'q1', false, 1, user: 'someone-else');
      expect(await notebook(), isEmpty);
    });
  });

  group('MistakeEntry.subjectId', () {
    MistakeEntry entry({required String attemptSubject, String? questionSubject}) =>
        MistakeEntry(
          Mistake(
            AttemptRecord(
              questionId: 'q1',
              topicId: 't1',
              subjectId: attemptSubject,
              selectedIndex: 1,
              isCorrect: false,
              source: 'drill',
            ),
          ),
          Question(
            id: 'q1',
            topicId: 't1',
            subjectId: questionSubject ?? '',
            text: 'Q',
            options: const ['a', 'b'],
            correctIndex: 0,
            explanation: '',
            source: 'drill',
          ),
        );

    test("files a mistake under the question's subject, not a stale one", () {
      expect(
        entry(attemptSubject: 'deleted-subject', questionSubject: 'maths')
            .subjectId,
        'maths',
      );
    });

    test('CONTROL: falls back to the attempt when the question has none', () {
      expect(entry(attemptSubject: 'maths').subjectId, 'maths');
    });
  });

  group('practice', () {
    late FakeFirebaseFirestore db;

    Question question(String id) => Question(
      id: id,
      topicId: 't1',
      subjectId: 's1',
      text: 'Question $id',
      options: ['right$id', 'wrong$id', 'x$id', 'y$id'],
      correctIndex: 0,
      explanation: 'Because right$id.',
      source: 'waec',
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(FakeUser('u1')),
            attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
            progressRepositoryProvider.overrideWithValue(
              ProgressRepository(db),
            ),
            mistakesRepositoryProvider.overrideWithValue(
              MistakesRepository(db),
            ),
          ],
          child: MaterialApp(
            home: MistakesPracticeScreen(
              questions: [question('q1'), question('q2')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// q1 right this time, q2 wrong again.
    Future<void> play(WidgetTester tester) async {
      await tester.tap(find.text('rightq1'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Right this time.'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.tap(find.text('wrongq2'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Not yet.'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
    }

    setUp(() => db = FakeFirebaseFirestore());

    testWidgets('answers are recorded once, as review', (tester) async {
      await pump(tester);
      await play(tester);

      expect(find.text('1 of 2 right'), findsOneWidget);
      final attempts = await db.collection('attempts').get();
      expect(attempts.docs, hasLength(2));
      expect(attempts.docs.every((d) => d['source'] == 'review'), isTrue);
      final byQ = {for (final d in attempts.docs) d['questionId']: d.data()};
      expect(byQ['q1']!['isCorrect'], isTrue);
      expect(byQ['q2']!['isCorrect'], isFalse);
    });

    testWidgets('practice never touches the mastery counters', (tester) async {
      await pump(tester);
      await play(tester);
      expect((await db.collection('progress').get()).docs, isEmpty);
    });

    test('CONTROL: the check above would see a mastery write', () async {
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

    testWidgets('opened without questions, it points back to the notebook', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: MistakesPracticeScreen(questions: null)),
        ),
      );
      expect(find.text('Go to the notebook'), findsOneWidget);
    });
  });
}
