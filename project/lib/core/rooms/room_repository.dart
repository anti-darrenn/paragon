import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../models/question.dart';
import 'room.dart';
import 'teacher_quiz.dart';

/// Reads and writes for live quiz rooms (`room.dart`). Every write is the
/// exact shape `firestore.rules` checks.
///
/// **Cost.** A 30-player, 20-question game is roughly 2,000 reads (each
/// player's listener sees the room change about 40 times, the host sees
/// every answer) and 650 writes. `docs/audit/QUOTA.md` has the sums.
class RoomRepository {
  RoomRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _room(String code) =>
      _db.collection('rooms').doc(code);

  /// Makes a room and returns its code. Retries on the (rare) collision.
  ///
  /// [items] is the order (`b:<id>` bank, `q:<i>` the host's [quizId]);
  /// [questionIds] the bank ids among them. [topicName] is the room's
  /// title: a topic, several, or the quiz's name.
  Future<String> create({
    required String hostUid,
    required String subjectId,
    required String topicId,
    required String topicName,
    required List<String> questionIds,
    List<String> items = const [],
    String? quizId,
    RoomMode mode = RoomMode.classic,
    int timeLimit = 0,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = newRoomCode();
      final ref = _room(code);
      final taken = await ref.get().metered();
      if (taken.exists) continue;
      await ref.set({
        'hostUid': hostUid,
        'subjectId': subjectId,
        'topicId': topicId,
        'topicName': topicName,
        'questionIds': questionIds,
        'items': items.isEmpty ? [for (final id in questionIds) 'b:$id'] : items,
        'quizId': ?quizId,
        'mode': mode.name,
        'timeLimit': timeLimit,
        'state': RoomState.lobby.name,
        'index': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'results': <String, int>{},
        'scores': <String, int>{},
        'streaks': <String, int>{},
      });
      return code;
    }
    throw StateError('No free room code');
  }

  Stream<Room?> watch(String code) => _room(
    code,
  ).snapshots().metered().map((s) => s.exists ? Room.fromFirestore(s) : null);

  /// Every player, by uid: nickname and avatar (`preset:…`,
  /// `initials:…` or `photo:<version>`, 2026-10-17).
  Stream<Map<String, RoomPlayer>> watchPlayers(String code) => _room(code)
      .collection('players')
      .snapshots()
      .metered()
      .map(
        (q) => {
          for (final d in q.docs)
            d.id: (
              nickname: asString(d.data()['nickname'], fallback: 'Player'),
              avatar: asStringOrNull(d.data()['avatar']),
            ),
        },
      );

  /// Every answer in the room — the host's view — with when it arrived
  /// (the server's clock), for speed scoring.
  Stream<List<TimedAnswer>> watchAnswers(String code) => _room(code)
      .collection('answers')
      .snapshots()
      .metered()
      .map(
        (q) => [
          for (final d in q.docs)
            (
              uid: asString(d.data()['uid']),
              index: asInt(d.data()['index']),
              selected: asInt(d.data()['selectedIndex'], fallback: -1),
              at: d.data()['at'] is Timestamp
                  ? (d.data()['at'] as Timestamp).toDate()
                  : null,
            ),
        ],
      );

  /// A player's own answer to question [index], if any.
  Stream<int?> watchMyAnswer(String code, String uid, int index) => _room(code)
      .collection('answers')
      .doc(answerId(uid, index))
      .snapshots()
      .metered()
      .map((s) => s.exists ? asIntOrNull(s.data()?['selectedIndex']) : null);

  /// This player's nickname if they have joined [code] — after a reload,
  /// so they are not asked again.
  Future<String?> myNickname(String code, String uid) async {
    final s = await _room(code).collection('players').doc(uid).get().metered();
    return s.exists ? asString(s.data()?['nickname']) : null;
  }

  /// What this player answered to question [index], if anything.
  Future<int?> myAnswer(String code, String uid, int index) async {
    final s = await _room(
      code,
    ).collection('answers').doc(answerId(uid, index)).get().metered();
    return s.exists ? asIntOrNull(s.data()?['selectedIndex']) : null;
  }

  Future<void> join(
    String code,
    String uid,
    String nickname, {
    String? avatar,
  }) => _room(code).collection('players').doc(uid).set({
    'nickname': nickname,
    'joinedAt': FieldValue.serverTimestamp(),
    'avatar': ?avatar,
  });

  Future<void> answer(String code, String uid, int index, int selected) =>
      _room(code).collection('answers').doc(answerId(uid, index)).set({
        'uid': uid,
        'index': index,
        'selectedIndex': selected,
        'at': FieldValue.serverTimestamp(),
      });

  // ── Host transitions ─────────────────────────────────────────────

  /// Shows question [index], stamping when (the server's clock), which
  /// starts the timer every phone counts down from.
  Future<void> showQuestion(String code, int index) => _room(code).update({
    'state': RoomState.question.name,
    'index': index,
    'questionStartedAt': FieldValue.serverTimestamp(),
  });

  /// The reveal, with the scores and runs after this question.
  Future<void> reveal(
    String code, {
    Map<String, int>? scores,
    Map<String, int>? streaks,
  }) => _room(code).update({
    'state': RoomState.reveal.name,
    'scores': ?scores,
    'streaks': ?streaks,
  });

  Future<void> podium(String code, Map<String, int> results) =>
      _room(code).update({'state': RoomState.podium.name, 'results': results});

  Future<void> close(String code) =>
      _room(code).update({'state': RoomState.closed.name});

  /// The room's questions, in its order.
  Future<List<Question>> questions(List<String> ids) async {
    final out = <String, Question>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .metered();
      for (final d in snap.docs) {
        final q = Question.fromFirestore(d);
        // Only vetted questions reach students (servable.dart).
        if (q.vetted) out[d.id] = q;
      }
    }
    return [for (final id in ids) ?out[id]];
  }
}

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(FirebaseFirestore.instance),
);

final roomProvider = StreamProvider.autoDispose.family<Room?, String>(
  (ref, code) => ref.read(roomRepositoryProvider).watch(code),
);

final roomPlayersProvider = StreamProvider.autoDispose
    .family<Map<String, RoomPlayer>, String>(
      (ref, code) => ref.read(roomRepositoryProvider).watchPlayers(code),
    );

final roomAnswersProvider = StreamProvider.autoDispose
    .family<List<TimedAnswer>, String>(
      (ref, code) => ref.read(roomRepositoryProvider).watchAnswers(code),
    );

/// One player in a room: what they called themselves, and their avatar.
typedef RoomPlayer = ({String nickname, String? avatar});

/// A room's questions in its order: bank questions (vetted only) and the
/// host's own quiz questions, mixed as [Room.order] says. Keyed by the
/// order and quiz id joined, so a state change never re-reads them.
final roomItemsProvider = FutureProvider.autoDispose
    .family<List<Question>, String>((ref, key) async {
      final parts = key.split('|');
      final quizId = parts.first;
      final order = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1].split(',')
          : const <String>[];
      final bankIds = [
        for (final i in order)
          if (i.startsWith('b:')) i.substring(2),
      ];
      final bank = bankIds.isEmpty
          ? const <Question>[]
          : await ref.read(roomRepositoryProvider).questions(bankIds);
      final byId = {for (final q in bank) q.id: q};
      final quiz = quizId.isEmpty
          ? null
          : await ref.read(teacherQuizProvider(quizId).future);
      return [
        for (final i in order)
          if (i.startsWith('b:'))
            ?byId[i.substring(2)]
          else if (i.startsWith('q:') && quiz != null)
            if (int.tryParse(i.substring(2)) case final n?
                when n >= 0 && n < quiz.questions.length)
              quiz.asQuestion(n),
      ];
    });

/// The key for [roomItemsProvider].
String roomItemsKey(Room room) => '${room.quizId ?? ''}|${room.order.join(',')}';
