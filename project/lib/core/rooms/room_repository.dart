import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../models/question.dart';
import 'room.dart';

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
  Future<String> create({
    required String hostUid,
    required String subjectId,
    required String topicId,
    required String topicName,
    required List<String> questionIds,
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
        'state': RoomState.lobby.name,
        'index': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'results': <String, int>{},
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

  /// Every answer in the room — the host's view.
  Stream<List<RoomAnswer>> watchAnswers(String code) => _room(code)
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

  Future<void> showQuestion(String code, int index) =>
      _room(code).update({'state': RoomState.question.name, 'index': index});

  Future<void> reveal(String code) =>
      _room(code).update({'state': RoomState.reveal.name});

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
    .family<List<RoomAnswer>, String>(
      (ref, code) => ref.read(roomRepositoryProvider).watchAnswers(code),
    );

/// A room's questions, loaded once: keyed by the ids themselves
/// (`room.questionIds.join(',')`), not by the room, so the room changing
/// state forty times a game does not re-read them forty times.
final roomQuestionsProvider = FutureProvider.autoDispose
    .family<List<Question>, String>((ref, idsKey) {
      if (idsKey.isEmpty) return Future.value(const []);
      return ref.read(roomRepositoryProvider).questions(idsKey.split(','));
    });

/// One player in a room: what they called themselves, and their avatar.
typedef RoomPlayer = ({String nickname, String? avatar});
