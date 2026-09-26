import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/lesson_progress.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/features/account/guest_upgrade.dart';
import 'package:paragon/features/study/cards/card_store.dart';
import 'package:paragon/features/study/cards/leitner.dart';
import 'package:paragon/features/study/notes/study_models.dart';
import 'package:paragon/features/study/notes/study_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Carrying a guest's work into the account they make.
///
/// The uid does not change on an upgrade, so everything the guest wrote to
/// Firestore is already theirs. These tests cover what was never written:
/// device-only notes, bookmarks and cards, and in-memory lesson ticks.
void main() {
  const uid = 'guest-1';
  late FakeFirebaseFirestore db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
  });

  LessonNote note(String block, String text) => LessonNote(
    id: 'ignored',
    topicId: 't1',
    resourceId: 'r1',
    subjectId: 's1',
    blockKey: block,
    colour: HighlightColour.yellow,
    text: text,
    snapshot: 'snapshot',
  );

  const bookmark = Bookmark(
    kind: BookmarkKind.lesson,
    topicId: 't1',
    resourceId: 'r1',
    title: 'Vectors',
  );

  Future<int> copy() => copyGuestStudyData(
    localStudy: LocalStudyStore(uid),
    study: FirestoreStudyStore(db, uid),
    localCards: LocalCardStore(uid),
    cards: FirestoreCardStore(db, uid),
  );

  group('copyGuestStudyData', () {
    // Control: with nothing on the device nothing is written, so the
    // assertions below are about the copy and not about leftovers.
    test('nothing on the device writes nothing', () async {
      expect(await copy(), 0);
      expect((await db.collection('notes').get()).docs, isEmpty);
      expect((await db.collection('study').doc(uid).get()).exists, isFalse);
    });

    test('copies notes, bookmarks and cards, then clears the device', () async {
      final local = LocalStudyStore(uid);
      await local.createNote(note('b1', 'first'));
      await local.createNote(note('b2', 'second'));
      await local.addBookmark(bookmark);
      await LocalCardStore(
        uid,
      ).save({'c1': CardState(box: 2, due: DateTime(2026, 10, 1))});

      expect(await copy(), 4);

      final notes = await db.collection('notes').get();
      expect(
        notes.docs.map((d) => d['text']),
        containsAll(['first', 'second']),
      );
      expect(notes.docs.every((d) => d['userId'] == uid), isTrue);

      final study = (await db.collection('study').doc(uid).get()).data()!;
      expect((study['bookmarks'] as Map).keys, contains(bookmark.key));
      expect((study['cards'] as Map)['c1']['box'], 2);

      expect(await LocalStudyStore(uid).hasData, isFalse);
      expect(await LocalCardStore(uid).hasData, isFalse);
    });

    test('running it again does not duplicate anything', () async {
      await LocalStudyStore(uid).createNote(note('b1', 'only'));
      await copy();
      await copy();
      expect((await db.collection('notes').get()).docs, hasLength(1));
    });

    test('another guest on the same device is left alone', () async {
      await LocalStudyStore('someone-else').createNote(note('b1', 'theirs'));
      await copy();
      expect(await LocalStudyStore('someone-else').hasData, isTrue);
      expect((await db.collection('notes').get()).docs, isEmpty);
    });
  });

  group('LearnProgressRepository.markAllComplete', () {
    test('writes every in-memory completion in one document', () async {
      final lessons = LessonProgress.empty
          .withCompleted('t1', 'r1', subjectId: 's1')
          .withCompleted('t1', 'r2', subjectId: 's1')
          .withCompleted('t2', 'r9', subjectId: 's2');

      await LearnProgressRepository(
        db,
      ).markAllComplete(uid: uid, lessons: lessons);

      final stored = LessonProgress.fromDocument(
        (await db.collection('learn').doc(uid).get()).data(),
      );
      expect(stored.isComplete('t1', 'r1'), isTrue);
      expect(stored.isComplete('t1', 'r2'), isTrue);
      expect(stored.isComplete('t2', 'r9'), isTrue);
      expect(stored.forTopic('t2').subjectId, 's2');
      expect(stored.completedCount, 3);
    });

    test('keeps a test result already on the document', () async {
      await db.collection('learn').doc(uid).set({
        'topics': {
          't1': {'passed': true, 'bestScore': 90, 'attempts': 1},
        },
      });
      await LearnProgressRepository(db).markAllComplete(
        uid: uid,
        lessons: LessonProgress.empty.withCompleted('t1', 'r1'),
      );
      final t1 =
          ((await db.collection('learn').doc(uid).get()).data()!['topics']
                  as Map)['t1']
              as Map;
      expect(t1['passed'], isTrue);
      expect((t1['completed'] as Map)['r1'], isTrue);
    });

    test('nothing completed writes nothing', () async {
      await LearnProgressRepository(
        db,
      ).markAllComplete(uid: uid, lessons: LessonProgress.empty);
      expect((await db.collection('learn').doc(uid).get()).exists, isFalse);
    });
  });
}
