import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/lessons/subject_index.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/core/repositories/subject_index_repository.dart';
import 'package:paragon/features/course_index_screen.dart';
import 'package:paragon/features/study/cards/card_providers.dart';
import 'package:paragon/features/study/cards/card_review_screen.dart';
import 'package:paragon/features/study/cards/card_store.dart';
import 'package:paragon/features/study/cards/leitner.dart';
import 'package:paragon/features/study/notes/study_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Wraps a real store and counts what reaches it.
class CountingStore implements CardStore {
  CountingStore(this.inner);
  final CardStore inner;
  final saves = <Map<String, CardState>>[];

  @override
  Future<Map<String, CardState>> load() => inner.load();

  @override
  Future<void> save(Map<String, CardState> changed) {
    saves.add(Map.of(changed));
    return inner.save(changed);
  }
}

final _now = DateTime(2026, 9, 23, 10);
final _leitner = Leitner(clock: () => _now);

IndexedCard _card(
  String id,
  String front,
  String back, {
  String topic = 't1',
}) => IndexedCard(
  id: id,
  front: front,
  back: back,
  kind: 'card',
  topicId: topic,
  topicName: topic == 't1' ? 'Number bases' : 'Indices',
  resourceId: 'intro',
);

final _index = SubjectIndex(
  subjectId: 's1',
  topics: {
    't1': TopicIndex(
      topicId: 't1',
      topicName: 'Number bases',
      cards: [
        _card('t1:intro:card:aaa:0', 'What is base ten?', 'Ten digits.'),
        _card('t1:intro:card:bbb:0', 'What is binary?', 'Base two.'),
      ],
    ),
  },
);

void main() {
  group('FirestoreCardStore', () {
    test('a save is one merge that keeps bookmarks and other cards', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('study').doc('u1').set({
        'userId': 'u1',
        'bookmarks': {
          'lesson:t1:intro': {'kind': 'lesson'},
        },
        'cards': {
          'old:r:x': {
            'box': 3,
            'due': Timestamp.fromDate(DateTime(2026, 10, 1)),
          },
        },
      });
      final store = FirestoreCardStore(db, 'u1');
      await store.save({
        't1:intro:card:aaa:0': CardState(box: 2, due: DateTime(2026, 9, 25)),
      });

      final data = (await db.collection('study').doc('u1').get()).data()!;
      expect(data['bookmarks'], {
        'lesson:t1:intro': {'kind': 'lesson'},
      });
      expect(data['updatedAt'], isNotNull);
      final cards = data['cards'] as Map;
      expect(cards.keys, unorderedEquals(['old:r:x', 't1:intro:card:aaa:0']));

      final loaded = await store.load();
      expect(
        loaded['t1:intro:card:aaa:0'],
        CardState(box: 2, due: DateTime(2026, 9, 25)),
      );
      expect(loaded['old:r:x']!.box, 3);
    });

    test('malformed entries read as new cards rather than failing', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('study').doc('u1').set({
        'cards': {
          'a': 'junk',
          'b': {'box': 'x'},
          'c': {'box': 2, 'due': 5},
        },
      });
      final loaded = await FirestoreCardStore(db, 'u1').load();
      expect(loaded.keys, ['c']);
    });
  });

  group('review screen', () {
    late FakeFirebaseFirestore db;

    Future<void> pump(
      WidgetTester tester, {
      required User user,
      CardStore? store,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(user),
            isGuestProvider.overrideWithValue(user.isAnonymous),
            studyDbProvider.overrideWithValue(db),
            subjectIndexProvider.overrideWith((ref, id) async => _index),
            leitnerProvider.overrideWithValue(_leitner),
            if (store != null) cardStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CardReviewScreen(subjectId: 's1'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      db = FakeFirebaseFirestore();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows the back after a tap, advances, and writes once at '
        'the end, keeping bookmarks', (tester) async {
      await db.collection('study').doc('u1').set({
        'userId': 'u1',
        'bookmarks': {
          'lesson:t1:intro': {'kind': 'lesson'},
        },
      });
      final store = CountingStore(FirestoreCardStore(db, 'u1'));
      await pump(tester, user: FakeUser('u1'), store: store);

      expect(_summaryLine(tester), '2 cards · 2 due');
      await tester.tap(find.byKey(const ValueKey('cards.reviewDue')));
      await tester.pumpAndSettle();

      expect(find.text('What is base ten?'), findsOneWidget);
      expect(find.text('Ten digits.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cards.face')));
      await tester.pumpAndSettle();
      expect(find.text('Ten digits.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cards.knew')));
      await tester.pumpAndSettle();
      expect(find.text('What is binary?'), findsOneWidget);
      expect(find.text('Base two.'), findsNothing);
      expect(find.textContaining('2 of 2'), findsOneWidget);
      // Nothing is written per card.
      expect(store.saves, isEmpty);

      await tester.tap(find.byKey(const ValueKey('cards.reveal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.missed')));
      await tester.pumpAndSettle();

      expect(find.textContaining('You knew 1 of 2'), findsOneWidget);
      expect(store.saves, hasLength(1));
      expect(store.saves.single, {
        't1:intro:card:aaa:0': CardState(box: 2, due: DateTime(2026, 9, 25)),
        't1:intro:card:bbb:0': CardState(box: 1, due: DateTime(2026, 9, 24)),
      });

      final data = (await db.collection('study').doc('u1').get()).data()!;
      // Control: the merge kept what was already there.
      expect(data['bookmarks'], {
        'lesson:t1:intro': {'kind': 'lesson'},
      });
      expect((data['cards'] as Map).keys, hasLength(2));

      // Back to the chooser: both cards are now scheduled, none due.
      await tester.tap(find.byKey(const ValueKey('cards.again')));
      await tester.pumpAndSettle();
      expect(_summaryLine(tester), '2 cards · 0 due');

      // Leaving after the session wrote nothing more.
      Navigator.of(tester.element(find.byType(CardReviewScreen))).pop();
      await tester.pumpAndSettle();
      expect(store.saves, hasLength(1));
    });

    testWidgets('leaving part-way writes that session once', (tester) async {
      final store = CountingStore(FirestoreCardStore(db, 'u1'));
      await pump(tester, user: FakeUser('u1'), store: store);
      await tester.tap(find.byKey(const ValueKey('cards.reviewDue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.face')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.knew')));
      await tester.pumpAndSettle();
      expect(store.saves, isEmpty);

      Navigator.of(tester.element(find.byType(CardReviewScreen))).pop();
      await tester.pumpAndSettle();
      expect(store.saves, hasLength(1));
      expect(store.saves.single.keys, ['t1:intro:card:aaa:0']);
    });

    testWidgets('a guest\'s schedule goes to the device, not Firestore', (
      tester,
    ) async {
      await pump(tester, user: FakeUser('g1', isAnonymous: true));
      expect(find.text(kGuestCardsPrompt), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cards.reviewDue')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('cards.reveal')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cards.knew')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('You knew 2 of 2'), findsOneWidget);

      expect((await db.collection('study').get()).docs, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('study.v1.g1.cards'),
        contains('t1:intro:card:aaa:0'),
      );
      final local = await LocalCardStore('g1').load();
      expect(local['t1:intro:card:bbb:0']!.box, 2);
      // Control: another guest on the device starts fresh.
      expect(await LocalCardStore('g2').load(), isEmpty);
    });

    testWidgets('a signed-in student\'s schedule goes to Firestore, not the '
        'device (control)', (tester) async {
      await pump(tester, user: FakeUser('u1'));
      expect(find.text(kGuestCardsPrompt), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cards.reviewDue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.reveal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.missed')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cards.finishNow')));
      await tester.pumpAndSettle();

      final data = (await db.collection('study').doc('u1').get()).data()!;
      expect((data['cards'] as Map).keys, ['t1:intro:card:aaa:0']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('study.')), isEmpty);
    });

    testWidgets('pick a topic reviews only that topic', (tester) async {
      await pump(tester, user: FakeUser('u1'));
      await tester.tap(find.byKey(const ValueKey('cards.topic.t1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 of 2 · Number bases'), findsOneWidget);
    });
  });

  group('course page', () {
    const course = Course(
      key: 's1',
      slug: 'mathematics',
      name: 'Mathematics',
      blurb: '',
      subjectId: 's1',
      status: CourseStatus.live,
      modules: [],
    );

    Future<void> pump(
      WidgetTester tester, {
      required SubjectIndex index,
      Map<String, CardState> schedule = const {},
    }) async {
      final router = GoRouter(
        initialLocation: '/subject/s1/course',
        routes: [
          GoRoute(
            path: '/subject/:id/course',
            builder: (_, s) =>
                CourseIndexScreen(subjectKey: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/cards/:subjectId',
            builder: (_, s) =>
                Scaffold(body: Text('CARDS ${s.pathParameters['subjectId']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseProvider.overrideWith((ref, key) async => course),
            userProgressProvider.overrideWith(
              (ref) => Stream.value(UserProgress.empty),
            ),
            currentUserProvider.overrideWithValue(FakeUser('u1')),
            subjectIndexProvider.overrideWith((ref, id) async => index),
            leitnerProvider.overrideWithValue(_leitner),
            cardStoreProvider.overrideWithValue(_FixedStore(schedule)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows how many cards are due and opens the review', (
      tester,
    ) async {
      await pump(
        tester,
        index: _index,
        schedule: {
          't1:intro:card:aaa:0': CardState(box: 3, due: DateTime(2026, 9, 30)),
        },
      );
      expect(find.text('Revision cards: 1 due'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('course.revisionCards')));
      await tester.pumpAndSettle();
      expect(find.text('CARDS s1'), findsOneWidget);
    });

    testWidgets('shows nothing when the subject has no cards (control)', (
      tester,
    ) async {
      await pump(tester, index: SubjectIndex.empty);
      expect(find.byKey(const ValueKey('course.revisionCards')), findsNothing);
      expect(find.textContaining('Revision cards'), findsNothing);
    });
  });
}

String? _summaryLine(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('cards.summaryLine'))).data;

class _FixedStore implements CardStore {
  _FixedStore(this.schedule);
  final Map<String, CardState> schedule;

  @override
  Future<Map<String, CardState>> load() async => schedule;

  @override
  Future<void> save(Map<String, CardState> changed) async {}
}
