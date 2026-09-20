import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
}
