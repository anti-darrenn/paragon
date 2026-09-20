import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/guest_limits.dart';

/// The guest subject lock.
///
/// It was previously written inline in `waec_subject_screen.dart` as
/// `subject.name.toLowerCase() != 'mathematics'`, which was correct and
/// untested. The reason it moved here is that Learning Mode now enforces
/// the same restriction, and two inline copies of a product rule drift —
/// the drift being a guest who can drill Physics but cannot sit a Physics
/// exam, with nothing in the code saying which was intended.
void main() {
  group('GuestLimits.allowsSubject', () {
    test('a guest gets Mathematics', () {
      expect(GuestLimits.allowsSubject('Mathematics'), isTrue);
    });

    test('matches regardless of case or surrounding space', () {
      // One side of the comparison is a Firestore document, the other a
      // hand-written catalog entry; neither guarantees the other's casing.
      expect(GuestLimits.allowsSubject('mathematics'), isTrue);
      expect(GuestLimits.allowsSubject('  MATHEMATICS  '), isTrue);
    });

    test('Further Mathematics is a different subject', () {
      // The control that gives this file its value. A `contains` or
      // `startsWith` implementation would pass every other test here and
      // silently unlock a second subject.
      expect(GuestLimits.allowsSubject('Further Mathematics'), isFalse);
    });

    test('everything else is closed', () {
      for (final name in ['Physics', 'Chemistry', 'Government', '']) {
        expect(
          GuestLimits.allowsSubject(name),
          isFalse,
          reason: '$name should be closed to guests',
        );
      }
    });
  });

  group('GuestLimits.locks', () {
    test('locks nothing for a signed-in student', () {
      for (final name in ['Physics', 'Mathematics', 'Further Mathematics']) {
        expect(GuestLimits.locks(isGuest: false, subjectName: name), isFalse);
      }
    });

    test('locks everything but the open subject for a guest', () {
      expect(
        GuestLimits.locks(isGuest: true, subjectName: 'Mathematics'),
        isFalse,
      );
      expect(GuestLimits.locks(isGuest: true, subjectName: 'Physics'), isTrue);
    });
  });

  group('messages', () {
    test('the lock message names the subject a guest does get', () {
      // Otherwise it tells a student what they cannot do and leaves them
      // to discover the rest by tapping.
      expect(
        GuestLimits.lockedSubjectMessage,
        contains(GuestLimits.openSubject),
      );
    });

    test('the progress message says progress is not saved', () {
      expect(GuestLimits.progressNotKeptMessage, contains('not'));
      expect(
        GuestLimits.progressNotKeptMessage.toLowerCase(),
        contains('saved'),
      );
    });
  });
}
