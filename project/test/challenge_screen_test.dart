import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/challenge_screen.dart';

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

CourseTopic _topic(String id) => CourseTopic(
  id: id,
  name: 'Topic $id',
  questionCount: 300,
  hasNotes: false,
  isPlaceholder: false,
);

const _course = Course(
  key: 'maths',
  slug: 'mathematics',
  name: 'Mathematics',
  blurb: '',
  subjectId: 's1',
  status: CourseStatus.live,
  modules: [
    CourseModule(
      id: 'm1',
      name: 'Module one',
      isPlaceholder: false,
      topics: [],
    ),
  ],
);

Question _q(String topic, int n) => Question(
  id: '$topic$n',
  topicId: topic,
  subjectId: 's1',
  text: 'Stem $topic$n',
  options: ['right$topic$n', 'wrong$topic$n', 'x', 'y'],
  correctIndex: 0,
  explanation: '',
  source: 'drill',
);

/// A unit test end to end against a fake database, so the writes that
/// decide access — and the ones that must never happen — can be read back.
void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  // four from each of topics a and b
  final questions = [
    for (final t in ['a', 'b'])
      for (var i = 0; i < 4; i++) _q(t, i),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String? moduleId = 'm1',
    Map<String, dynamic> learnDoc = const {},
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final course = Course(
      key: _course.key,
      slug: _course.slug,
      name: _course.name,
      blurb: '',
      subjectId: 's1',
      status: CourseStatus.live,
      modules: [
        CourseModule(
          id: 'm1',
          name: 'Module one',
          isPlaceholder: false,
          topics: [_topic('a'), _topic('b')],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(FakeUser('u1')),
          courseProvider.overrideWith((ref, key) async => course),
          challengeQuestionsProvider.overrideWith(
            (ref, key) async => questions,
          ),
          userProgressProvider.overrideWith(
            (ref) => Stream.value(UserProgress.fromDocument(const {})),
          ),
          topicTestProgressProvider.overrideWith(
            (ref) => Stream.value(TopicTestProgress.fromDocument(learnDoc)),
          ),
          attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
          learnProgressRepositoryProvider.overrideWithValue(
            LearnProgressRepository(db),
          ),
          progressRepositoryProvider.overrideWithValue(ProgressRepository(db)),
        ],
        child: MaterialApp(
          home: ChallengeScreen(subjectKey: 'maths', moduleId: moduleId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// All of topic a right; topic b two right, two wrong.
  Future<void> sit(WidgetTester tester) async {
    for (final q in questions) {
      final right = q.topicId == 'a' || q.id == 'b0' || q.id == 'b1';
      await tester.tap(find.text(right ? 'right${q.id}' : 'wrong${q.id}'));
      await tester.pump();
      await tester.tap(find.text(q == questions.last ? 'Finish' : 'Next'));
      await tester.pumpAndSettle();
    }
  }

  Future<Map<String, dynamic>> topics(String collection) async {
    final doc = await db.collection(collection).doc('u1').get();
    return Map<String, dynamic>.from(doc.data()?['topics'] as Map? ?? {});
  }

  testWidgets('a unit test opens a topic passed at 4 of 4, not one at 2 of 4', (
    tester,
  ) async {
    await pump(tester);
    await sit(tester);

    expect(find.text('6 / 8'), findsOneWidget);
    expect(find.text('You unlocked practice for 1 topic.'), findsOneWidget);

    final learn = await topics('learn');
    expect(learn['a']['passed'], isTrue);
    expect(learn['a']['passedVia'], 'unit_test');
    expect(
      learn['a'].containsKey('attempts'),
      isFalse,
      reason: "the topic's own test was not sat",
    );
    expect(learn.containsKey('b'), isFalse);

    final attempts = await db.collection('attempts').get();
    expect(attempts.docs, hasLength(8));
    expect(attempts.docs.every((d) => d['source'] == 'challenge'), isTrue);
  });

  testWidgets('mastery is fed for the topic it opened, never the locked one', (
    tester,
  ) async {
    await pump(tester);
    await sit(tester);
    final progress = await topics('progress');
    expect(progress['a']['answered'], 4);
    expect(progress['a']['correct'], 4);
    expect(
      progress.containsKey('b'),
      isFalse,
      reason: 'b is still locked; counting it would be a way round the gate',
    );
  });

  testWidgets('CONTROL: a topic already open gets its answers counted', (
    tester,
  ) async {
    await pump(
      tester,
      learnDoc: {
        'topics': {
          'b': {'passed': true, 'bestScore': 90, 'attempts': 1},
        },
      },
    );
    await sit(tester);
    final progress = await topics('progress');
    expect(progress['b']['answered'], 4);
    expect(progress['b']['correct'], 2);
  });

  testWidgets('the course challenge unlocks nothing, even when perfect', (
    tester,
  ) async {
    await pump(tester, moduleId: null);
    for (final q in questions) {
      await tester.tap(find.text('right${q.id}'));
      await tester.pump();
      await tester.tap(find.text(q == questions.last ? 'Finish' : 'Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('8 / 8'), findsOneWidget);
    expect(find.textContaining('You unlocked'), findsNothing);
    expect(await topics('learn'), isEmpty);
    expect(await topics('progress'), isEmpty);
  });
}
