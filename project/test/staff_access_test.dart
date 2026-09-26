import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/repositories/staff_invite_repository.dart';

void main() {
  group('StaffAccess.fromClaims', () {
    test('no subjects claim means every subject', () {
      final a = StaffAccess.fromClaims({'writer': true});
      expect(a.covers('anything'), isTrue);
      expect(a.roleIn('anything'), StaffRole.writer);
    });

    test('a subjects claim limits the role', () {
      final a = StaffAccess.fromClaims({
        'reviewer': true,
        'subjects': ['m1', 'p1'],
      });
      expect(a.roleIn('m1'), StaffRole.reviewer);
      // Control: outside the list the account has no role at all.
      expect(a.roleIn('c1'), StaffRole.none);
    });

    test('an admin is never limited, whatever the claim says', () {
      final a = StaffAccess.fromClaims({
        'admin': true,
        'subjects': ['m1'],
      });
      expect(a.roleIn('c1'), StaffRole.admin);
    });

    test('no claims, no access', () {
      expect(StaffAccess.fromClaims(null).roleIn('m1'), StaffRole.none);
    });
  });

  group('invite keys', () {
    test('an email is one request however it is typed', () {
      expect(inviteKey('  Ada@Example.COM '), 'ada@example.com');
    });

    test('only plausible email addresses are accepted', () {
      expect(looksLikeEmail('ada@example.com'), isTrue);
      for (final bad in ['ada', 'ada@', '@x.com', 'a b@x.com', 'a/b@x.com']) {
        expect(looksLikeEmail(bad), isFalse, reason: bad);
      }
    });
  });
}
