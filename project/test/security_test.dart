import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/account_repository.dart';
import 'package:paragon/features/account/account_sync.dart';
import 'package:paragon/features/account/reauth.dart';
import 'package:paragon/features/account/security_screen.dart';

/// Sign-in and security: the pure decisions behind the screen, and the one
/// Firestore write it makes.
void main() {
  group('SignInMethods', () {
    test('reads password and Google', () {
      final m = SignInMethods.fromProviderIds(['password', 'google.com']);
      expect(m.password, isTrue);
      expect(m.google, isTrue);
    });

    test('a Google-only account has no password', () {
      final m = SignInMethods.fromProviderIds(['google.com']);
      expect(m.password, isFalse);
      expect(m.google, isTrue);
    });

    test('a guest has neither', () {
      final m = SignInMethods.fromProviderIds(const []);
      expect(m.password, isFalse);
      expect(m.google, isFalse);
    });
  });

  group('newPasswordProblem', () {
    test('accepts a matching password of 6+', () {
      expect(newPasswordProblem('secret1', 'secret1'), isNull);
    });
    test('refuses one that is too short', () {
      expect(newPasswordProblem('abc', 'abc'), isNotNull);
    });
    test('refuses two that differ', () {
      expect(newPasswordProblem('secret1', 'secret2'), isNotNull);
    });
  });

  group('emailNeedsSync', () {
    test('a changed Auth email is copied', () {
      expect(emailNeedsSync(stored: 'old@x.com', auth: 'new@x.com'), isTrue);
    });
    // Control for the case below.
    test('agreeing emails write nothing', () {
      expect(emailNeedsSync(stored: 'a@x.com', auth: 'a@x.com'), isFalse);
    });
    test('an Auth user with no email never erases the stored one', () {
      expect(emailNeedsSync(stored: 'a@x.com', auth: null), isFalse);
      expect(emailNeedsSync(stored: 'a@x.com', auth: ''), isFalse);
    });
    test('a missing stored email is filled in', () {
      expect(emailNeedsSync(stored: null, auth: 'a@x.com'), isTrue);
    });
  });

  test('formatAccountDate', () {
    expect(formatAccountDate(null), '—');
    expect(
      formatAccountDate(DateTime(2026, 9, 26, 14, 5)),
      '26 Sep 2026, 14:05',
    );
  });

  group('AccountRepository and accountRequests', () {
    late FakeFirebaseFirestore db;
    late AccountRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = AccountRepository(db);
    });

    test('a sign-out request has exactly the shape the rules accept', () async {
      await repo.requestSignOutEverywhere('u1');
      final data = (await db.collection('accountRequests').doc('u1').get())
          .data()!;
      expect(data.keys.toSet(), {'type', 'requestedAt'});
      expect(data['type'], 'revokeSessions');
    });

    test('deleting an account removes a pending request', () async {
      await repo.requestSignOutEverywhere('u1');
      await repo.deleteOwnedDocuments('u1');
      expect(
        (await db.collection('accountRequests').doc('u1').get()).exists,
        isFalse,
      );
    });
  });
}
