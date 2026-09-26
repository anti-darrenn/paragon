import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/prefs/account_prefs.dart';
import 'package:paragon/core/providers/reading_settings_provider.dart';
import 'package:paragon/core/repositories/user_repository.dart';

/// Settings that follow an account: the stored shape, and the rule that an
/// analytics opt-out can spread but an opt-in cannot.
void main() {
  group('reading settings round trip', () {
    test('every value survives the account', () {
      const s = ReadingSettings(
        textScaleStep: 3,
        lineSpacing: LineSpacing.loose,
        font: ReadingFont.hyperlegible,
        lowDataMode: true,
      );
      expect(readingFromPrefs(readingToPrefs(s)), s);
    });

    test('an account with no reading keys has none', () {
      expect(readingFromPrefs(null), isNull);
      expect(readingFromPrefs({'analytics': false}), isNull);
    });

    // Control for the fallback test: a valid value is not replaced.
    test('valid values are kept', () {
      expect(readingFromPrefs({'textScaleStep': 4})!.textScaleStep, 4);
    });

    test('values from another build fall back one by one', () {
      final s = readingFromPrefs({
        'textScaleStep': 99,
        'lineSpacing': 'huge',
        'font': 'comic',
        'lowDataMode': true,
      })!;
      expect(s.textScaleStep, kDefaultTextScaleStep);
      expect(s.lineSpacing, LineSpacing.normal);
      expect(s.font, ReadingFont.standard);
      expect(s.lowDataMode, isTrue);
    });

    test('every stored value is one the rules accept', () {
      for (final spacing in LineSpacing.values) {
        expect(['normal', 'relaxed', 'loose'], contains(spacing.name));
      }
      for (final font in ReadingFont.values) {
        expect(['standard', 'hyperlegible'], contains(font.name));
      }
      expect(kTextScaleSteps.length - 1, 4);
    });
  });

  group('analytics', () {
    test('an account opt-out turns a device off', () {
      expect(
        accountTurnsAnalyticsOff(deviceEnabled: true, account: false),
        isTrue,
      );
    });
    test('an account opt-in never turns a device on', () {
      expect(
        accountTurnsAnalyticsOff(deviceEnabled: false, account: true),
        isFalse,
      );
    });
    test('no account choice changes nothing', () {
      expect(
        accountTurnsAnalyticsOff(deviceEnabled: true, account: null),
        isFalse,
      );
    });
    test('reads only a real bool', () {
      expect(analyticsFromPrefs({'analytics': 'no'}), isNull);
      expect(analyticsFromPrefs({'analytics': false}), isFalse);
    });
  });

  test('setPrefs merges key by key', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'prefs': {'analytics': false},
    });
    await UserRepository(db).setPrefs(uid: 'u1', prefs: {'font': 'standard'});
    final prefs =
        (await db.collection('users').doc('u1').get()).data()!['prefs'] as Map;
    expect(prefs['analytics'], isFalse);
    expect(prefs['font'], 'standard');
  });
}
