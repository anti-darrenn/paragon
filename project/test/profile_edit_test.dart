import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/user_repository.dart';
import 'package:paragon/features/onboarding/profile_form.dart';

/// The settings profile editor, and the difference between the two ways of
/// writing a profile.
///
/// `setProfile` serves onboarding, where a blank box means "not answered
/// yet" and must not wipe a sibling field. `updateProfile` serves the
/// editor, where a cleared box is a student asking for that value to be
/// deleted. Getting these the wrong way round is silent in both
/// directions, which is why both are pinned here.
void main() {
  late FakeFirebaseFirestore db;
  late UserRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = UserRepository(db);
  });

  Future<Map<String, dynamic>?> profileOf(String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    return snap.data()?['profile'] as Map<String, dynamic>?;
  }

  group('UserRepository.updateProfile', () {
    setUp(() async {
      await db.collection('users').doc('u1').set({
        'uid': 'u1',
        'displayName': 'Ada',
        'profile': {'school': 'Kings College', 'age': 16, 'gender': 'Female'},
      });
    });

    test('clearing a field deletes it', () async {
      await repo.updateProfile(
        uid: 'u1',
        profile: {'school': 'Kings College', 'age': null, 'gender': 'Female'},
      );

      final profile = await profileOf('u1');
      expect(profile!.containsKey('age'), isFalse);
      expect(profile['school'], 'Kings College');
      expect(profile['gender'], 'Female');
    });

    test('an empty string clears too', () async {
      await repo.updateProfile(uid: 'u1', profile: {'school': ''});
      expect((await profileOf('u1'))!.containsKey('school'), isFalse);
    });

    test('leaves fields it was not given alone', () async {
      await repo.updateProfile(uid: 'u1', profile: {'age': 17});
      final profile = await profileOf('u1');
      expect(profile!['age'], 17);
      expect(profile['school'], 'Kings College');
    });

    test('does not disturb the rest of the user document', () async {
      await repo.updateProfile(uid: 'u1', profile: {'age': null});
      final snap = await db.collection('users').doc('u1').get();
      expect(snap.data()!['displayName'], 'Ada');
    });
  });

  group('UserRepository.setProfile', () {
    test('is the opposite, and must stay that way', () async {
      await db.collection('users').doc('u2').set({
        'profile': {'school': 'Kings College', 'age': 16},
      });

      // The control this file exists for: onboarding's writer must ignore
      // a blank rather than treat it as a deletion, or skipping the step
      // with one box filled would erase the others.
      await repo.setProfile(uid: 'u2', profile: {'school': '', 'age': null});

      final profile = await profileOf('u2');
      expect(profile!['school'], 'Kings College');
      expect(profile['age'], 16);
    });
  });

  group('ProfileFormController', () {
    test('round-trips a stored profile', () {
      final form = ProfileFormController();
      addTearDown(form.dispose);

      form.hydrate({
        'school': 'Kings College',
        'age': 16,
        'classYear': 'SS2',
        'gender': 'Female',
        'country': 'Nigeria',
        'state': 'Lagos',
      });

      expect(form.toProfile(), {
        'school': 'Kings College',
        'classYear': 'SS2',
        'age': 16,
        'gender': 'Female',
        'country': 'Nigeria',
        'state': 'Lagos',
      });
    });

    test('drops a stored value that is no longer an option', () {
      final form = ProfileFormController();
      addTearDown(form.dispose);

      // DropdownButtonFormField throws on a value absent from its items,
      // so a state list that has since changed must not reach it.
      form.hydrate({'state': 'Atlantis', 'gender': 'Female'});
      expect(form.state, isNull);
      expect(form.gender, 'Female');
    });

    test('a missing or malformed profile leaves the form empty', () {
      final form = ProfileFormController();
      addTearDown(form.dispose);

      form.hydrate(null);
      expect(form.isEmpty, isTrue);
      form.hydrate('not a map');
      expect(form.isEmpty, isTrue);
    });

    test('a cleared box reads as null, not as absent', () {
      // This is what makes deletion possible: the editor has to be able to
      // tell "emptied" from "never set", and both look like a blank box.
      final form = ProfileFormController();
      addTearDown(form.dispose);

      form.hydrate({'school': 'Kings College'});
      form.school.text = '';
      expect(form.toProfile()['school'], isNull);
      expect(form.toProfile().containsKey('school'), isTrue);
    });
  });
}
