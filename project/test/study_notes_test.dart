import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/widgets/article_view.dart';
import 'package:paragon/features/study/notes/notes_hooks.dart';
import 'package:paragon/features/study/notes/notes_widgets.dart';
import 'package:paragon/features/study/notes/study_models.dart';
import 'package:paragon/features/study/notes/study_providers.dart';
import 'package:paragon/features/study/notes/study_store.dart';
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

const _body = 'First paragraph.\n\nSecond paragraph.';

const _resource = LearnResource(
  id: 'intro',
  type: LearnResourceType.article,
  order: 1,
  title: 'Introduction',
  subjectId: 's1',
  topicId: 't1',
  body: _body,
);

LessonNote _note({
  String id = '',
  String topicId = 't1',
  String resourceId = 'intro',
  required String blockKey,
  HighlightColour? colour,
  String text = '',
  String snapshot = 'snap',
}) => LessonNote(
  id: id,
  topicId: topicId,
  resourceId: resourceId,
  subjectId: 's1',
  blockKey: blockKey,
  colour: colour,
  text: text,
  snapshot: snapshot,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final doc = parseLessonDoc(_body);
  final firstKey = doc.blocks[0].key;
  final secondKey = doc.blocks[1].key;

  // ─── Repository ────────────────────────────────────────────────────

  group('FirestoreStudyStore notes', () {
    late FakeFirebaseFirestore db;
    late FirestoreStudyStore store;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreStudyStore(db, 'u1');
    });

    test('creates, updates and deletes a note', () async {
      final created = await store.createNote(
        _note(blockKey: firstKey, colour: HighlightColour.yellow),
      );
      expect(created.id, isNotEmpty);

      var stored = (await db.collection('notes').doc(created.id).get()).data()!;
      expect(stored['userId'], 'u1');
      expect(stored['blockKey'], firstKey);
      expect(stored['colour'], 'yellow');
      expect(stored['text'], '');
      expect(stored['snapshot'], 'snap');
      expect(stored.keys, containsAll(['createdAt', 'updatedAt']));

      await store.updateNote(
        created.copyWith(text: 'Remember this', clearColour: true),
      );
      stored = (await db.collection('notes').doc(created.id).get()).data()!;
      expect(stored['text'], 'Remember this');
      expect(stored['colour'], isNull);
      expect(stored['userId'], 'u1', reason: 'update must not touch owner');

      await store.deleteNote(created.id);
      expect((await db.collection('notes').doc(created.id).get()).exists, isFalse);
    });

    test('the per-lesson query returns only this user\'s notes on this lesson',
        () async {
      final mine = await store.createNote(_note(blockKey: firstKey, text: 'mine'));
      // Control: another student's note on the very same lesson.
      await FirestoreStudyStore(db, 'u2').createNote(
        _note(blockKey: firstKey, text: 'theirs'),
      );
      // Same slug in a different topic — resource ids are only unique
      // within a topic.
      await store.createNote(
        _note(topicId: 't9', blockKey: firstKey, text: 'other topic'),
      );
      // A different lesson.
      await store.createNote(
        _note(resourceId: 'other', blockKey: firstKey, text: 'other lesson'),
      );

      final notes = await store.lessonNotes('t1', 'intro');
      expect(notes.map((n) => n.id), [mine.id]);

      // The control really is there: the query, not an empty database,
      // is what excluded it.
      final all = await db.collection('notes').get();
      expect(all.docs.where((d) => d.data()['userId'] == 'u2'), hasLength(1));
    });
  });

  group('FirestoreStudyStore bookmarks', () {
    late FakeFirebaseFirestore db;
    late FirestoreStudyStore store;

    const lesson = Bookmark(
      kind: BookmarkKind.lesson,
      topicId: 't1',
      resourceId: 'intro',
      subjectId: 's1',
      title: 'Introduction',
    );

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreStudyStore(db, 'u1');
    });

    test('adding twice keeps one bookmark; removing twice is harmless', () async {
      await store.addBookmark(lesson);
      await store.addBookmark(lesson);
      var saved = await store.bookmarks();
      expect(saved.keys, [lesson.key]);
      expect(saved[lesson.key]!.title, 'Introduction');

      await store.removeBookmark(lesson.key);
      await store.removeBookmark(lesson.key);
      saved = await store.bookmarks();
      expect(saved, isEmpty);
    });

    test('writing a bookmark keeps unrelated fields on study/{uid}', () async {
      // Another feature (revision cards) will share this document.
      await db.collection('study').doc('u1').set({
        'userId': 'u1',
        'cards': {'c1': {'due': 3}},
      });

      await store.addBookmark(lesson);
      var data = (await db.collection('study').doc('u1').get()).data()!;
      expect(data['cards'], {'c1': {'due': 3}});
      expect((data['bookmarks'] as Map).keys, [lesson.key]);
      expect(data['updatedAt'], isNotNull);

      await store.removeBookmark(lesson.key);
      data = (await db.collection('study').doc('u1').get()).data()!;
      expect(data['cards'], {'c1': {'due': 3}});
      expect(data['bookmarks'], isEmpty);
    });

    test('the notifier toggle is idempotent in pairs', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(FakeUser('u1')),
          studyDbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarksProvider.future);
      final notifier = container.read(bookmarksProvider.notifier);

      expect(await notifier.toggle(lesson), isTrue);
      expect(await notifier.toggle(lesson), isFalse);
      expect(await notifier.toggle(lesson), isTrue);
      expect((await store.bookmarks()).keys, [lesson.key]);
    });
  });

  // ─── Detached notes ────────────────────────────────────────────────

  group('partitionNotes', () {
    test('a note on a block that is gone is detached; one on a block that '
        'exists is not', () {
      final attached = _note(id: 'a', blockKey: secondKey);
      final detached = _note(id: 'd', blockKey: 'paragraph:deadbeef:0');
      final parts = partitionNotes([attached, detached], doc);
      expect(parts.attached.map((n) => n.id), ['a']);
      expect(parts.detached.map((n) => n.id), ['d']);
    });

    test('rewording a block detaches its note', () {
      final n = _note(id: 'a', blockKey: firstKey);
      final edited = parseLessonDoc('First paragraph, reworded.\n\nSecond paragraph.');
      expect(partitionNotes([n], edited).detached, hasLength(1));
      expect(partitionNotes([n], doc).detached, isEmpty);
    });

    test('snapshots are trimmed and capped', () {
      final long = parseLessonDoc('  ${'x' * 1500}  ').blocks.single;
      expect(blockSnapshot(long).length, kMaxSnapshotLength);
      expect(blockSnapshot(doc.blocks[0]), 'First paragraph.');
    });
  });

  // ─── Widgets ───────────────────────────────────────────────────────

  Future<void> pumpArticle(
    WidgetTester tester, {
    required User user,
    required FakeFirebaseFirestore db,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          isGuestProvider.overrideWithValue(user.isAnonymous),
          studyDbProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) => Column(
                  children: [
                    const NotesHeaderActions(resource: _resource),
                    ArticleView(
                      body: _body,
                      decorate: notesDecorator(ref, _resource),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationOf(WidgetTester tester, String key) =>
      tester.widget<DecoratedBox>(find.byKey(ValueKey('note-block-$key'))).decoration
          as BoxDecoration;

  testWidgets('the decorator highlights the highlighted block and no other',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await FirestoreStudyStore(db, 'u1').createNote(
      _note(blockKey: secondKey, colour: HighlightColour.green, text: 'why'),
    );

    await pumpArticle(tester, user: FakeUser('u1'), db: db);

    expect(decorationOf(tester, secondKey).color, HighlightColour.green.fill);
    expect(find.byKey(ValueKey('note-marker-$secondKey')), findsOneWidget);
    // Control: the other block is plain.
    expect(decorationOf(tester, firstKey).color, Colors.transparent);
    expect(find.byKey(ValueKey('note-marker-$firstKey')), findsNothing);
    expect(find.text('Notes (1)'), findsOneWidget);
  });

  testWidgets('long-press, pick a colour: one note written, block highlighted',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpArticle(tester, user: FakeUser('u1'), db: db);

    await tester.longPress(find.byKey(ValueKey('note-block-$firstKey')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swatch-blue')));
    await tester.pumpAndSettle();

    final notes = await db.collection('notes').get();
    expect(notes.docs, hasLength(1));
    expect(notes.docs.single.data()['colour'], 'blue');
    expect(notes.docs.single.data()['blockKey'], firstKey);
    expect(decorationOf(tester, firstKey).color, HighlightColour.blue.fill);
    expect(decorationOf(tester, secondKey).color, Colors.transparent);
  });

  testWidgets('the notes sheet lists attached and detached notes apart',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreStudyStore(db, 'u1');
    final attached = await store.createNote(
      _note(blockKey: firstKey, text: 'still here'),
    );
    final detached = await store.createNote(
      _note(
        blockKey: 'paragraph:deadbeef:0',
        text: 'on old wording',
        snapshot: 'The paragraph as it used to read.',
      ),
    );

    await pumpArticle(tester, user: FakeUser('u1'), db: db);
    expect(find.text('Notes (2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notes-button')));
    await tester.pumpAndSettle();

    final heading = find.byKey(const ValueKey('detached-heading'));
    final a = find.byKey(ValueKey('attached-${attached.id}'));
    final d = find.byKey(ValueKey('detached-${detached.id}'));
    expect(heading, findsOneWidget);
    expect(a, findsOneWidget);
    expect(d, findsOneWidget);
    // Control: neither note is listed in the other's section.
    expect(find.byKey(ValueKey('detached-${attached.id}')), findsNothing);
    expect(find.byKey(ValueKey('attached-${detached.id}')), findsNothing);
    expect(tester.getTopLeft(a).dy, lessThan(tester.getTopLeft(heading).dy));
    expect(tester.getTopLeft(d).dy, greaterThan(tester.getTopLeft(heading).dy));
    // The detached note shows what it was written against.
    expect(find.text('The paragraph as it used to read.'), findsOneWidget);
  });

  testWidgets('a guest\'s notes and bookmarks go to the device, not Firestore',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = FakeFirebaseFirestore();
    await pumpArticle(tester, user: FakeUser('g1', isAnonymous: true), db: db);

    expect(find.textContaining(kGuestNotesPrompt), findsNothing);

    await tester.longPress(find.byKey(ValueKey('note-block-$firstKey')));
    await tester.pumpAndSettle();
    expect(find.textContaining(kGuestNotesPrompt), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swatch-yellow')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('bookmark-${Bookmark.lessonKey('t1', 'intro')}')),
    );
    await tester.pumpAndSettle();

    expect(decorationOf(tester, firstKey).color, HighlightColour.yellow.fill);
    expect((await db.collection('notes').get()).docs, isEmpty);
    expect((await db.collection('study').get()).docs, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('study.v1.g1.notes'), contains(firstKey));
    expect(prefs.getString('study.v1.g1.bookmarks'), contains('intro'));

    // And they read back from the device in a fresh store.
    final local = LocalStudyStore('g1');
    expect((await local.lessonNotes('t1', 'intro')).single.colour,
        HighlightColour.yellow);
    // Control: another guest on the same device sees none of it.
    expect(await LocalStudyStore('g2').allNotes(), isEmpty);
  });

  testWidgets('a signed-in student\'s highlight goes to Firestore, not the device',
      (tester) async {
    // The control for the guest test above.
    SharedPreferences.setMockInitialValues({});
    final db = FakeFirebaseFirestore();
    await pumpArticle(tester, user: FakeUser('u1'), db: db);

    await tester.longPress(find.byKey(ValueKey('note-block-$firstKey')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swatch-yellow')));
    await tester.pumpAndSettle();

    expect((await db.collection('notes').get()).docs, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('study.')), isEmpty);
  });
}
