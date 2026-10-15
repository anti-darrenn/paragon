import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';

/// Live quiz rooms, kept simple on purpose (launch plan phase 3): a host
/// with an account picks a topic, students join with a six-letter code —
/// guests included — and everyone answers the same question at once.
/// One point per right answer; no speed bonus, no leaderboard beyond the
/// room, nothing kept after a day.
///
/// `rooms/{code}` (host writes), `rooms/{code}/players/{uid}` (a nickname,
/// written once by its player) and `rooms/{code}/answers/{uid_index}` (one
/// per player per question, accepted only while that question is live).
/// The rules check all of that with a `get()` of the room.
///
/// **Rooms never touch `attempts` or `progress`.** A game is not practice
/// the student chose, and a classroom game must not be a way around the
/// topic test.
enum RoomState {
  lobby,
  question,
  reveal,
  podium,
  closed;

  static RoomState parse(Object? v) => RoomState.values.firstWhere(
    (s) => s.name == v,
    orElse: () => RoomState.closed,
  );
}

class Room {
  const Room({
    required this.code,
    required this.hostUid,
    required this.subjectId,
    required this.topicId,
    required this.topicName,
    required this.questionIds,
    required this.state,
    required this.index,
    this.results = const {},
    this.createdAt,
  });

  final String code;
  final String hostUid;
  final String subjectId;
  final String topicId;
  final String topicName;
  final List<String> questionIds;
  final RoomState state;

  /// The current question, 0-based.
  final int index;

  /// Points by player uid, written by the host at the podium.
  final Map<String, int> results;

  /// Rooms last a day from this (rules and `jobs.js --job=rooms`).
  final DateTime? createdAt;

  bool get isLast => index >= questionIds.length - 1;

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final raw = d['results'];
    final created = d['createdAt'];
    return Room(
      code: doc.id,
      hostUid: asString(d['hostUid']),
      subjectId: asString(d['subjectId']),
      topicId: asString(d['topicId']),
      topicName: asString(d['topicName']),
      questionIds: asStringList(d['questionIds']),
      state: RoomState.parse(d['state']),
      index: asInt(d['index']),
      results: raw is Map
          ? {for (final e in raw.entries) '${e.key}': asInt(e.value)}
          : const {},
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// The most players a room takes. Not enforceable in the rules (they
/// cannot count), so the join screen checks it; a few extra cost reads,
/// nothing more.
const int kMaxRoomPlayers = 50;

/// Six characters with nothing to confuse when read off a projector: no
/// 0/O, 1/I/L.
const String kRoomCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String newRoomCode([math.Random? random]) {
  final r = random ?? math.Random.secure();
  return List.generate(
    6,
    (_) => kRoomCodeAlphabet[r.nextInt(kRoomCodeAlphabet.length)],
  ).join();
}

/// What a typed code becomes: upper case, spaces and dashes gone. Null if
/// it cannot be a code — six characters from [kRoomCodeAlphabet], which
/// has no 0/O or 1/I/L to mistype.
String? normaliseRoomCode(String typed) {
  final c = typed.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (c.length != 6) return null;
  for (final ch in c.split('')) {
    if (!kRoomCodeAlphabet.contains(ch)) return null;
  }
  return c;
}

/// The answer document's id: one per player per question, which is how the
/// rules make an answer impossible to give twice.
String answerId(String uid, int index) => '${uid}_$index';

/// One player's answer.
typedef RoomAnswer = ({String uid, int index, int selected});

/// Points per player: one for each answer that matches its question's
/// right option. Players who answered nothing still appear, with 0.
Map<String, int> roomScores({
  required Iterable<String> players,
  required Iterable<RoomAnswer> answers,
  required List<int> correctIndexes,
}) {
  final scores = {for (final p in players) p: 0};
  for (final a in answers) {
    if (a.index < 0 || a.index >= correctIndexes.length) continue;
    if (!scores.containsKey(a.uid)) continue; // left, or never joined
    if (a.selected == correctIndexes[a.index]) {
      scores[a.uid] = scores[a.uid]! + 1;
    }
  }
  return scores;
}

/// Standings, best first; equal scores share a place ("1, 2, 2, 4").
List<({String uid, int score, int place})> standings(Map<String, int> scores) {
  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final out = <({String uid, int score, int place})>[];
  for (var i = 0; i < sorted.length; i++) {
    final place = i > 0 && sorted[i].value == sorted[i - 1].value
        ? out[i - 1].place
        : i + 1;
    out.add((uid: sorted[i].key, score: sorted[i].value, place: place));
  }
  return out;
}

/// How many chose each option for one question — the reveal's bar chart.
List<int> optionCounts(Iterable<RoomAnswer> answers, int index, int options) {
  final counts = List<int>.filled(options, 0);
  for (final a in answers) {
    if (a.index == index && a.selected >= 0 && a.selected < options) {
      counts[a.selected]++;
    }
  }
  return counts;
}
