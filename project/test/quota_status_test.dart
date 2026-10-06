import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/data/quota_status.dart';

void main() {
  group('quotaResetUtc', () {
    test('summer: midnight PDT is 07:00 UTC (08:00 in Lagos)', () {
      expect(
        quotaResetUtc(DateTime.utc(2026, 10, 3, 12)),
        DateTime.utc(2026, 10, 4, 7),
      );
    });

    test('winter: midnight PST is 08:00 UTC (09:00 in Lagos)', () {
      expect(
        quotaResetUtc(DateTime.utc(2027, 1, 15, 12)),
        DateTime.utc(2027, 1, 16, 8),
      );
    });

    test('just before the reset it is the next one, not tomorrow\'s', () {
      expect(
        quotaResetUtc(DateTime.utc(2026, 10, 4, 6, 59)),
        DateTime.utc(2026, 10, 4, 7),
      );
      expect(
        quotaResetUtc(DateTime.utc(2026, 10, 4, 7)),
        DateTime.utc(2026, 10, 5, 7),
      );
    });

    test('the night daylight time ends (1 Nov 2026)', () {
      // 31 Oct is daylight time; midnight starting 1 Nov is still PDT.
      expect(
        quotaResetUtc(DateTime.utc(2026, 10, 31, 20)),
        DateTime.utc(2026, 11, 1, 7),
      );
      // After it, midnight starting 2 Nov is PST.
      expect(
        quotaResetUtc(DateTime.utc(2026, 11, 1, 20)),
        DateTime.utc(2026, 11, 2, 8),
      );
    });

    test('the night daylight time starts (14 Mar 2027)', () {
      expect(
        quotaResetUtc(DateTime.utc(2027, 3, 13, 20)),
        DateTime.utc(2027, 3, 14, 8),
      );
      expect(
        quotaResetUtc(DateTime.utc(2027, 3, 14, 20)),
        DateTime.utc(2027, 3, 15, 7),
      );
    });
  });

  group('QuotaStatus', () {
    tearDown(() => QuotaStatus.instance.noteServerSuccess());

    test('only resource-exhausted marks the quota spent', () {
      final status = QuotaStatus.instance;
      // Control: an outage is not a spent quota.
      expect(
        status.noteError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isFalse,
      );
      expect(status.value, isFalse);
      expect(status.noteError(StateError('x')), isFalse);

      expect(
        status.noteError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'resource-exhausted',
          ),
        ),
        isTrue,
      );
      expect(status.value, isTrue);

      status.noteServerSuccess();
      expect(status.value, isFalse);
    });
  });
}
