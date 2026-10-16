import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/sign_out.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what signing out removes from a shared computer', () {
    test("the student's exam in progress goes", () {
      expect(
        deviceKeyBelongsTo(
          'waec_exam_in_progress:u1:maths',
          uid: 'u1',
          wasGuest: false,
        ),
        isTrue,
      );
    });

    test("a guest's device-only notes and cards go", () {
      for (final key in [
        'study.v1.g1.notes',
        'study.v1.g1.bookmarks',
        'study.v1.g1.cards',
      ]) {
        expect(
          deviceKeyBelongsTo(key, uid: 'g1', wasGuest: true),
          isTrue,
          reason: key,
        );
      }
    });

    test("an account's study copy stays: it may still be copying up", () {
      expect(
        deviceKeyBelongsTo('study.v1.u1.notes', uid: 'u1', wasGuest: false),
        isFalse,
      );
    });

    test('control: other people, settings and studio backups stay', () {
      for (final key in [
        'waec_exam_in_progress:u2:maths',
        'study.v1.u2.notes',
        'studio.backup.v1.t1.r1',
        'appearance',
      ]) {
        expect(
          deviceKeyBelongsTo(key, uid: 'u1', wasGuest: true),
          isFalse,
          reason: key,
        );
      }
      expect(
        deviceKeyBelongsTo('waec_exam_in_progress::x', uid: '', wasGuest: true),
        isFalse,
      );
    });

    test('clearDeviceDataFor removes exactly those keys', () async {
      SharedPreferences.setMockInitialValues({
        'waec_exam_in_progress:g1:maths': '{}',
        'study.v1.g1.notes': '[]',
        'study.v1.u2.notes': '[]',
        'appearance': 'dark',
      });
      await clearDeviceDataFor(uid: 'g1', wasGuest: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'study.v1.u2.notes', 'appearance'});
    });
  });
}
