import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/onboarding/onboarding_step.dart';
import 'package:paragon/core/repositories/user_repository.dart';

/// Changing a username: the 90-day cooldown and the reservation that is
/// never given back. `firestore.rules` enforces both again server-side;
/// `verify_rules.js` checks that half.
void main() {
  group('UsernameRules.nextChangeAllowedAt', () {
    final now = DateTime(2026, 9, 26);

    test('never changed means now', () {
      expect(UsernameRules.nextChangeAllowedAt(null, now: now), isNull);
    });

    test('changed yesterday means 90 days from then', () {
      final last = now.subtract(const Duration(days: 1));
      expect(
        UsernameRules.nextChangeAllowedAt(last, now: now),
        last.add(const Duration(days: 90)),
      );
    });

    // Control: the boundary goes the right way.
    test('changed 91 days ago means now', () {
      final last = now.subtract(const Duration(days: 91));
      expect(UsernameRules.nextChangeAllowedAt(last, now: now), isNull);
    });

    test('the cooldown matches the rules file', () {
      expect(UsernameRules.changeCooldown.inDays, 90);
    });
  });

  group('UserRepository.changeUsername', () {
    late FakeFirebaseFirestore db;
    late UserRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = UserRepository(db);
      await repo.reserveUsername(uid: 'u1', raw: 'Ada_L', key: 'ada_l');
    });

    Future<Map<String, dynamic>> user() async =>
        (await db.collection('users').doc('u1').get()).data()!;

    test('moves to a free handle and stamps the change', () async {
      final ok = await repo.changeUsername(
        uid: 'u1',
        raw: 'Ada_Lovelace',
        key: 'ada_lovelace',
      );
      expect(ok, isTrue);
      final data = await user();
      expect(data['username'], 'Ada_Lovelace');
      expect(data['usernameKey'], 'ada_lovelace');
      expect(data.containsKey('usernameChangedAt'), isTrue);
    });

    test('the old handle stays reserved to its owner', () async {
      await repo.changeUsername(
        uid: 'u1',
        raw: 'Ada_Lovelace',
        key: 'ada_lovelace',
      );
      final old = await db.collection('usernames').doc('ada_l').get();
      expect(old.exists, isTrue);
      expect(old['uid'], 'u1');
    });

    test("someone else's handle is refused and nothing changes", () async {
      await repo.reserveUsername(uid: 'u2', raw: 'grace', key: 'grace');
      final ok = await repo.changeUsername(
        uid: 'u1',
        raw: 'grace',
        key: 'grace',
      );
      expect(ok, isFalse);
      expect((await user())['username'], 'Ada_L');
      expect((await user()).containsKey('usernameChangedAt'), isFalse);
    });

    test('a capitals-only change keeps the same reservation', () async {
      final ok = await repo.changeUsername(
        uid: 'u1',
        raw: 'ADA_L',
        key: 'ada_l',
      );
      expect(ok, isTrue);
      expect((await user())['username'], 'ADA_L');
    });
  });
}
