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

  group('ResourceStatus.parse — must agree with firestore.rules', () {
    // The rule: readable by students iff `status` is exactly 'published'.
    // The editor's badge must say the same thing, or it will call an
    // article published that no student can see.
    test('exactly "published" is published', () {
      expect(ResourceStatus.parse('published'), ResourceStatus.published);
    });

    test('a missing status is hidden by the rules, so it is a draft', () {
      // "Missing means published" was a rules clause once; it leaked
      // drafts through unfiltered lists and was removed. The model must
      // not quietly keep the old reading.
      expect(ResourceStatus.parse(null), ResourceStatus.draft);
      expect(
        LearnResource.fromFirestore(FakeDoc('r', {'type': 'article'})).status,
        ResourceStatus.draft,
      );
    });

    test('the review states parse exactly, and none of them is live', () {
      expect(ResourceStatus.parse('in_review'), ResourceStatus.inReview);
      expect(
        ResourceStatus.parse('changes_requested'),
        ResourceStatus.changesRequested,
      );
      expect(
        ResourceStatus.values.where((s) => s.isLive),
        [ResourceStatus.published],
      );
      // Control: near misses are drafts, never a review state.
      for (final v in ['In_review', 'in review', 'review', 'changes']) {
        expect(ResourceStatus.parse(v), ResourceStatus.draft, reason: v);
      }
    });

    test('anything else is hidden from students, so it is a draft', () {
      // Control: these are the values a looser parser would get wrong.
      for (final v in ['draft', 'Published', ' published', '', 'live', 1, true]) {
        expect(ResourceStatus.parse(v), ResourceStatus.draft, reason: 'from "$v"');
      }
    });

    test('createdBy is optional', () {
      expect(LearnResource.fromFirestore(FakeDoc('r', {})).createdBy, isNull);
      expect(
        LearnResource.fromFirestore(FakeDoc('r', {'createdBy': 'uid1'})).createdBy,
        'uid1',
      );
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
}
