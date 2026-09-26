import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/account_repository.dart';
import 'package:paragon/features/account/export_screen.dart';

/// "Download my data": what goes in the file, and that it can be written.
///
/// The export must cover the same documents account deletion removes. The
/// last test checks that directly, so adding a collection to one and not
/// the other fails here.
void main() {
  late FakeFirebaseFirestore db;
  late AccountRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = AccountRepository(db);
    final at = Timestamp.fromDate(DateTime.utc(2026, 9, 1, 12));
    await db.collection('users').doc('u1').set({
      'username': 'ada_l',
      'createdAt': at,
      'profile': {'school': 'Kings'},
    });
    await db.collection('progress').doc('u1').set({'topics': {}});
    await db.collection('learn').doc('u1').set({'topics': {}});
    await db.collection('study').doc('u1').set({'bookmarks': {}});
    await db.collection('attempts').add({'userId': 'u1', 'timestamp': at});
    await db.collection('attempts').add({'userId': 'u1', 'timestamp': at});
    await db.collection('notes').add({'userId': 'u1', 'text': 'hi'});
    await db.collection('flags').add({'userId': 'u1', 'reason': 'wrong'});
    // Someone else's, which must not appear.
    await db.collection('attempts').add({'userId': 'u2', 'timestamp': at});
  });

  test('contains every owned document and nothing of anyone else', () async {
    final out = await repo.exportOwnedDocuments('u1');
    expect(out['uid'], 'u1');
    expect((out['users'] as Map)['username'], 'ada_l');
    expect(out['attempts'], hasLength(2));
    expect(out['notes'], hasLength(1));
    expect(out['flags'], hasLength(1));
    for (final key in ['progress', 'learn', 'study']) {
      expect(out.containsKey(key), isTrue, reason: key);
    }
  });

  test('timestamps become ISO strings, nested ones too', () async {
    final out = await repo.exportOwnedDocuments('u1');
    expect((out['users'] as Map)['createdAt'], '2026-09-01T12:00:00.000Z');
    final attempt = (out['attempts'] as List).first as Map;
    expect(attempt['timestamp'], '2026-09-01T12:00:00.000Z');
    expect(attempt['id'], isA<String>());
  });

  test('the whole export encodes as JSON', () async {
    final out = await repo.exportOwnedDocuments('u1');
    expect(() => jsonEncode(out), returnsNormally);
  });

  test('a missing document is left out, not shown as empty', () async {
    final out = await repo.exportOwnedDocuments('u1');
    expect(out.containsKey('accountRequests'), isFalse);
  });

  test('exportSize counts owned documents only', () async {
    // 6 keyed-by-uid slots + 2 attempts + 1 note + 1 flag.
    expect(await repo.exportSize('u1'), 10);
  });

  test('covers everything deletion removes', () async {
    await repo.requestSignOutEverywhere('u1');
    await db.collection('staffProfiles').doc('u1').set({'displayName': 'A'});
    final before = await repo.exportOwnedDocuments('u1');
    await repo.deleteOwnedDocuments('u1');
    final after = await repo.exportOwnedDocuments('u1');

    // Control: the export saw data before deletion...
    expect(
      before.keys,
      containsAll(['users', 'accountRequests', 'staffProfiles']),
    );
    // ...and deletion left nothing the export can find.
    for (final key in [
      'users',
      'progress',
      'learn',
      'study',
      'accountRequests',
      'staffProfiles',
    ]) {
      expect(after.containsKey(key), isFalse, reason: key);
    }
    for (final key in ['attempts', 'notes', 'flags']) {
      expect(after[key], isEmpty, reason: key);
    }
  });

  group('limits and naming', () {
    final now = DateTime(2026, 9, 26, 10);
    test('first export is allowed', () {
      expect(nextExportAllowedAt(null, now: now), isNull);
    });
    test('a second within a day is not', () {
      expect(
        nextExportAllowedAt(now.subtract(const Duration(hours: 2)), now: now),
        isNotNull,
      );
    });
    test('after a day it is again', () {
      expect(
        nextExportAllowedAt(now.subtract(const Duration(hours: 25)), now: now),
        isNull,
      );
    });
    test('the file name identifies nobody', () {
      expect(exportFileName(now), 'paragon-data-2026-09-26.json');
    });
  });
}
