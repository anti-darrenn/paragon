import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject.dart';
import '../models/unit.dart';
import '../models/topic.dart';
import '../models/question.dart';

final _firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Loads the list of subjects.
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db.collection('subjects').orderBy('name').get();
  return snap.docs.map((d) => Subject.fromFirestore(d)).toList();
});

/// Units by subjectId
final unitsProvider = FutureProvider.family<List<Unit>, String>((
  ref,
  subjectId,
) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('units')
      .where('subjectId', isEqualTo: subjectId)
      .orderBy('order')
      .get();
  return snap.docs.map((d) => Unit.fromFirestore(d)).toList();
});

/// Topics by unitId
final topicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  unitId,
) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('topics')
      .where('unitId', isEqualTo: unitId)
      .orderBy('order')
      .get();
  return snap.docs.map((d) => Topic.fromFirestore(d)).toList();
});

/// One topic by id. The lesson page needs its name, unit and subject (the
/// last two for the topic-test link at the end of a lesson); the editor
/// needs its subject.
final topicByIdProvider = FutureProvider.family<Topic?, String>((
  ref,
  topicId,
) async {
  final snap = await ref
      .read(_firestoreProvider)
      .collection('topics')
      .doc(topicId)
      .get();
  return snap.exists ? Topic.fromFirestore(snap) : null;
});

// Spec §2.2.7: "If a topic has fewer than 5 questions: all are shown. If
// more than 20: cap at 20 per session." Live data: 42 of 128 topics already
// have fewer than 20 questions (min 1) — the cap is a no-op for a third of
// topics and only bites the ones that exceed it (max seen: 103).
const _drillSessionSize = 20;

// Firestore auto-generated document IDs draw from this 62-char alphabet.
// Used to synthesize a random cursor for FieldPath.documentId ordering —
// there's no year-like field on questions to rotate on the way WAEC does,
// but doc IDs are themselves random strings, so a random starting point
// works the same way: no new index (ordering by document ID after a single
// equality filter doesn't need one), no stored random field.
const _autoIdAlphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

String _randomAutoId(Random random) {
  return List.generate(
    20,
    (_) => _autoIdAlphabet[random.nextInt(_autoIdAlphabet.length)],
  ).join();
}

/// Drill questions for a topic (topicId), capped to [_drillSessionSize] and
/// rotated via a random document-ID cursor so a topic with more than
/// [_drillSessionSize] questions doesn't serve the same fixed subset every
/// session — drill is the repeat-use surface, so unlike a plain .limit()
/// this needs to actually vary across visits, not just cap the worst case.
///
/// If the forward window runs short (random start landed near the end of
/// the topic's ID range), wrap to the beginning. The wrap fetch pulls up to
/// [_drillSessionSize] candidates (not just the shortfall) and filters out
/// anything the forward query already returned — needed because an
/// unfiltered wrap query has no upper bound on document ID, so for a small
/// topic (pool close to the cap) it can otherwise re-read documents the
/// forward query already got, double-counting them. Worst case this means
/// up to 2x [_drillSessionSize] reads on the wrap path, not a strict cap —
/// still far below the uncapped worst case of 103.
final drillQuestionsProvider = FutureProvider.family<List<Question>, String>((
  ref,
  topicId,
) async {
  final db = ref.read(_firestoreProvider);
  // hasAnswer only — a question with no verified answer can never be marked
  // correct, which is the defect this whole pass exists to remove
  final base = db
      .collection('questions')
      .where('topicId', isEqualTo: topicId)
      .where('hasAnswer', isEqualTo: true);

  final randomStart = _randomAutoId(Random());
  final forward = await base
      .orderBy(FieldPath.documentId)
      .startAt([randomStart])
      .limit(_drillSessionSize)
      .get();

  var docs = forward.docs;
  if (docs.length < _drillSessionSize) {
    final seenIds = docs.map((d) => d.id).toSet();
    final wrap = await base
        .orderBy(FieldPath.documentId)
        .limit(_drillSessionSize)
        .get();
    final needed = _drillSessionSize - docs.length;
    final additions = wrap.docs
        .where((d) => !seenIds.contains(d.id))
        .take(needed);
    docs = [...docs, ...additions];
  }

  final shuffled = docs.toList()..shuffle();
  return shuffled.map((d) => Question.fromFirestore(d)).toList();
});

// Safety net only — real per-subject bounds always come from
// waecYearRangeProvider below. Live data proved a single hardcoded range
// wrong last session: Further Mathematics runs 2006-2025, not 1990-2024,
// and a fixed 2024 upper bound silently excluded a real year of content.
const _waecFallbackEarliestYear = 1990;
const _waecFallbackLatestYear = 2024;

/// A subject's real WAEC year range — two single-document reads (one
/// ascending, one descending by year), both covered by the existing
/// subjectId+source+year composite indexes. Falls back to the nominal
/// 1990-2024 range only if a subject somehow has zero WAEC questions.
final waecYearRangeProvider = FutureProvider.family<(int min, int max), String>(
  (ref, subjectId) async {
    final db = ref.read(_firestoreProvider);
    final base = db
        .collection('questions')
        .where('subjectId', isEqualTo: subjectId)
        .where('source', isEqualTo: 'waec')
        .where('hasAnswer', isEqualTo: true);

    final earliest = await base.orderBy('year').limit(1).get();
    final latest = await base.orderBy('year', descending: true).limit(1).get();

    final min = earliest.docs.isEmpty
        ? _waecFallbackEarliestYear
        : (earliest.docs.first.data()['year'] as num).toInt();
    final max = latest.docs.isEmpty
        ? _waecFallbackLatestYear
        : (latest.docs.first.data()['year'] as num).toInt();
    return (min, max);
  },
);

/// Key for [waecAvailableCountProvider] — deliberately excludes
/// questionCount/shuffle so dragging the count slider or flipping shuffle
/// doesn't trigger a new count() read; only the subject and year range
/// actually change how many questions are available.
class WaecYearRangeQuery {
  const WaecYearRangeQuery({
    required this.subjectId,
    required this.yearFrom,
    required this.yearTo,
  });

  final String subjectId;
  final int yearFrom;
  final int yearTo;

  @override
  bool operator ==(Object other) =>
      other is WaecYearRangeQuery &&
      other.subjectId == subjectId &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo;

  @override
  int get hashCode => Object.hash(subjectId, yearFrom, yearTo);
}

/// Dynamic availability count for the setup screen's label (spec §2.3.3:
/// "Fetched from a count query — not a full document fetch"). A Firestore
/// count() aggregate — it never transfers the matching documents, only a
/// number, and reuses the same composite index the exam fetch below does.
final waecAvailableCountProvider =
    FutureProvider.family<int, WaecYearRangeQuery>((ref, query) async {
      final db = ref.read(_firestoreProvider);
      final aggregate = await db
          .collection('questions')
          .where('subjectId', isEqualTo: query.subjectId)
          .where('source', isEqualTo: 'waec')
          .where('hasAnswer', isEqualTo: true)
          .where('year', isGreaterThanOrEqualTo: query.yearFrom)
          .where('year', isLessThanOrEqualTo: query.yearTo)
          .count()
          .get();
      return aggregate.count ?? 0;
    });

/// Full config for one exam fetch — subject, year range, question count,
/// and whether to rotate/shuffle or serve deterministic chronological
/// order. Used only as [waecExamQuestionsProvider]'s family key.
class WaecExamConfig {
  const WaecExamConfig({
    required this.subjectId,
    required this.yearFrom,
    required this.yearTo,
    required this.questionCount,
    required this.shuffle,
  });

  final String subjectId;
  final int yearFrom;
  final int yearTo;
  final int questionCount;
  final bool shuffle;

  @override
  bool operator ==(Object other) =>
      other is WaecExamConfig &&
      other.subjectId == subjectId &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo &&
      other.questionCount == questionCount &&
      other.shuffle == shuffle;

  @override
  int get hashCode =>
      Object.hash(subjectId, yearFrom, yearTo, questionCount, shuffle);
}

/// Exam questions for [config] — capped to config.questionCount, scoped to
/// config.yearFrom..config.yearTo (never beyond it, unlike last session's
/// hardcoded-range version: a user-selected range narrower than the
/// subject's full range must not silently pull in years outside it).
///
/// config.shuffle == true: rotates via a random pivot year within the
/// selected range plus wraparound, then shuffles — same mechanism as last
/// session, now scoped to the chosen range instead of a hardcoded one, and
/// carrying the same coarse-not-uniform caveat documented there.
///
/// config.shuffle == false: deterministic, oldest-first, no rotation — per
/// spec 2.3.3's literal "chronological order" language for that toggle
/// state. That's intentional determinism, not the rotation bug recurring.
final waecExamQuestionsProvider =
    FutureProvider.family<List<Question>, WaecExamConfig>((ref, config) async {
      final db = ref.read(_firestoreProvider);
      final base = db
          .collection('questions')
          .where('subjectId', isEqualTo: config.subjectId)
          .where('source', isEqualTo: 'waec')
          .where('hasAnswer', isEqualTo: true);

      if (!config.shuffle) {
        final snap = await base
            .where('year', isGreaterThanOrEqualTo: config.yearFrom)
            .where('year', isLessThanOrEqualTo: config.yearTo)
            .orderBy('year')
            .limit(config.questionCount)
            .get();
        return snap.docs.map((d) => Question.fromFirestore(d)).toList();
      }

      final pivotYear =
          config.yearFrom +
          Random().nextInt(config.yearTo - config.yearFrom + 1);

      final forward = await base
          .where('year', isGreaterThanOrEqualTo: pivotYear)
          .where('year', isLessThanOrEqualTo: config.yearTo)
          .orderBy('year')
          .limit(config.questionCount)
          .get();

      var docs = forward.docs;
      if (docs.length < config.questionCount) {
        final backfill = await base
            .where('year', isLessThan: pivotYear)
            .where('year', isGreaterThanOrEqualTo: config.yearFrom)
            .orderBy('year', descending: true)
            .limit(config.questionCount - docs.length)
            .get();
        docs = [...docs, ...backfill.docs];
      }
      final shuffled = docs.toList()..shuffle();

      return shuffled.map((d) => Question.fromFirestore(d)).toList();
    });
