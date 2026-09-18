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
  final base = db.collection('questions').where('topicId', isEqualTo: topicId);

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

// WAEC papers run 40-50 objective questions in practice, and it's the
// unbuilt §2.3.3 setup screen's own default question count (range 10-60) —
// capping here means behaviour won't change once that screen adds the
// slider, only configurability will.
const _waecExamSize = 40;

// WAEC's actual scraped year range (see .cursorrules "SUBJECT SLUGS" /
// scraper URL pattern) — used only to pick a random rotation point below,
// not as a hard data boundary.
const _waecEarliestYear = 1990;
const _waecLatestYear = 2024;

/// WAEC exam questions by subjectId, capped to [_waecExamSize] so a subject
/// with hundreds of seeded questions (Physics: 1769, Mathematics: 1716)
/// doesn't load its entire bank on a single exam screen.
///
/// Rotation is coarse, not a uniform random sample. A random pivot year
/// selects a forward window (year >= pivot, ascending), backfilled from
/// below if the tail of the range runs short. That's biased at both edges
/// of the nominal 1990-2024 range, confirmed live on real data:
/// - Bottom edge: a subject whose data doesn't start until partway through
///   the range collapses every earlier pivot onto the same block. Further
///   Mathematics has no WAEC questions before 2006 — pivots 1990 through
///   2005 (16 of 35 possible values) all return the exact same 40
///   documents, pre-shuffle.
/// - Top edge: a pivot with little forward room left falls straight into
///   backfill, which always sweeps the same most-recent-years cluster
///   regardless of which late pivot you started from.
/// The result list is shuffled below to at least fix a second, separate
/// bug that hits even a collapsed pivot: Firestore returns documents
/// within a year in a stable order, so without shuffling, two students on
/// the same pivot would get an identical paper in identical order.
///
/// True uniform sampling would need either a stored random field on each
/// question (a seeder/schema change, out of scope for this minimal cap) or
/// Query.offset() into the full population — which Firestore bills as a
/// read per skipped document, reintroducing the exact cost problem this
/// cap exists to fix. Deferred to Session 10's real exam configuration
/// work if it matters by then; this fixes the live breakage (loading
/// hundreds to thousands of questions per exam), not the sampling design.
final waecQuestionsProvider = FutureProvider.family<List<Question>, String>((
  ref,
  subjectId,
) async {
  final db = ref.read(_firestoreProvider);
  final base = db
      .collection('questions')
      .where('subjectId', isEqualTo: subjectId)
      .where('source', isEqualTo: 'waec');

  final pivotYear =
      _waecEarliestYear +
      Random().nextInt(_waecLatestYear - _waecEarliestYear + 1);

  final forward = await base
      .where('year', isGreaterThanOrEqualTo: pivotYear)
      .orderBy('year')
      .limit(_waecExamSize)
      .get();

  var docs = forward.docs;
  if (docs.length < _waecExamSize) {
    final backfill = await base
        .where('year', isLessThan: pivotYear)
        .orderBy('year', descending: true)
        .limit(_waecExamSize - docs.length)
        .get();
    docs = [...docs, ...backfill.docs];
  }
  docs = docs.toList()..shuffle();

  return docs.map((d) => Question.fromFirestore(d)).toList();
});
