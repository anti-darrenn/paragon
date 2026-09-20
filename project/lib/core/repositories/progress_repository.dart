import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progress/mastery.dart';
import '../providers/auth_provider.dart';

/// Per-topic practice counters, for the mastery rings.
///
/// ## Why this is not on `users/{uid}`
///
/// `firestore.rules` restricts that document to an allow-list precisely so
/// that stats fields are server-only from the moment they exist, and
/// `CLAUDE.md` makes client-written `topicStats` a hard blocker on
/// leaderboards and XP. Nothing here challenges that. This is a separate,
/// private, display-only document, and the distinction that makes it
/// acceptable is the one that rule is protecting: **nothing competitive or
/// rewarding may ever read it.** The moment a leaderboard, an XP total or
/// an achievement depends on these numbers, they have to be recomputed
/// server-side from `attempts` first.
///
/// That recomputation is always available, which is the other half of the
/// argument: `attempts` remains the source of truth. Every increment here
/// is written alongside an `attempts` document carrying the same facts and
/// a real `serverTimestamp()`. This document is a cache of a query the
/// free tier cannot afford to run, not a second set of books.
///
/// ## Why it is a cache at all
///
/// The honest way to draw these rings is to count `attempts` per topic.
/// Firestore has no GROUP BY, so that is one `count()` aggregate per
/// topic — 40 to 64 of them for a single course page — or one unbounded
/// read of every attempt the student has ever made in the subject. On the
/// Spark plan's 50k daily reads, with a corpus deliberately sized to the
/// free tier, neither is affordable. One document read per session is.
///
/// ## Write cost
///
/// One write per *session*, not per question. The drill screen accumulates
/// in memory and flushes once, which keeps a 20-question session at the 20
/// attempt writes it already costs rather than doubling them. The cost of
/// that choice is that a session lost to a closed browser tab mid-drill is
/// not counted — the `attempts` documents for it still exist, so nothing
/// is actually lost, only this cache is briefly behind.
///
/// ## Drill only, deliberately
///
/// WAEC exam answers do not feed these counters. Two reasons, and the
/// second is the one that decides it: the rings are a Learning Mode idea,
/// and CLAUDE.md is emphatic that the two modes must not merge; and a
/// single exam spans a whole subject, so attributing it would mean one
/// write per topic it touched — up to forty — for one submission. That is
/// precisely the write pattern the session-level flush above exists to
/// avoid. Exam performance is recorded in `attempts` with
/// `source: 'waec'`, where an exam-history feature can read it properly.
class ProgressRepository {
  const ProgressRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('progress').doc(uid);

  Future<UserProgress> fetch(String uid) async {
    final snap = await _doc(uid).get();
    return UserProgress.fromDocument(snap.data());
  }

  /// Adds one session's totals to [topicId].
  ///
  /// `FieldValue.increment` rather than read-modify-write: two devices
  /// finishing a session at once must not clobber each other, and this is
  /// the same reasoning that made `updateStreak` a transaction. Increment
  /// is better than a transaction here because it needs no read at all.
  ///
  /// `SetOptions(merge: true)` deep-merges nested maps — the same
  /// behaviour `UserRepository.setProfile` relies on — so this touches
  /// only the named topic's two counters and leaves every other topic in
  /// the map alone. It also creates the document on a student's first
  /// session, so there is no provisioning step.
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String subjectId,
    required int answered,
    required int correct,
  }) async {
    if (answered <= 0) return;

    await _doc(uid).set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'topics': {
        topicId: {
          'answered': FieldValue.increment(answered),
          'correct': FieldValue.increment(correct),
          // Stamped on every write so the document can answer "how many
          // topics has this student started in Physics" on its own. Without
          // it, attributing a topic to its subject means loading that
          // subject's whole outline — which is affordable on a course page,
          // where it is loaded anyway, and not on the dashboard, where it
          // would mean doing it for every subject the student picked.
          'subjectId': subjectId,
        },
      },
    }, SetOptions(merge: true));
  }
}

/// Every topic a student has practised, keyed by topic id.
class UserProgress {
  const UserProgress(this._topics);

  final Map<String, TopicProgress> _topics;

  static const UserProgress empty = UserProgress({});

  TopicProgress forTopic(String topicId) =>
      _topics[topicId] ?? TopicProgress.none;

  MasteryLevel levelFor(String topicId) => forTopic(topicId).level;

  bool get isEmpty => _topics.isEmpty;

  int get startedTopicCount =>
      _topics.values.where((p) => p.level.isStarted).length;

  /// Topics taken to proficient or above, across every subject.
  int get completedTopicCount =>
      _topics.values.where((p) => p.level.isComplete).length;

  /// Questions answered across every topic — the one number here that is a
  /// direct count of work done rather than a judgement about it.
  int get totalAnswered =>
      _topics.values.fold(0, (total, p) => total + p.answered);

  /// Per-subject rollup, from the `subjectId` stamped on each entry.
  ///
  /// Entries written before that stamp existed carry an empty subject and
  /// are counted in no subject at all, rather than being guessed at. The
  /// effect is that a long-standing student's first look at a new
  /// dashboard undercounts until they next practise — which is wrong in
  /// the safe direction, and self-corrects.
  SubjectProgress forSubject(String subjectId) {
    if (subjectId.isEmpty) return const SubjectProgress();
    var started = 0;
    var complete = 0;
    var answered = 0;
    for (final entry in _topics.values) {
      if (entry.subjectId != subjectId) continue;
      if (!entry.level.isStarted) continue;
      started++;
      answered += entry.answered;
      if (entry.level.isComplete) complete++;
    }
    return SubjectProgress(
      startedTopics: started,
      completedTopics: complete,
      answered: answered,
    );
  }

  static UserProgress fromDocument(Map<String, dynamic>? data) {
    final raw = data?['topics'];
    if (raw is! Map) return empty;
    return UserProgress({
      for (final entry in raw.entries)
        if (entry.key is String)
          entry.key as String: TopicProgress.fromMap(entry.value),
    });
  }
}

/// What one subject's worth of practice adds up to.
///
/// Counts only — deliberately no percentage. A percentage needs the number
/// of topics the subject *has*, which is not on the subject document and
/// cannot be known without loading the whole outline. The course page has
/// that outline and shows a real ring; anywhere that does not has counts,
/// rather than a number that looks precise and is invented.
class SubjectProgress {
  const SubjectProgress({
    this.startedTopics = 0,
    this.completedTopics = 0,
    this.answered = 0,
  });

  final int startedTopics;
  final int completedTopics;
  final int answered;

  bool get isEmpty => startedTopics == 0;
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(FirebaseFirestore.instance);
});

/// The signed-in student's progress.
///
/// A `StreamProvider` so a finished drill updates every ring on the way
/// back out without anything having to invalidate it by hand. That costs
/// one document listener, not one per topic.
final userProgressProvider = StreamProvider<UserProgress>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(UserProgress.empty);

  return FirebaseFirestore.instance
      .collection('progress')
      .doc(user.uid)
      .snapshots()
      .map((doc) => UserProgress.fromDocument(doc.data()));
});
