// Every fromFirestore must survive a malformed document.
//
// The rule is in CLAUDE.md, and the reason is the failure mode: these run
// inside provider mapping, so a throw takes down the whole screen instead of
// leaving one gap. Documents are written by several seeders, edited by hand
// in the Firebase Console, and a seeding run can stop mid-way when the
// free-tier quota runs out — so malformed input is a realistic event, not a
// hypothetical one.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/firestore_parsing.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/models/topic.dart';
import 'package:paragon/core/models/unit.dart';

// ignore: subtype_of_sealed_class
/// Minimal DocumentSnapshot: only `id` and `data()` are exercised by the
/// models, and noSuchMethod absorbs the rest of the interface.
///
/// The type is sealed, hence the ignore. The alternative — giving each model a
/// `fromMap(id, data)` and testing that instead — would leave the
/// `docData(doc)` path untested, and the null payload it guards (a snapshot
/// for a document that does not exist) is exactly the case most likely to
/// crash a screen. Better to fake the real entry point than to test around it.
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

/// The shapes a document realistically arrives in when something has gone
/// wrong: nothing at all, explicit nulls, and values of the wrong type
/// (hand-edits in the Console save numbers as strings very easily).
final malformed = <String, Map<String, dynamic>?>{
  'null payload (deleted doc)': null,
  'empty map': <String, dynamic>{},
  'all fields null': {
    'name': null, 'unitCount': null, 'subjectId': null, 'unitId': null,
    'topicId': null, 'text': null, 'options': null, 'correctIndex': null,
    'order': null, 'questionCount': null, 'hasNotes': null, 'year': null,
    'explanation': null, 'source': null, 'notesMarkdown': null,
  },
  'numbers written as strings': {
    'unitCount': '10', 'order': '3', 'questionCount': '300',
    'correctIndex': '2', 'year': '2019',
  },
  'wrong types throughout': {
    'name': 42, 'unitCount': 'not a number', 'subjectId': true,
    'unitId': 3.5, 'topicId': [], 'text': {'a': 1},
    'options': 'not a list', 'correctIndex': 'abc', 'order': null,
    'questionCount': <String, dynamic>{}, 'hasNotes': 'true', 'year': 'xyz',
  },
  'options holding non-strings': {
    'text': 'Q', 'options': [1, null, 'three', 4.5], 'correctIndex': 1,
  },
};

void main() {
  // Control: proves the suite above is not vacuous. These are the exact casts
  // the models used before, and they throw on the very documents the tests
  // feed in. If someone "simplifies" the coercion helpers back to direct
  // casts, the group below starts failing rather than quietly passing.
  group('control - the old direct casts really do throw', () {
    test('a null field cast to String throws', () {
      final d = <String, dynamic>{'name': null};
      expect(() => d['name'] as String, throwsA(isA<TypeError>()));
    });

    test('a null field cast to num throws', () {
      final d = <String, dynamic>{'unitCount': null};
      expect(() => (d['unitCount'] as num).toInt(), throwsA(isA<TypeError>()));
    });

    test('List<String>.from throws on non-string entries', () {
      final d = <String, dynamic>{'options': [1, 2, 3]};
      expect(() => List<String>.from(d['options'] as List), throwsA(isA<TypeError>()));
    });

    test('a null payload cast to Map throws', () {
      final Map<String, dynamic>? data = null;
      expect(() => data as Map<String, dynamic>, throwsA(isA<TypeError>()));
    });
  });

  group('models never throw on a malformed document', () {
    malformed.forEach((label, data) {
      test(label, () {
        final doc = FakeDoc('doc-id', data);
        expect(() => Subject.fromFirestore(doc), returnsNormally, reason: label);
        expect(() => Unit.fromFirestore(doc), returnsNormally, reason: label);
        expect(() => Topic.fromFirestore(doc), returnsNormally, reason: label);
        expect(() => Question.fromFirestore(doc), returnsNormally, reason: label);
      });
    });
  });

  group('fallbacks are sane', () {
    test('a missing document yields empty values, not nulls or crashes', () {
      final doc = FakeDoc('abc', null);
      expect(Subject.fromFirestore(doc).name, '');
      expect(Subject.fromFirestore(doc).unitCount, 0);
      expect(Topic.fromFirestore(doc).questionCount, 0);
      expect(Question.fromFirestore(doc).options, isEmpty);
      // id always survives - it comes from the snapshot, not the payload
      expect(Question.fromFirestore(doc).id, 'abc');
    });

    test('correctIndex falls back to -1, never 0', () {
      // 0 would silently mark option A correct on a broken document; -1 is
      // what the app already treats as "no verified answer".
      for (final v in [null, 'abc', <String>[], {}]) {
        final q = Question.fromFirestore(FakeDoc('q', {'correctIndex': v}));
        expect(q.correctIndex, -1, reason: 'correctIndex from $v');
      }
    });

    test('subject questionCount reads 0 ("not known") when missing or bad', () {
      // The welcome screen hides the count at 0 rather than showing it.
      for (final v in [null, 'abc', <String>[], {}]) {
        final s = Subject.fromFirestore(FakeDoc('s', {'questionCount': v}));
        expect(s.questionCount, 0, reason: 'questionCount from $v');
      }
      final real = Subject.fromFirestore(FakeDoc('s', {'questionCount': 14602}));
      expect(real.questionCount, 14602);
    });

    test('source defaults to drill, not empty', () {
      expect(Question.fromFirestore(FakeDoc('q', {})).source, 'drill');
    });

    test('option positions are preserved when entries are not strings', () {
      // correctIndex indexes into this list, so dropping a bad entry would
      // shift the right answer onto the wrong option.
      final q = Question.fromFirestore(
        FakeDoc('q', {'options': [1, null, 'three', 4.5], 'correctIndex': 2}),
      );
      expect(q.options.length, 4);
      expect(q.options[2], 'three');
      expect(q.options[q.correctIndex], 'three');
    });

    test('numeric strings are read as numbers', () {
      final t = Topic.fromFirestore(
        FakeDoc('t', {'questionCount': '300', 'order': '2'}),
      );
      expect(t.questionCount, 300);
      expect(t.order, 2);
      expect(Question.fromFirestore(FakeDoc('q', {'year': '2019'})).year, 2019);
    });

    test('year stays null when absent, rather than becoming 0', () {
      // year is nullable by design - drill questions have none, and 0 would
      // read as a real year in the WAEC year-range queries.
      expect(Question.fromFirestore(FakeDoc('q', {})).year, isNull);
    });
  });

  group('coercion helpers', () {
    test('asInt accepts num, numeric string, and falls back otherwise', () {
      expect(asInt(5), 5);
      expect(asInt(5.9), 5);
      expect(asInt('7'), 7);
      expect(asInt(' 8 '), 8);
      expect(asInt(null), 0);
      expect(asInt('nope', fallback: -1), -1);
    });

    test('asBool handles the string and numeric spellings', () {
      expect(asBool(true), isTrue);
      expect(asBool('true'), isTrue);
      expect(asBool('TRUE'), isTrue);
      expect(asBool('false'), isFalse);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool(null), isFalse);
      expect(asBool('banana', fallback: true), isTrue);
    });

    test('asStringList returns empty for non-iterables', () {
      expect(asStringList(null), isEmpty);
      expect(asStringList('abc'), isEmpty);
      expect(asStringList(42), isEmpty);
      expect(asStringList(['a', 'b']), ['a', 'b']);
    });

    test('docData tolerates a null or non-map payload', () {
      expect(docData(FakeDoc('x', null)), isEmpty);
      expect(docData(FakeDoc('x', {'a': 1})), {'a': 1});
    });
  });

  test('a well-formed document still parses exactly as before', () {
    final q = Question.fromFirestore(FakeDoc('qid', {
      'topicId': 't1',
      'subjectId': 's1',
      'text': r'Evaluate \(2^{3}\)',
      'options': ['6', '8', '9', '12'],
      'correctIndex': 1,
      'explanation': 'two cubed is eight',
      'source': 'drill',
      'year': null,
    }));
    expect(q.id, 'qid');
    expect(q.topicId, 't1');
    expect(q.text, r'Evaluate \(2^{3}\)');
    expect(q.options, ['6', '8', '9', '12']);
    expect(q.correctIndex, 1);
    expect(q.options[q.correctIndex], '8');
    expect(q.source, 'drill');
    expect(q.year, isNull);
  });
}
