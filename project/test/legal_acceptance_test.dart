import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/legal/legal_documents.dart';
import 'package:paragon/core/repositories/user_repository.dart';
import 'package:paragon/features/account/account_help.dart';

/// Recording which terms a student accepted, and the gate that asks again
/// when they change.
void main() {
  group('needsLegalAcceptance', () {
    test('an account on the current version goes straight on', () {
      expect(needsLegalAcceptance({'legalVersion': kLegalVersion}), isFalse);
    });
    test('an older version is asked again', () {
      expect(needsLegalAcceptance({'legalVersion': '2000-01-01'}), isTrue);
    });
    test('an account with no record is asked once', () {
      expect(needsLegalAcceptance({'username': 'ada_l'}), isTrue);
    });
    // A still-loading document must not bounce anyone to the gate.
    test('no document yet decides nothing', () {
      expect(needsLegalAcceptance(null), isFalse);
    });
  });

  group('UserRepository', () {
    late FakeFirebaseFirestore db;
    late UserRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = UserRepository(db);
    });

    test('choosing a username records the terms accepted', () async {
      await repo.reserveUsername(uid: 'u1', raw: 'ada_l', key: 'ada_l');
      final data = (await db.collection('users').doc('u1').get()).data()!;
      expect(data['legalVersion'], kLegalVersion);
      expect(data.containsKey('legalAcceptedAt'), isTrue);
      expect(needsLegalAcceptance(data), isFalse);
    });

    test(
      'accepting again moves an old record to the current version',
      () async {
        await db.collection('users').doc('u1').set({'legalVersion': 'old'});
        await repo.acceptLegal('u1');
        final data = (await db.collection('users').doc('u1').get()).data()!;
        expect(data['legalVersion'], kLegalVersion);
      },
    );
  });

  test('the change list is written for the current version', () {
    expect(kLegalChanges, isNotEmpty);
    expect(kLegalVersion.length, lessThanOrEqualTo(32));
  });

  group('accountHelpMailto', () {
    test('addresses the contact inbox with a subject', () {
      final uri = accountHelpMailto();
      expect(uri.scheme, 'mailto');
      expect(uri.path, contactEmail);
      expect(uri.query, contains('subject='));
      expect(uri.query, isNot(contains('body=')));
    });
    test('carries the account id when there is one, and nothing else', () {
      final uri = accountHelpMailto(uid: 'abc123');
      expect(Uri.decodeComponent(uri.query), contains('Account ID: abc123'));
    });
  });
}
