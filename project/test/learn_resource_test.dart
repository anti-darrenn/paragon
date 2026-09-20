// The Learn resource model, and the rules that decide what a student sees.
//
// Two things here are worth more than the coverage:
//
//   - `isAvailable` is the whole placeholder story. Almost no topic has a
//     video, so "grayed out, still listed" is the normal path, not an edge
//     case, and it is derived from the data rather than from a flag an
//     author has to remember to set.
//   - an unrecognised `type` must survive. A student on an older build
//     will one day be handed a resource type that build has never heard
//     of, and the answer has to be a shorter list, not a crash.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/firestore_parsing.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/learn_repository.dart';

// ignore: subtype_of_sealed_class
/// Same minimal fake as `model_null_safety_test.dart` — only `id` and
/// `data()` are exercised, and faking the real entry point is what keeps
/// the `docData(doc)` null-payload path under test.
class FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDoc(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LearnResourceType.parse', () {
    test('recognises the three real types, case and space insensitively', () {
      expect(LearnResourceType.parse('video'), LearnResourceType.video);
      expect(LearnResourceType.parse('  Article '), LearnResourceType.article);
      expect(LearnResourceType.parse('EXERCISE'), LearnResourceType.exercise);
    });

    test('anything else is unknown, never a throw', () {
      for (final v in [null, '', 'quiz', 42, <String>[], {'a': 1}]) {
        expect(LearnResourceType.parse(v), LearnResourceType.unknown,
            reason: 'from $v');
      }
    });
  });

  group('LearnResource.fromFirestore never throws', () {
    final malformed = <String, Map<String, dynamic>?>{
      'null payload (deleted doc)': null,
      'empty map': <String, dynamic>{},
      'all fields null': {
        'type': null, 'order': null, 'title': null, 'subjectId': null,
        'topicId': null, 'origin': null, 'youtubeId': null, 'body': null,
        'durationSeconds': null, 'description': null, 'transcript': null,
        'questionCount': null,
      },
      'numbers written as strings': {
        'type': 'exercise', 'order': '2', 'questionCount': '8',
        'durationSeconds': '360',
      },
      'wrong types throughout': {
        'type': 99, 'order': 'first', 'title': <String>[], 'subjectId': true,
        'topicId': 3.5, 'youtubeId': {'v': 1}, 'body': 7,
        'questionCount': <String, dynamic>{},
      },
    };

    malformed.forEach((label, data) {
      test(label, () {
        expect(
          () => LearnResource.fromFirestore(FakeDoc('r1', data)),
          returnsNormally,
          reason: label,
        );
      });
    });

    test('a missing document yields empty values and keeps its id', () {
      final r = LearnResource.fromFirestore(FakeDoc('res-7', null));
      expect(r.id, 'res-7');
      expect(r.title, '');
      expect(r.order, 0);
      expect(r.type, LearnResourceType.unknown);
      expect(r.youtubeId, isNull);
      expect(r.body, '');
    });

    test('origin defaults to authored, not empty', () {
      expect(LearnResource.fromFirestore(FakeDoc('r', {})).origin, 'authored');
    });
  });

  group('asStringOrNull collapses blank to absent', () {
    test('empty and whitespace-only become null', () {
      // The distinction the placeholder rule depends on: a youtubeId
      // seeded as '' must behave exactly like one that was never written.
      for (final v in [null, '', '   ', '\n\t']) {
        expect(asStringOrNull(v), isNull, reason: 'from "$v"');
      }
    });

    test('a real value survives, untrimmed', () {
      expect(asStringOrNull(' dQw4w9WgXcQ '), ' dQw4w9WgXcQ ');
      expect(asStringOrNull(42), '42');
    });
  });

  group('isAvailable — what renders as a live row vs a placeholder', () {
    LearnResource res(Map<String, dynamic> data) =>
        LearnResource.fromFirestore(FakeDoc('r', data));

    test('a video with no youtubeId is a placeholder, not hidden', () {
      final r = res({'type': 'video', 'title': 'Intro'});
      expect(r.type, LearnResourceType.video);
      expect(r.isAvailable, isFalse);
      // Still a fully-formed resource: the list renders it disabled.
      expect(r.title, 'Intro');
    });

    test('a video whose youtubeId is blank is also a placeholder', () {
      expect(res({'type': 'video', 'youtubeId': '   '}).isAvailable, isFalse);
    });

    test('a video with a youtubeId is available', () {
      expect(
        res({'type': 'video', 'youtubeId': 'dQw4w9WgXcQ'}).isAvailable,
        isTrue,
      );
    });

    test('an article is available only once it has a body', () {
      expect(res({'type': 'article'}).isAvailable, isFalse);
      expect(res({'type': 'article', 'body': '   '}).isAvailable, isFalse);
      expect(res({'type': 'article', 'body': 'Some prose.'}).isAvailable, isTrue);
    });

    test('an exercise is always available — its questions come from the '
        'topic bank, not from the resource', () {
      expect(res({'type': 'exercise'}).isAvailable, isTrue);
    });

    test('an unknown type is never available', () {
      expect(res({'type': 'podcast', 'body': 'x'}).isAvailable, isFalse);
    });
  });

  group('topic test scoring', () {
    test('80% exactly passes', () {
      expect(passesTopicTest(correct: 8, total: 10), isTrue);
      expect(passesTopicTest(correct: 4, total: 5), isTrue);
    });

    test('just under 80% fails', () {
      expect(passesTopicTest(correct: 7, total: 10), isFalse);
      expect(passesTopicTest(correct: 3, total: 4), isFalse);
    });

    test('a perfect score passes', () {
      expect(passesTopicTest(correct: 10, total: 10), isTrue);
    });

    test('an empty test cannot be passed', () {
      // Otherwise a topic with no answerable questions would unlock drill
      // for free — 0/0 is not 100%.
      expect(passesTopicTest(correct: 0, total: 0), isFalse);
    });

    test('the threshold constants are what the product says they are', () {
      expect(kTopicTestPassRatio, 0.8);
      expect(kTopicTestQuestions, 10);
    });
  });
}
