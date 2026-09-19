import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/onboarding/onboarding_step.dart';
import 'package:paragon/core/repositories/user_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsernameRules.normalise', () {
    test('lower-cases only', () {
      expect(UsernameRules.normalise('BrightKofi'), 'brightkofi');
      expect(UsernameRules.normalise('brightkofi'), 'brightkofi');
    });

    test('casing variants collide on one key', () {
      final keys = {
        UsernameRules.normalise('adalovelace'),
        UsernameRules.normalise('AdaLovelace'),
        UsernameRules.normalise('ADALOVELACE'),
      };
      expect(keys.length, 1);
    });

    test('is exactly what firestore.rules can recompute', () {
      // The rule verifies `after.username.lower() == after.usernameKey`.
      // If normalise ever does more than trim + lower-case, the server
      // can no longer check a claim and uniqueness silently degrades to
      // a client-side promise. This test is that contract.
      for (final raw in ['Chidi_99', 'adalovelace', 'ZZZZ', 'a_b_c_d']) {
        expect(UsernameRules.normalise(raw), raw.trim().toLowerCase());
      }
    });

    test('trims surrounding whitespace', () {
      expect(UsernameRules.normalise('  chidi_99  '), 'chidi_99');
    });
  });

  group('UsernameRules.validate', () {
    test('accepts a normal handle', () {
      expect(UsernameRules.validate('chidi_99'), isNull);
      expect(UsernameRules.validate('adalovelace'), isNull);
      expect(UsernameRules.validate('ABCD'), isNull);
    });

    test('rejects empty or whitespace', () {
      expect(UsernameRules.validate(''), isNotNull);
      expect(UsernameRules.validate('   '), isNotNull);
    });

    test('rejects disallowed characters, periods included', () {
      expect(UsernameRules.validate('ada lovelace'), isNotNull);
      expect(UsernameRules.validate('ada-lovelace'), isNotNull);
      expect(UsernameRules.validate('ada@lovelace'), isNotNull);
      expect(UsernameRules.validate('adé'), isNotNull);
      // Periods are gone: they would make normalisation unverifiable in
      // firestore.rules. See UsernameRules._allowed.
      expect(UsernameRules.validate('ada.lovelace'), isNotNull);
    });

    test('enforces the length bounds', () {
      expect(UsernameRules.validate('abc'), isNotNull);
      expect(UsernameRules.validate('abcd'), isNull);
    });

    test('every accepted handle satisfies the server regex', () {
      // firestore.rules gates the reservation id on ^[a-z0-9_]{4,20}$.
      // Anything validate() accepts must also pass that, or the client
      // offers names the server will refuse.
      final serverPattern = RegExp(r'^[a-z0-9_]{4,20}$');
      for (final raw in ['chidi_99', 'ABCD', 'Ada_Lovelace']) {
        expect(UsernameRules.validate(raw), isNull, reason: raw);
        expect(
          serverPattern.hasMatch(UsernameRules.normalise(raw)),
          isTrue,
          reason: raw,
        );
      }
    });

    test('enforces the maximum length', () {
      expect(UsernameRules.validate('a' * 20), isNull);
      expect(UsernameRules.validate('a' * 21), isNotNull);
    });
  });

  group('resolveOnboardingStep', () {
    Map<String, dynamic> doc({
      String? username,
      String? displayName,
      List<String>? subjects,
    }) {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (displayName != null) data['displayName'] = displayName;
      if (subjects != null) data['selectedSubjects'] = subjects;
      return data;
    }

    test('a null document resolves to the first step, never complete', () {
      // A missing doc must not wave anyone past the funnel.
      expect(resolveOnboardingStep(null), OnboardingStep.username);
    });

    test('an empty document starts at username', () {
      expect(resolveOnboardingStep({}), OnboardingStep.username);
    });

    test('blank strings count as missing', () {
      expect(
        resolveOnboardingStep(doc(username: '   ')),
        OnboardingStep.username,
      );
      expect(
        resolveOnboardingStep(doc(username: 'ada', displayName: '')),
        OnboardingStep.displayName,
      );
    });

    test('an email sign-up with no name stops at display name', () {
      // UserRepository.createUserIfNew writes displayName: '' when Firebase
      // Auth has none — exactly the case that used to greet people as
      // "Hey,  👋" on the dashboard.
      expect(
        resolveOnboardingStep(doc(username: 'ada', displayName: '')),
        OnboardingStep.displayName,
      );
    });

    test('an empty subject list counts as missing', () {
      expect(
        resolveOnboardingStep(
          doc(username: 'ada', displayName: 'Ada', subjects: []),
        ),
        OnboardingStep.subjects,
      );
    });

    test('all three gating fields present resolves to complete', () {
      expect(
        resolveOnboardingStep(
          doc(username: 'ada', displayName: 'Ada', subjects: ['maths']),
        ),
        OnboardingStep.complete,
      );
    });

    test('the optional profile step never gates completion', () {
      // No profile map at all, yet the user is complete — the optional
      // step is reachable only by walking forward, never by redirect.
      final complete = doc(
        username: 'ada',
        displayName: 'Ada',
        subjects: ['maths'],
      );
      expect(complete.containsKey('profile'), isFalse);
      expect(resolveOnboardingStep(complete), OnboardingStep.complete);
    });

    test('wrong types are treated as missing, not crashes', () {
      expect(
        resolveOnboardingStep({'username': 42}),
        OnboardingStep.username,
      );
      expect(
        resolveOnboardingStep({
          'username': 'ada',
          'displayName': 'Ada',
          'selectedSubjects': 'maths',
        }),
        OnboardingStep.subjects,
      );
    });
  });

  group('OnboardingStep', () {
    test('next walks the funnel in order and terminates', () {
      expect(OnboardingStep.username.next, OnboardingStep.displayName);
      expect(OnboardingStep.displayName.next, OnboardingStep.subjects);
      expect(OnboardingStep.subjects.next, OnboardingStep.profile);
      expect(OnboardingStep.profile.next, OnboardingStep.complete);
      expect(OnboardingStep.complete.next, OnboardingStep.complete);
    });

    test('step numbers cover 1..4 and complete has none', () {
      expect(OnboardingStep.username.stepNumber, 1);
      expect(OnboardingStep.displayName.stepNumber, 2);
      expect(OnboardingStep.subjects.stepNumber, 3);
      expect(OnboardingStep.profile.stepNumber, 4);
      expect(OnboardingStep.complete.stepNumber, isNull);
    });

    test('isOnboardingPath matches every funnel route and nothing else', () {
      for (final step in OnboardingStep.values) {
        if (step == OnboardingStep.complete) continue;
        expect(
          OnboardingStep.isOnboardingPath(step.path),
          isTrue,
          reason: '${step.name} (${step.path})',
        );
      }
      expect(OnboardingStep.isOnboardingPath('/'), isFalse);
      expect(OnboardingStep.isOnboardingPath('/courses'), isFalse);
      expect(OnboardingStep.isOnboardingPath('/welcome'), isFalse);
      expect(OnboardingStep.isOnboardingPath('/subjects'), isFalse);
    });
  });

  group('UserRepository.reserveUsername', () {
    late FakeFirebaseFirestore db;
    late UserRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = UserRepository(db);
      await db.collection('users').doc('u1').set({'uid': 'u1'});
      await db.collection('users').doc('u2').set({'uid': 'u2'});
    });

    test('reserves a free handle and writes it to the user doc', () async {
      final ok = await repo.reserveUsername(
        uid: 'u1',
        raw: 'AdaLovelace',
        key: 'adalovelace',
      );

      expect(ok, isTrue);

      final reservation =
          await db.collection('usernames').doc('adalovelace').get();
      expect(reservation.data()?['uid'], 'u1');
      // The chosen spelling is preserved, not the normalised key.
      expect(reservation.data()?['raw'], 'AdaLovelace');

      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?['username'], 'AdaLovelace');
      expect(user.data()?['usernameKey'], 'adalovelace');
    });

    test('refuses a handle owned by someone else', () async {
      await repo.reserveUsername(uid: 'u1', raw: 'ada', key: 'ada');

      final ok = await repo.reserveUsername(uid: 'u2', raw: 'ada', key: 'ada');

      expect(ok, isFalse);
      // u2 must not have been given the name on their own document.
      final u2 = await db.collection('users').doc('u2').get();
      expect(u2.data()?['username'], isNull);
      // ...and u1 still owns the reservation.
      final reservation = await db.collection('usernames').doc('ada').get();
      expect(reservation.data()?['uid'], 'u1');
    });

    test('a casing variant cannot steal an existing handle', () async {
      await repo.reserveUsername(
        uid: 'u1',
        raw: 'adalovelace',
        key: 'adalovelace',
      );

      final ok = await repo.reserveUsername(
        uid: 'u2',
        raw: 'AdaLovelace',
        key: UsernameRules.normalise('AdaLovelace'),
      );

      expect(ok, isFalse);
    });

    test('a stored reservation always normalises to its own key', () async {
      // firestore.rules rejects a reservation whose id is not
      // raw.lower(), so the repository must never construct one.
      await repo.reserveUsername(
        uid: 'u1',
        raw: '  Chidi_99  ',
        key: UsernameRules.normalise('  Chidi_99  '),
      );

      final snap = await db.collection('usernames').doc('chidi_99').get();
      final raw = snap.data()?['raw'] as String;
      expect(raw, 'Chidi_99', reason: 'trimmed but not case-folded');
      expect(raw.toLowerCase(), 'chidi_99', reason: 'must equal the doc id');
    });

    test('finishes a half-done reservation the user already owns', () async {
      // Simulates an earlier attempt that created the reservation and then
      // failed before updating the user document.
      await db.collection('usernames').doc('ada').set({
        'uid': 'u1',
        'raw': 'ada',
      });

      final ok = await repo.reserveUsername(uid: 'u1', raw: 'ada', key: 'ada');

      expect(ok, isTrue, reason: 'own reservation is not a collision');
      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?['username'], 'ada');
    });

    test('is idempotent when run twice', () async {
      await repo.reserveUsername(uid: 'u1', raw: 'ada', key: 'ada');
      final ok = await repo.reserveUsername(uid: 'u1', raw: 'ada', key: 'ada');

      expect(ok, isTrue);
      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?['username'], 'ada');
    });
  });

  group('UserRepository onboarding field writes', () {
    late FakeFirebaseFirestore db;
    late UserRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = UserRepository(db);
      await db.collection('users').doc('u1').set({'uid': 'u1'});
    });

    test('setDisplayName trims', () async {
      await repo.setDisplayName(uid: 'u1', displayName: '  Ada  ');
      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?['displayName'], 'Ada');
    });

    test('setSelectedSubjects stores the list', () async {
      await repo.setSelectedSubjects(
        uid: 'u1',
        subjectKeys: ['mathematics', 'physics'],
      );
      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?['selectedSubjects'], ['mathematics', 'physics']);
    });

    test('setProfile saves only the fields actually supplied', () async {
      // Skipping with two fields filled saves those two — a partial save,
      // not a wipe of the rest.
      await repo.setProfile(
        uid: 'u1',
        profile: {
          'school': 'Kings College',
          'classYear': 'SS2',
          'age': null,
          'gender': '',
          'country': null,
        },
      );

      final user = await db.collection('users').doc('u1').get();
      final profile = user.data()?['profile'] as Map<String, dynamic>?;
      expect(profile?['school'], 'Kings College');
      expect(profile?['classYear'], 'SS2');
      expect(profile?.containsKey('age'), isFalse);
      expect(profile?.containsKey('gender'), isFalse);
      expect(profile?.containsKey('country'), isFalse);
    });

    test('setProfile with nothing supplied writes nothing', () async {
      await repo.setProfile(
        uid: 'u1',
        profile: {'school': '', 'age': null},
      );
      final user = await db.collection('users').doc('u1').get();
      expect(user.data()?.containsKey('profile'), isFalse);
    });

    test('a later setProfile merges rather than replacing', () async {
      await repo.setProfile(uid: 'u1', profile: {'school': 'Kings College'});
      await repo.setProfile(uid: 'u1', profile: {'country': 'Nigeria'});

      final user = await db.collection('users').doc('u1').get();
      final profile = user.data()?['profile'] as Map<String, dynamic>?;
      expect(profile?['school'], 'Kings College');
      expect(profile?['country'], 'Nigeria');
    });
  });
}
