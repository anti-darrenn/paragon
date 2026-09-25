import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/lesson_progress.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/learn_resource.dart';

LearnResource res(
  String id, {
  LearnResourceType type = LearnResourceType.article,
  String body = 'text',
  String? youtubeId,
}) => LearnResource(
  id: id,
  type: type,
  order: 0,
  title: id,
  subjectId: 's',
  topicId: 't',
  body: body,
  youtubeId: youtubeId,
);

void main() {
  group('parsing learn/{uid}', () {
    test('reads completed ids and the last-completed marker', () {
      final p = LessonProgress.fromDocument({
        'topics': {
          't1': {
            'completed': {'a': true, 'b': true, 'c': false},
            'subjectId': 's1',
            'lastCompletedId': 'b',
            'lastCompletedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
          },
        },
      });
      expect(p.forTopic('t1').completed, {'a', 'b'});
      expect(p.forTopic('t1').lastCompletedId, 'b');
      expect(p.isComplete('t1', 'a'), isTrue);
      expect(p.isComplete('t1', 'c'), isFalse);
    });

    test('malformed data never throws and reads as nothing done', () {
      for (final data in <Map<String, dynamic>?>[
        null,
        {},
        {'topics': 'nope'},
        {'topics': {'t': 5}},
        {'topics': {'t': {'completed': 'x', 'lastCompletedAt': 'yesterday'}}},
      ]) {
        final p = LessonProgress.fromDocument(data);
        expect(p.forTopic('t').completed, isEmpty, reason: '$data');
      }
    });

    test('a test-only entry has no completions', () {
      final p = LessonProgress.fromDocument({
        'topics': {'t': {'passed': true, 'bestScore': 90, 'attempts': 1}},
      });
      expect(p.forTopic('t').completed, isEmpty);
    });

    test('a completion-only entry reads as "no test taken" to the gate', () {
      // The two models share `learn/{uid}.topics.<id>`; completing a
      // lesson must not look like a test attempt, or a pass.
      final record = TopicTestProgress.fromDocument({
        'topics': {'t': {'completed': {'a': true}, 'subjectId': 's'}},
      }).forTopic('t');
      expect(record.passed, isFalse);
      expect(record.attempts, 0);
    });
  });

  group('walking the sequence', () {
    final list = [
      res('v', type: LearnResourceType.video), // no youtubeId: unavailable
      res('a1'),
      res('ex', type: LearnResourceType.exercise, body: ''),
      res('a2', body: ''), // no body: unavailable
      res('a3'),
    ];

    test('continue skips unavailable and completed items', () {
      expect(continueTarget(list, {})?.id, 'a1');
      expect(continueTarget(list, {'a1'})?.id, 'ex');
      expect(continueTarget(list, {'a1', 'ex'})?.id, 'a3');
      expect(continueTarget(list, {'a1', 'ex', 'a3'}), isNull);
    });

    test('next skips unavailable items and ends with null', () {
      expect(nextAfter(list, 'ex')?.id, 'a3');
      expect(nextAfter(list, 'a3'), isNull);
      expect(nextAfter(list, 'missing'), isNull);
    });

    test('counts only available items, capped by what exists', () {
      expect(availableCount(list), 3);
      expect(completedCount(list, {'a1', 'gone', 'a2'}), 1);
    });
  });

  test('most recent picks the latest completion across topics', () {
    final p = LessonProgress.fromDocument({
      'topics': {
        'old': {'lastCompletedAt': Timestamp.fromDate(DateTime(2026, 1, 1))},
        'new': {'lastCompletedAt': Timestamp.fromDate(DateTime(2026, 9, 1))},
        'none': {'completed': {'x': true}},
      },
    });
    expect(p.mostRecent?.topicId, 'new');
    expect(LessonProgress.empty.mostRecent, isNull);
  });

  test('guest in-memory completion adds without touching other topics', () {
    final p = LessonProgress.empty
        .withCompleted('t', 'a')
        .withCompleted('t', 'b')
        .withCompleted('u', 'z');
    expect(p.forTopic('t').completed, {'a', 'b'});
    expect(p.forTopic('u').completed, {'z'});
    expect(p.mostRecent, isNotNull);
  });
}
