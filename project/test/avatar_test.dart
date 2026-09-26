import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/avatar.dart';
import 'package:paragon/core/repositories/user_repository.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/features/profile/me_screen.dart';

/// Avatars, the bio, and the `/me` date label.
///
/// `Avatar.parse` runs on every screen that draws the student, from a field
/// a client wrote, so the part that matters is what it does with garbage:
/// it must always produce something drawable, and the same something for
/// the same student.
void main() {
  group('Avatar.parse', () {
    test('reads a preset', () {
      final a = Avatar.parse('preset:owl', seed: 'u1');
      expect(a.isPreset, isTrue);
      expect(a.preset!.id, 'owl');
      expect(a.storageValue, 'preset:owl');
    });

    test('reads initials on a colour', () {
      final a = Avatar.parse('initials:teal', seed: 'u1');
      expect(a.isPreset, isFalse);
      expect(a.colorKey, 'teal');
      expect(a.storageValue, 'initials:teal');
    });

    // Control: a valid value must not be treated as garbage, or every
    // fallback test below would pass for the wrong reason.
    test('a valid value is not replaced by the fallback', () {
      final fallback = Avatar.parse(null, seed: 'u1');
      final chosen = Avatar.parse('preset:rocket', seed: 'u1');
      expect(chosen, isNot(fallback));
    });

    for (final garbage in <Object?>[
      null,
      '',
      'owl',
      'preset:',
      'preset:no_such_preset',
      'initials:no_such_colour',
      'photo:owl',
      42,
      const {'preset': 'owl'},
    ]) {
      test('falls back to initials for ${garbage.runtimeType} "$garbage"', () {
        final a = Avatar.parse(garbage, seed: 'student-1');
        expect(a.isPreset, isFalse);
        expect(AppColors.avatarSwatches.containsKey(a.colorKey), isTrue);
      });
    }

    test('the fallback is stable for a seed', () {
      expect(
        Avatar.parse(null, seed: 'abc123'),
        Avatar.parse('garbage', seed: 'abc123'),
      );
    });

    test('different seeds spread across colours', () {
      final colours = {
        for (var i = 0; i < 50; i++) Avatar.fallbackColorKey('uid-$i'),
      };
      expect(colours.length, greaterThan(5));
    });

    test('every stored value matches the pattern the rules enforce', () {
      final rule = RegExp(r'^(preset|initials):[a-z_]{2,20}$');
      for (final p in AvatarPreset.all) {
        expect(rule.hasMatch(Avatar.forPreset(p).storageValue), isTrue);
      }
      for (final k in AppColors.avatarSwatches.keys) {
        expect(rule.hasMatch(Avatar.initials(k).storageValue), isTrue);
      }
    });

    test('preset ids are unique', () {
      final ids = AvatarPreset.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every preset colour exists', () {
      for (final p in AvatarPreset.all) {
        expect(AppColors.avatarSwatches.containsKey(p.colorKey), isTrue);
      }
    });
  });

  group('initialsFor', () {
    test('two words give two letters', () {
      expect(initialsFor('Chidi Okafor'), 'CO');
    });
    test('one word gives one letter', () {
      expect(initialsFor('ada'), 'A');
    });
    test('extra whitespace is ignored', () {
      expect(initialsFor('  ngozi   eze  '), 'NE');
    });
    test('a blank name uses the fallback', () {
      expect(initialsFor('  ', fallback: 'ada_l'), 'A');
    });
    test('nothing at all is a question mark', () {
      expect(initialsFor(null), '?');
    });
  });

  group('UserRepository.setBio', () {
    late FakeFirebaseFirestore db;
    late UserRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = UserRepository(db);
      await db.collection('users').doc('u1').set({'bio': 'Old bio'});
    });

    Future<Map<String, dynamic>> doc() async =>
        (await db.collection('users').doc('u1').get()).data()!;

    test('saves a trimmed bio', () async {
      await repo.setBio(uid: 'u1', bio: '  Aiming for A1  ');
      expect((await doc())['bio'], 'Aiming for A1');
    });

    test('a blank bio deletes the field', () async {
      await repo.setBio(uid: 'u1', bio: '   ');
      expect((await doc()).containsKey('bio'), isFalse);
    });

    test('an over-long bio is refused before it is written', () async {
      await expectLater(
        repo.setBio(uid: 'u1', bio: 'x' * (kBioMaxLength + 1)),
        throwsArgumentError,
      );
      expect((await doc())['bio'], 'Old bio');
    });
  });

  test('joinedLabel shows month and year only', () {
    expect(joinedLabel(DateTime(2026, 9, 26)), 'Joined September 2026');
    expect(joinedLabel(DateTime(2027, 1, 1)), 'Joined January 2027');
  });
}
