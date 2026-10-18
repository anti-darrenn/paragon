import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../providers/auth_provider.dart';
import 'room.dart';

/// "Quiz history" (owner's request, 2026-10-17): every live quiz a student
/// played or hosted, with the score and place, and how many were won.
///
/// Each phone writes its own entry once the room reaches the podium:
/// `quizHistory/{code}_{uid}`, one per room per person. The rules check a
/// player's score against the room's `results`, so nobody can record a
/// better game than they played. Guests keep theirs too, until their
/// account is cleaned up.
class QuizHistoryEntry {
  const QuizHistoryEntry({
    required this.roomCode,
    required this.title,
    required this.role,
    required this.score,
    required this.place,
    required this.players,
    required this.total,
    required this.mode,
    this.at,
  });

  final String roomCode;
  final String title;

  /// `player` or `host`.
  final String role;
  final int score;

  /// 1 is a win. A host's entry has none (0).
  final int place;
  final int players;
  final int total;
  final RoomMode mode;
  final DateTime? at;

  bool get isHost => role == 'host';
  bool get won => !isHost && place == 1 && players > 1;

  static QuizHistoryEntry fromMap(Map<String, dynamic> d) {
    final at = d['at'];
    return QuizHistoryEntry(
      roomCode: asString(d['roomCode']),
      title: asString(d['title'], fallback: 'Live quiz'),
      role: asString(d['role'], fallback: 'player'),
      score: asInt(d['score']),
      place: asInt(d['place']),
      players: asInt(d['players']),
      total: asInt(d['total']),
      mode: RoomMode.parse(d['mode']),
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

/// Wins, games and the best score, for the top of the history page. Pure.
({int games, int wins, int hosted}) historyTotals(List<QuizHistoryEntry> e) => (
  games: e.where((x) => !x.isHost).length,
  wins: e.where((x) => x.won).length,
  hosted: e.where((x) => x.isHost).length,
);

class QuizHistoryRepository {
  QuizHistoryRepository([this._override]);

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  /// Records this person's part in a finished room. Writing it twice is
  /// harmless: the id is fixed and the rules refuse a changed score.
  Future<void> record({
    required String uid,
    required Room room,
    required int players,
  }) async {
    final isHost = room.hostUid == uid;
    final rows = standings(room.results);
    final me = rows.where((r) => r.uid == uid).firstOrNull;
    if (!isHost && me == null) return;
    await _db.doc('quizHistory/${room.code}_$uid').set({
      'userId': uid,
      'roomCode': room.code,
      'title': room.topicName.length > 120
          ? room.topicName.substring(0, 120)
          : room.topicName,
      'role': isHost ? 'host' : 'player',
      'score': isHost ? 0 : me!.score,
      'place': isHost ? 0 : me!.place,
      'players': players,
      'total': room.questionCount,
      'mode': room.mode.name,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<QuizHistoryEntry>> mine(String uid) async {
    final snap = await _db
        .collection('quizHistory')
        .where('userId', isEqualTo: uid)
        .limit(200)
        .get()
        .metered();
    return [for (final d in snap.docs) QuizHistoryEntry.fromMap(d.data())]
      ..sort(
        (a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)),
      );
  }
}

final quizHistoryRepositoryProvider = Provider<QuizHistoryRepository>(
  (ref) => QuizHistoryRepository(),
);

final myQuizHistoryProvider =
    FutureProvider.autoDispose<List<QuizHistoryEntry>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const [];
      return ref.read(quizHistoryRepositoryProvider).mine(user.uid);
    });
