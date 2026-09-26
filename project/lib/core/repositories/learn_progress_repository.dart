import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../learn/lesson_progress.dart';
import '../learn/topic_test.dart';
import '../models/learn_resource.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import 'progress_repository.dart';

/// Topic-test results and Learn completion, one document per student:
/// `learn/{uid}`. Both sit under `topics.<topicId>` — the test fields
/// (`passed`, `bestScore`, …) beside `completed`, `lastCompletedId` and
/// `lastCompletedAt` — and each parser ignores the other's keys. Neither
/// is recomputable from `attempts`, which is the whole reason this document
/// exists; everything said below about test results holds for completion.
///
/// ## Why not `progress/{uid}`
///
/// That document is documented — in its own repository, in `firestore.rules`
/// and in CLAUDE.md — as a **cache of a query the free tier cannot afford**,
/// recomputable at any time from `attempts`. Every claim made for its
/// safety rests on that.
///
/// A topic-test pass is not recomputable from `attempts`. The attempts a
/// test produces are individually indistinguishable from any other ten
/// answers; nothing in that collection records which ten belonged to one
/// sitting, so "did this student ever score 80% in one attempt" cannot be
/// reconstructed. Storing it in a document described as a cache would make
/// that description false, and the next person to reason about `progress`
/// from its doc comment would reason wrongly.
///
/// So it lives here, in its own document, with its own rules block and its
/// own honest description: **authoritative, client-written, and not
/// verifiable.**
///
/// ## Why one document rather than a subcollection
///
/// `users/{uid}/topicProgress/{topicId}` is the shape that first suggests
/// itself, and on Spark it is the wrong one: deciding whether to draw a
/// padlock on a topic list of forty rows would be forty document reads,
/// per visit. One document is one read, and answers the whole page.
///
/// The cost is the 1 MiB document limit. At roughly 90 bytes per topic
/// entry, 216 topics is about 20 KB — two orders of magnitude clear.
///
/// ## What the rules can and cannot enforce
///
/// They pin the shape: closed top-level field set, owner-only both ways,
/// `updatedAt` forced to the real `serverTimestamp()` sentinel. They
/// cannot check that `passed` was earned, because a write is one document
/// and the ten answers behind it are not in it. See `topic_test.dart` for
/// why that is acceptable for this particular gate and would not be for a
/// rewarding one.
class LearnProgressRepository {
  const LearnProgressRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('learn').doc(uid);

  Future<TopicTestProgress> fetch(String uid) async {
    final snap = await _doc(uid).get();
    return TopicTestProgress.fromDocument(snap.data());
  }

  /// Records one finished topic-test attempt.
  ///
  /// `attempts` is incremented rather than written, so two devices
  /// finishing a test at once cannot clobber each other's count — the same
  /// reasoning as `ProgressRepository.addSession`, and better than a
  /// transaction because it needs no read.
  ///
  /// `passed` and `bestScore` cannot be increments, so they are read from
  /// [previous] — the value the screen already has in hand from the
  /// stream — and written as a monotonic maximum:
  ///
  ///   - `passed` is sticky: once true it stays true. A retake that goes
  ///     badly must not re-lock drill. Retakes are unlimited and a student
  ///     practising is not a student regressing.
  ///   - `bestScore` only ever rises.
  ///
  /// The race that remains is two simultaneous attempts on the same topic
  /// from two devices, where the lower score could win the `bestScore`
  /// write. It resolves itself on the next attempt, and the gate is
  /// unaffected because `passed` is sticky in the safe direction.
  ///
  /// One write per completed test — not per question.
  Future<void> recordAttempt({
    required String uid,
    required String topicId,
    required String subjectId,
    required int correct,
    required int total,
    required TopicTestRecord previous,
  }) async {
    if (total <= 0) return;

    final score = topicTestScore(correct: correct, total: total);
    final passedNow = topicTestPassed(correct: correct, total: total);

    await _doc(uid).set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'topics': {
        topicId: {
          'passed': previous.passed || passedNow,
          'bestScore': score > previous.bestScore ? score : previous.bestScore,
          'attempts': FieldValue.increment(1),
          'subjectId': subjectId,
          // A nested sentinel. The rules pin the top-level `updatedAt` but
          // cannot reach a dynamic map key, so this one is unverified —
          // acceptable because nothing reads it except a student looking at
          // their own history.
          'lastAttemptAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
  }

  /// Records one finished Learn item — a video watched, an article read,
  /// an exercise set completed.
  ///
  /// Same document, same merge shape as [recordAttempt], nested under the
  /// topic's entry so it reads with the one listener the app already
  /// holds. Callers skip this when the item is already complete (see
  /// `markLessonComplete`), so each item costs one write, once.
  Future<void> markComplete({
    required String uid,
    required String topicId,
    required String subjectId,
    required String resourceId,
  }) {
    return _doc(uid).set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'topics': {
        topicId: {
          'subjectId': subjectId,
          'completed': {resourceId: true},
          'lastCompletedId': resourceId,
          'lastCompletedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
  }

  /// Records every completion in [lessons] in one write — a guest's visit,
  /// carried into the account they have just created. The guest kept these
  /// in memory only (see [GuestLessonProgress]), so this is the one chance
  /// to keep them.
  Future<void> markAllComplete({
    required String uid,
    required LessonProgress lessons,
  }) async {
    final topics = <String, Object?>{
      for (final e in lessons.entries)
        if (e.value.completed.isNotEmpty)
          e.key: {
            'subjectId': e.value.subjectId,
            'completed': {for (final id in e.value.completed) id: true},
            if (e.value.lastCompletedId != null)
              'lastCompletedId': e.value.lastCompletedId,
            'lastCompletedAt': FieldValue.serverTimestamp(),
          },
    };
    if (topics.isEmpty) return;
    await _doc(uid).set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'topics': topics,
    }, SetOptions(merge: true));
  }
}

final learnProgressRepositoryProvider = Provider<LearnProgressRepository>((ref) {
  return LearnProgressRepository(FirebaseFirestore.instance);
});

/// The signed-in student's topic-test results.
///
/// A `StreamProvider`, so passing a test unlocks every padlock on the way
/// back out without anything having to invalidate it by hand. One document
/// listener for the whole app, not one per topic.
final topicTestProgressProvider = StreamProvider<TopicTestProgress>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(TopicTestProgress.empty);

  return FirebaseFirestore.instance
      .collection('learn')
      .doc(user.uid)
      .snapshots()
      .map((doc) => TopicTestProgress.fromDocument(doc.data()));
});

/// A signed-in student's finished Learn items, from the same `learn/{uid}`
/// document as [topicTestProgressProvider] — the SDK serves both from one
/// listener, so this costs no extra reads.
final _storedLessonProgressProvider = StreamProvider<LessonProgress>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || user.isAnonymous) return Stream.value(LessonProgress.empty);

  return FirebaseFirestore.instance
      .collection('learn')
      .doc(user.uid)
      .snapshots()
      .map((doc) => LessonProgress.fromDocument(doc.data()));
});

/// A guest's completions, for this visit only. Nothing about a guest's
/// Learn activity is stored — see `guest_limits.dart` — unless they turn
/// the session into an account, when `guest_upgrade.dart` writes these
/// with [LearnProgressRepository.markAllComplete].
class GuestLessonProgress extends Notifier<LessonProgress> {
  @override
  LessonProgress build() {
    // A new session (sign-in, sign-out) starts clean.
    ref.watch(authStateProvider);
    return LessonProgress.empty;
  }

  void complete(String topicId, String resourceId, {String? subjectId}) {
    state = state.withCompleted(topicId, resourceId, subjectId: subjectId);
  }
}

final guestLessonProgressProvider =
    NotifierProvider<GuestLessonProgress, LessonProgress>(
      GuestLessonProgress.new,
    );

/// Finished Learn items for whoever is signed in: stored for a real
/// account, in memory for a guest. Empty while loading, which only means a
/// checkmark appears a moment late.
final lessonProgressProvider = Provider<LessonProgress>((ref) {
  if (ref.watch(isGuestProvider)) return ref.watch(guestLessonProgressProvider);
  return ref.watch(_storedLessonProgressProvider).asData?.value ??
      LessonProgress.empty;
});

/// Marks a Learn item finished — the one entry point the lesson screen
/// uses, so the "skip if already done" rule and the guest split live in
/// one place.
Future<void> markLessonComplete(
  WidgetRef ref, {
  required LearnResource resource,
}) async {
  if (ref.read(lessonProgressProvider).isComplete(resource.topicId, resource.id)) {
    return;
  }
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  if (user.isAnonymous) {
    ref
        .read(guestLessonProgressProvider.notifier)
        .complete(
          resource.topicId,
          resource.id,
          // Kept so that, if the guest makes an account, the completion
          // carries its subject like any other.
          subjectId: resource.subjectId,
        );
  } else {
    await ref.read(learnProgressRepositoryProvider).markComplete(
      uid: user.uid,
      topicId: resource.topicId,
      subjectId: resource.subjectId,
      resourceId: resource.id,
    );
  }
  ref.read(analyticsProvider).lessonItemComplete(
    topicId: resource.topicId,
    type: resource.type.name,
  );
}

/// Whether the signed-in student may drill [topicId], and if not, why.
///
/// The single place the gate is evaluated. Both the padlock on a topic row
/// and the locked state inside `DrillScreen` read this, so a student can
/// never be shown an unlocked row that refuses them on arrival.
///
/// Synchronous by construction: both underlying streams have an `empty`
/// value, so a still-loading document reads as "no test passed" rather
/// than blocking. That direction is deliberate — a brief flash of a
/// padlock that resolves into an unlocked topic is a much smaller failure
/// than a gate that hangs, or one that opens while it waits.
final drillAccessProvider = Provider.family<DrillAccess, String>((
  ref,
  topicId,
) {
  final user = ref.watch(currentUserProvider);
  final tests =
      ref.watch(topicTestProgressProvider).asData?.value ??
      TopicTestProgress.empty;
  final progress =
      ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;

  return drillAccessFor(
    isSignedIn: user != null,
    isGuest: ref.watch(isGuestProvider),
    testRecord: tests.forTopic(topicId),
    drillMastery: progress.levelFor(topicId),
  );
});
