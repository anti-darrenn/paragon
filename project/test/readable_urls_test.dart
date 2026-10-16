import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/widgets/nav/back_navigation.dart';

/// Audit C9 (2026-10-15): subjects had readable URLs, but topics, drills,
/// tests and exams used Firestore ids, and "Start practising" switched the
/// address from a slug to an id.
void main() {
  CourseTopic topic(String id, String name) => CourseTopic(
    id: id,
    name: name,
    questionCount: 10,
    hasNotes: false,
    isPlaceholder: false,
  );

  final course = Course(
    key: 'gdv7zeXkoASauMlcmMnV',
    slug: 'mathematics',
    name: 'Mathematics',
    blurb: '',
    subjectId: 'gdv7zeXkoASauMlcmMnV',
    status: CourseStatus.live,
    modules: [
      CourseModule(
        id: 'unit1',
        name: 'Number and Numeration',
        isPlaceholder: false,
        topics: [
          topic('sGeqO2FDw79otnkz3tz6', 'Indices'),
          topic('t2', 'Fractions/Decimals/Approximations'),
        ],
      ),
    ],
  );

  test('a topic is found by its slug or its id', () {
    expect(course.findTopic('indices')!.$2.id, 'sGeqO2FDw79otnkz3tz6');
    expect(course.findTopic('sGeqO2FDw79otnkz3tz6')!.$2.name, 'Indices');
    expect(course.findTopic('fractions-decimals-approximations')!.$2.id, 't2');
    expect(course.findTopic('no-such-topic'), isNull);
  });

  test('links are readable all the way to drill and the test', () {
    final indices = course.findTopic('indices')!.$2;
    expect(
      course.topicPath(indices),
      '/subject/mathematics/course/topic/indices',
    );
    expect(course.drillPath(indices), endsWith('/topic/indices/drill'));
    expect(course.testPath(indices), endsWith('/topic/indices/test'));
    expect(
      course.pathForTopicId('sGeqO2FDw79otnkz3tz6'),
      '/subject/mathematics/course/topic/indices',
    );
  });

  test('drill and the test go back to their topic page', () {
    for (final s in ['drill', 'test']) {
      expect(
        parentPathFor(
          Uri.parse('/subject/mathematics/course/topic/indices/$s'),
        ),
        '/subject/mathematics/course/topic/indices',
      );
    }
  });

  test('control: an id that looks like nothing still resolves first', () {
    // An id is preferred over a slug, so an old link cannot land elsewhere.
    final tricky = Course(
      key: 'k',
      slug: 'physics',
      name: 'Physics',
      blurb: '',
      subjectId: 'k',
      status: CourseStatus.live,
      modules: [
        CourseModule(
          id: 'u',
          name: 'U',
          isPlaceholder: false,
          topics: [topic('waves', 'Light'), topic('x2', 'Waves')],
        ),
      ],
    );
    expect(tricky.findTopic('waves')!.$2.name, 'Light');
  });
}
