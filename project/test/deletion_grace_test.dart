import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/account_repository.dart';

/// The 30-day grace period: scheduling removes nothing, cancelling puts
/// the account back exactly as it was.
void main() {
  late FakeFirebaseFirestore db;
  late AccountRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = AccountRepository(db);
    await db.collection('users').doc('u1').set({'username': 'ada_l'});
    await db.collection('attempts').add({'userId': 'u1'});
  });

  Future<Map<String, dynamic>> user() async =>
      (await db.collection('users').doc('u1').get()).data()!;

  test('scheduling stamps the request and removes nothing', () async {
    await repo.scheduleDeletion('u1');
    expect((await user()).containsKey('deletionRequestedAt'), isTrue);
    expect((await user())['username'], 'ada_l');
    expect((await db.collection('attempts').get()).docs, hasLength(1));
  });

  test('cancelling removes the stamp and nothing else', () async {
    await repo.scheduleDeletion('u1');
    await repo.cancelDeletion('u1');
    expect((await user()).containsKey('deletionRequestedAt'), isFalse);
    expect((await user())['username'], 'ada_l');
  });

  test('the deletion date is 30 days on', () {
    expect(deletionDateFor(DateTime(2026, 9, 26)), DateTime(2026, 10, 26));
    expect(kDeletionGracePeriod.inDays, 30);
  });
}
