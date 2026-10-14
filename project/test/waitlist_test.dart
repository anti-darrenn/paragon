import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/waitlist_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WaitlistRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = WaitlistRepository(db);
  });

  test('joining writes exactly the fields the rule allows', () async {
    await repo.set('u1', const {}, 'biology', wanted: true);
    final d = (await db.collection('waitlist').doc('u1').get()).data()!;
    expect(d.keys.toSet(), {'userId', 'subjects', 'updatedAt'});
    expect(d['userId'], 'u1');
    expect(d['subjects'], ['biology']);
  });

  test('joining a second subject keeps the first; leaving removes one', () async {
    await repo.set('u1', const {}, 'biology', wanted: true);
    await repo.set('u1', {'biology'}, 'economics', wanted: true);
    expect(await repo.watch('u1').first, {'biology', 'economics'});
    await repo.set('u1', {'biology', 'economics'}, 'biology', wanted: false);
    expect(await repo.watch('u1').first, {'economics'});
  });

  test('counts students per subject', () async {
    await repo.set('u1', const {}, 'biology', wanted: true);
    await repo.set('u2', const {}, 'biology', wanted: true);
    await repo.set('u3', const {}, 'economics', wanted: true);
    expect(await repo.countFor('biology'), 2);
    // Control: a subject nobody asked for.
    expect(await repo.countFor('commerce'), 0);
  });
}
