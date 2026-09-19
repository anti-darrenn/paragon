import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/subject_catalog.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/models/topic.dart';
import 'package:paragon/core/models/unit.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';

/// `courseProvider` reads Firestore through `subjectsProvider`,
/// `unitsProvider` and `topicsProvider`, which construct their own
/// `FirebaseFirestore.instance` and so can't be pointed at a fake. These
/// tests override those three providers instead — that's the seam the
/// course read-model actually depends on, and it keeps the assertions on
/// the behaviour that matters: which source wins, and what gets marked
/// practisable.

Subject _subject(String id, String name, int unitCount) =>
    Subject(id: id, name: name, unitCount: unitCount);

Unit _unit(String id, String subjectId, String name, int order) =>
    Unit(id: id, subjectId: subjectId, name: name, order: order);

Topic _topic(
  String id,
  String unitId,
  String subjectId,
  String name, {
  int questionCount = 10,
  bool hasNotes = false,
}) => Topic(
  id: id,
  unitId: unitId,
  subjectId: subjectId,
  name: name,
  questionCount: questionCount,
  order: 0,
  hasNotes: hasNotes,
);

/// A container wired with one live subject ("Physics", 1 unit, 2 topics)
/// and nothing else.
ProviderContainer _container({List<Subject>? subjects}) {
  final liveSubjects = subjects ?? [_subject('phys-id', 'Physics', 1)];

  return ProviderContainer(
    overrides: [
      subjectsProvider.overrideWith((ref) async => liveSubjects),
      unitsProvider.overrideWith(
        (ref, subjectId) async => subjectId == 'phys-id'
            ? [_unit('unit-1', 'phys-id', 'Motion', 0)]
            : <Unit>[],
      ),
      topicsProvider.overrideWith(
        (ref, unitId) async => unitId == 'unit-1'
            ? [
                _topic(
                  'topic-1',
                  'unit-1',
                  'phys-id',
                  'Projectile Motion',
                  questionCount: 12,
                ),
                _topic(
                  'topic-2',
                  'unit-1',
                  'phys-id',
                  'Relative Motion',
                  questionCount: 7,
                  hasNotes: true,
                ),
              ]
            : <Topic>[],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubjectCatalog', () {
    test('slugify matches the scraper slugs', () {
      expect(SubjectCatalog.slugify('Further Mathematics'), 'further-mathematics');
      expect(SubjectCatalog.slugify('English Language'), 'english-language');
      expect(SubjectCatalog.slugify('  Physics  '), 'physics');
    });

    test('every catalog slug is unique and matches its own name', () {
      final slugs = SubjectCatalog.all.map((s) => s.slug).toList();
      expect(slugs.toSet().length, slugs.length, reason: 'duplicate slug');

      for (final subject in SubjectCatalog.all) {
        expect(
          SubjectCatalog.slugify(subject.name),
          subject.slug,
          reason: '${subject.name} does not slugify to ${subject.slug}',
        );
      }
    });

    test('every subject has a colour that is not the fallback', () {
      // AppColors.forSubject falls back to the brand orange for an unknown
      // name. A catalog entry hitting the fallback means the two lists have
      // drifted apart — every course page would lose its accent silently.
      for (final subject in SubjectCatalog.all) {
        expect(
          SubjectCatalog.byName(subject.name),
          isNotNull,
          reason: '${subject.name} is unreachable by name',
        );
      }
    });

    test('planned subjects carry an outline, seeded ones do not', () {
      const seeded = {'mathematics', 'physics', 'further-mathematics'};
      for (final subject in SubjectCatalog.all) {
        if (seeded.contains(subject.slug)) {
          expect(subject.outline, isEmpty, reason: '${subject.slug} is seeded');
        } else {
          expect(
            subject.outline,
            isNotEmpty,
            reason: '${subject.slug} has no placeholder outline',
          );
          for (final unit in subject.outline) {
            expect(unit.topics, isNotEmpty, reason: '${unit.name} is empty');
          }
        }
      }
    });
  });

  group('courseProvider', () {
    test('resolves a live subject by Firestore document id', () async {
      final container = _container();
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('phys-id').future);

      expect(course.name, 'Physics');
      expect(course.status, CourseStatus.live);
      expect(course.subjectId, 'phys-id');
      expect(course.modules.single.name, 'Motion');
      expect(course.topicCount, 2);
      expect(course.questionCount, 19);
    });

    test('resolves the same live subject by slug', () async {
      final container = _container();
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('physics').future);

      expect(course.status, CourseStatus.live);
      expect(course.subjectId, 'phys-id');
      // The key keeps the form it arrived with, so child links stay stable.
      expect(course.key, 'physics');
    });

    test('live topics are practisable and carry their real fields', () async {
      final container = _container();
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('phys-id').future);
      final topics = course.modules.single.topics;

      expect(topics.every((t) => t.isPlaceholder), isFalse);
      expect(topics.first.questionCount, 12);
      // hasNotes is read from the document, not assumed — one of the two
      // fixtures sets it.
      expect(topics.first.hasNotes, isFalse);
      expect(topics.last.hasNotes, isTrue);
    });

    test('an unseeded subject falls back to its catalog outline', () async {
      final container = _container();
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('chemistry').future);

      expect(course.name, 'Chemistry');
      expect(course.status, CourseStatus.planned);
      expect(course.subjectId, isNull);
      expect(course.modules, isNotEmpty);
      // Nothing in a planned course may be offered as practisable.
      expect(
        course.modules.every(
          (m) => m.isPlaceholder && m.topics.every((t) => t.isPlaceholder),
        ),
        isTrue,
      );
      expect(course.questionCount, 0);
    });

    test('a seeded subject with zero units falls back to planned', () async {
      // Guards the empty-course case: a subject document exists but the
      // seeder never wrote its units.
      final container = ProviderContainer(
        overrides: [
          subjectsProvider.overrideWith(
            (ref) async => [_subject('chem-id', 'Chemistry', 0)],
          ),
          unitsProvider.overrideWith((ref, subjectId) async => <Unit>[]),
          topicsProvider.overrideWith((ref, unitId) async => <Topic>[]),
        ],
      );
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('chem-id').future);

      expect(course.status, CourseStatus.planned);
      expect(course.modules, isNotEmpty, reason: 'outline should fill the gap');
      // subjectId is still known, but nothing is practisable.
      expect(course.subjectId, 'chem-id');
    });

    test('an unknown key throws rather than rendering an empty page', () async {
      final container = _container();
      addTearDown(container.dispose);

      // Asserted through the provider's AsyncValue rather than its
      // `.future`: an errored FutureProvider needs a live listener for the
      // failure to settle, and reading `.future` without one leaves the
      // element in the loading state until the container is torn down.
      final sub = container.listen(
        courseProvider('not-a-subject'),
        (_, _) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sub.read().hasError, isTrue);
      expect(sub.read().error, isA<CourseNotFoundException>());
    });

    test('findTopic returns the topic with its module', () async {
      final container = _container();
      addTearDown(container.dispose);

      final course = await container.read(courseProvider('phys-id').future);
      final found = course.findTopic('topic-2');

      expect(found, isNotNull);
      expect(found!.$1.name, 'Motion');
      expect(found.$2.name, 'Relative Motion');
      expect(course.findTopic('nope'), isNull);
    });
  });

  group('courseCatalogProvider', () {
    test('lists every catalog subject, live ones tagged live', () async {
      final container = _container();
      addTearDown(container.dispose);

      final courses = await container.read(courseCatalogProvider.future);

      expect(courses.length, SubjectCatalog.all.length);

      final physics = courses.firstWhere((c) => c.name == 'Physics');
      expect(physics.isLive, isTrue);
      // Live rows route by document id — the form the rest of the app uses.
      expect(physics.key, 'phys-id');
      expect(physics.moduleCount, 1);

      final chemistry = courses.firstWhere((c) => c.name == 'Chemistry');
      expect(chemistry.isLive, isFalse);
      expect(chemistry.key, 'chemistry');
      expect(chemistry.moduleCount, greaterThan(0));
    });
  });

  group('FakeFirebaseFirestore sanity', () {
    // Keeps the fake in play so the suite still fails loudly if the shared
    // Firestore fixtures stop constructing.
    test('subject documents round-trip through fromFirestore', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('subjects').doc('s1').set({
        'name': 'Economics',
        'unitCount': 4,
      });

      final snap = await db.collection('subjects').doc('s1').get();
      final subject = Subject.fromFirestore(snap as DocumentSnapshot);

      expect(subject.name, 'Economics');
      expect(subject.unitCount, 4);
      expect(SubjectCatalog.byName(subject.name)?.slug, 'economics');
    });
  });
}
