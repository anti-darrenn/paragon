import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/account_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountRepository.deleteOwnedDocuments', () {
    late FakeFirebaseFirestore db;
    late AccountRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = AccountRepository(db);

      await db.collection('users').doc('u1').set({'uid': 'u1'});
      await db.collection('users').doc('u2').set({'uid': 'u2'});
      await db.collection('usernames').doc('ada').set({
        'uid': 'u1',
        'raw': 'ada',
      });

      for (var i = 0; i < 5; i++) {
        await db.collection('attempts').add({'userId': 'u1', 'n': i});
        await db.collection('attempts').add({'userId': 'u2', 'n': i});
      }
      await db.collection('flags').add({'userId': 'u1', 'questionId': 'q1'});
      await db.collection('flags').add({'userId': 'u2', 'questionId': 'q2'});

      // The two uid-keyed single documents. Both are easy to forget when a
      // collection is added, and forgetting leaves a student who asked to
      // be deleted, and mostly was.
      await db.collection('progress').doc('u1').set({
        'userId': 'u1',
        'topics': {'t1': {'answered': 20, 'correct': 18}},
      });
      await db.collection('progress').doc('u2').set({'userId': 'u2'});
      await db.collection('learn').doc('u1').set({
        'userId': 'u1',
        'topics': {'t1': {'passed': true, 'bestScore': 90, 'attempts': 1}},
      });
      await db.collection('learn').doc('u2').set({'userId': 'u2'});

      // Highlights and notes (a query) and bookmarks (a uid-keyed doc).
      // u2's note is on the same lesson, so only the userId filter can be
      // what spares it.
      for (final uid in ['u1', 'u1', 'u2']) {
        await db.collection('notes').add({
          'userId': uid,
          'topicId': 't1',
          'resourceId': 'intro',
          'blockKey': 'paragraph:0000:0',
          'text': 'note by $uid',
        });
      }
      await db.collection('study').doc('u1').set({
        'userId': 'u1',
        'bookmarks': {'lesson:t1:intro': {'kind': 'lesson'}},
      });
      await db.collection('study').doc('u2').set({'userId': 'u2'});
    });

    test('removes the user document, attempts and flags', () async {
      await repo.deleteOwnedDocuments('u1');

      expect((await db.collection('users').doc('u1').get()).exists, isFalse);

      final attempts = await db
          .collection('attempts')
          .where('userId', isEqualTo: 'u1')
          .get();
      expect(attempts.docs, isEmpty);

      final flags = await db
          .collection('flags')
          .where('userId', isEqualTo: 'u1')
          .get();
      expect(flags.docs, isEmpty);
    });

    test('removes the progress and topic-test documents', () async {
      await repo.deleteOwnedDocuments('u1');

      expect((await db.collection('progress').doc('u1').get()).exists, isFalse);
      // The drill gate's record. Added with the topic test; if this ever
      // starts failing, a deleted student's test history is surviving them.
      expect((await db.collection('learn').doc('u1').get()).exists, isFalse);
    });

    test('removes notes and the bookmarks document', () async {
      await repo.deleteOwnedDocuments('u1');

      final notes = await db
          .collection('notes')
          .where('userId', isEqualTo: 'u1')
          .get();
      expect(notes.docs, isEmpty);
      expect((await db.collection('study').doc('u1').get()).exists, isFalse);

      // Control: another student's note on the same lesson, and their
      // study document, survive.
      final theirs = await db
          .collection('notes')
          .where('userId', isEqualTo: 'u2')
          .get();
      expect(theirs.docs, hasLength(1));
      expect((await db.collection('study').doc('u2').get()).exists, isTrue);
    });

    test('leaves other users entirely alone', () async {
      await repo.deleteOwnedDocuments('u1');

      expect((await db.collection('users').doc('u2').get()).exists, isTrue);
      final attempts = await db
          .collection('attempts')
          .where('userId', isEqualTo: 'u2')
          .get();
      expect(attempts.docs.length, 5);
      final flags = await db
          .collection('flags')
          .where('userId', isEqualTo: 'u2')
          .get();
      expect(flags.docs.length, 1);
      expect((await db.collection('progress').doc('u2').get()).exists, isTrue);
      expect((await db.collection('learn').doc('u2').get()).exists, isTrue);
    });

    test('keeps the username reservation', () async {
      // Permanent by design: releasing a handle would let someone else
      // claim it and inherit the previous owner's identity. The privacy
      // policy states this, so the behaviour is load-bearing.
      await repo.deleteOwnedDocuments('u1');

      final reservation = await db.collection('usernames').doc('ada').get();
      expect(reservation.exists, isTrue);
      expect(reservation.data()?['uid'], 'u1');
    });

    test('deletes more documents than fit in a single batch', () async {
      // The chunker loops until the collection is drained; 450 is the
      // per-batch cap, so 460 forces a second pass.
      final db2 = FakeFirebaseFirestore();
      final repo2 = AccountRepository(db2);
      await db2.collection('users').doc('big').set({'uid': 'big'});
      for (var i = 0; i < 460; i++) {
        await db2.collection('attempts').add({'userId': 'big', 'n': i});
      }

      await repo2.deleteOwnedDocuments('big');

      final left = await db2
          .collection('attempts')
          .where('userId', isEqualTo: 'big')
          .get();
      expect(left.docs, isEmpty);
    });

    test('is safe to run for a user with no data', () async {
      await db.collection('users').doc('empty').set({'uid': 'empty'});
      await repo.deleteOwnedDocuments('empty');
      expect((await db.collection('users').doc('empty').get()).exists, isFalse);
    });
  });

  group('AccountRepository.deleteAccount', () {
    // The documents go while the student is still signed in, then the
    // auth user. The other order never worked: once the auth user is gone
    // the client is signed out and every owner-only delete is refused
    // (reproduced against the emulators, 2026-10-16).
    late FakeFirebaseFirestore db;
    late AccountRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = AccountRepository(db);
      await db.collection('users').doc('u1').set({'uid': 'u1'});
      await db.collection('attempts').add({'userId': 'u1'});
    });

    Future<bool> userDocExists() async =>
        (await db.collection('users').doc('u1').get()).exists;

    test('deletes the documents before the auth user', () async {
      final user = _FakeUser(
        authTime: DateTime.now().subtract(const Duration(minutes: 1)),
        onDelete: userDocExists,
      );
      final outcome = await repo.deleteAccount(user);
      expect(outcome, AccountDeletionOutcome.deleted);
      expect(user.deleted, isTrue);
      expect(
        user.docExistedAtDelete,
        isFalse,
        reason: 'documents must be gone before the auth user is',
      );
      final left = await db.collection('attempts').get();
      expect(left.docs, isEmpty);
    });

    test('a stale sign-in touches nothing and asks to confirm', () async {
      final user = _FakeUser(
        authTime: DateTime.now().subtract(const Duration(hours: 2)),
        onDelete: userDocExists,
      );
      final outcome = await repo.deleteAccount(user);
      expect(outcome, AccountDeletionOutcome.needsRecentLogin);
      expect(user.deleted, isFalse);
      expect(await userDocExists(), isTrue);
    });

    test('a guest is deleted without the age check', () async {
      final user = _FakeUser(
        authTime: DateTime.now().subtract(const Duration(days: 3)),
        anonymous: true,
        onDelete: userDocExists,
      );
      expect(await repo.deleteAccount(user), AccountDeletionOutcome.deleted);
      expect(await userDocExists(), isFalse);
    });
  });
}

class _FakeToken implements IdTokenResult {
  _FakeToken(this.authTime);
  @override
  final DateTime? authTime;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({
    required this.authTime,
    required this.onDelete,
    this.anonymous = false,
  });

  final DateTime authTime;
  final Future<bool> Function() onDelete;
  final bool anonymous;
  bool deleted = false;
  bool? docExistedAtDelete;

  @override
  String get uid => 'u1';

  @override
  bool get isAnonymous => anonymous;

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _FakeToken(authTime);

  @override
  Future<void> delete() async {
    docExistedAtDelete = await onDelete();
    deleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
