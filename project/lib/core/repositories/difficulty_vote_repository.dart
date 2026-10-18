import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Students' "how hard was this?" ratings (owner's decision, 2026-10-17).
///
/// One `difficultyVotes/{auto}` document per practice session, holding
/// `{userId, createdAt, votes: {questionId: 1..5}}` — never a write per
/// tap. `jobs.js --job=difficulty` adds them nightly into each question's
/// `crowdDifficulty {n, sum}` and deletes them; `blendTier` turns that
/// into the tier students see. Guests may rate too: their documents are
/// deleted with them.
///
/// Ratings are asked for in practice only (drill, exercises, mistakes,
/// quizzes), never in the topic test or the WAEC exam.
class DifficultyVoteRepository {
  DifficultyVoteRepository([this._override]);

  /// Looked up when a session is sent, not when a screen opens: a practice
  /// screen holds this from its first build, before Firebase may be ready
  /// (and in widget tests, where it never is).
  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  /// The most ratings one session sends; the rules hold the same cap.
  static const maxPerSession = 30;

  /// Sends a session's [votes]. A no-op when there are none. Not awaited by
  /// callers leaving a screen: the SDK keeps and retries the write.
  Future<void> submit({
    required String uid,
    required Map<String, int> votes,
  }) async {
    final valid = {
      for (final e in votes.entries)
        if (e.key.isNotEmpty && e.value >= 1 && e.value <= 5) e.key: e.value,
    };
    if (valid.isEmpty) return;
    final capped = Map.fromEntries(valid.entries.take(maxPerSession));
    await _db.collection('difficultyVotes').add({
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'votes': capped,
    });
  }
}

final difficultyVoteRepositoryProvider = Provider<DifficultyVoteRepository>(
  (ref) => DifficultyVoteRepository(),
);
