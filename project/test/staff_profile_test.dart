import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/account_repository.dart';
import 'package:paragon/features/admin/studio/staff_profile.dart';

/// The team's view of each other: a published name and avatar.
void main() {
  group('staffProfileIsStale', () {
    const published = StaffProfile(displayName: 'Ada', avatar: 'preset:owl');

    test('nothing published yet is stale', () {
      expect(
        staffProfileIsStale(null, displayName: 'Ada', avatar: null),
        isTrue,
      );
    });
    // Control: a match writes nothing, which is what keeps the sync cheap.
    test('a match is not stale', () {
      expect(
        staffProfileIsStale(
          published,
          displayName: 'Ada',
          avatar: 'preset:owl',
        ),
        isFalse,
      );
    });
    test('a new avatar is stale', () {
      expect(
        staffProfileIsStale(
          published,
          displayName: 'Ada',
          avatar: 'initials:teal',
        ),
        isTrue,
      );
    });
    test('a new name is stale', () {
      expect(
        staffProfileIsStale(
          published,
          displayName: 'Ada L',
          avatar: 'preset:owl',
        ),
        isTrue,
      );
    });
  });

  test('fromData tolerates missing and wrong fields', () {
    expect(StaffProfile.fromData(null), isNull);
    final p = StaffProfile.fromData({'displayName': 7});
    expect(p!.displayName, '7');
    expect(p.avatar, isNull);
  });

  test("deleting a team member's account removes their profile", () async {
    final db = FakeFirebaseFirestore();
    await db.collection('staffProfiles').doc('u1').set({'displayName': 'A'});
    await AccountRepository(db).deleteOwnedDocuments('u1');
    expect(
      (await db.collection('staffProfiles').doc('u1').get()).exists,
      isFalse,
    );
  });
}
