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

/// Drill questions for a topic (topicId)
final drillQuestionsProvider = FutureProvider.family<List<Question>, String>((
  ref,
  topicId,
) async {
  final db = ref.read(_firestoreProvider);
  final snap = await db
      .collection('questions')
      .where('topicId', isEqualTo: topicId)
      .get();
  return snap.docs.map((d) => Question.fromFirestore(d)).toList();
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
