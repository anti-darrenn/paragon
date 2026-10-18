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

/// How a room scores (2026-10-17).
enum RoomMode {
  /// One point per right answer, the original rooms.
  classic,

  /// Kahoot-style: up to [kSpeedMaxPoints] for a right answer, less the
  /// longer it took, plus a bonus for a run of right answers.
  speed;

  static RoomMode parse(Object? v) =>
      v == 'speed' ? RoomMode.speed : RoomMode.classic;
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
    this.items = const [],
    this.quizId,
    this.mode = RoomMode.classic,
    this.timeLimit = 0,
    this.questionStartedAt,
    this.scores = const {},
    this.streaks = const {},
  });

  /// The questions in order: `b:<questionId>` from the bank, `q:<i>`
  /// the i-th of the host's own quiz ([quizId]). Rooms made before
  /// 2026-10-17 have none, and [questionIds] is the order.
  final List<String> items;
  final String? quizId;
  final RoomMode mode;

  /// Seconds per question; 0 means no timer (the host reveals by hand).
  final int timeLimit;

  /// When the live question was shown, by the server's clock; the rules
  /// refuse an answer after [timeLimit] (and two seconds' grace).
  final DateTime? questionStartedAt;

  /// Running totals and runs of right answers, written by the host at
  /// each reveal, so every phone can show its score and place.
  final Map<String, int> scores;
  final Map<String, int> streaks;

  /// The room's questions in order, as items, whatever its age.
  List<String> get order =>
      items.isNotEmpty ? items : [for (final id in questionIds) 'b:$id'];

  int get questionCount => order.length;

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

  bool get isLast => index >= questionCount - 1;

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
      items: asStringList(d['items']),
      quizId: asStringOrNull(d['quizId']),
      mode: RoomMode.parse(d['mode']),
      timeLimit: asInt(d['timeLimit']),
      questionStartedAt: d['questionStartedAt'] is Timestamp
          ? (d['questionStartedAt'] as Timestamp).toDate()
          : null,
      scores: _intMap(d['scores']),
      streaks: _intMap(d['streaks']),
    );
  }
}

Map<String, int> _intMap(Object? raw) => raw is Map
    ? {for (final e in raw.entries) '${e.key}': asInt(e.value)}
    : const {};

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

/// The link a host shares: the join screen with the code filled in.
String roomJoinPath(String code) => '/join?code=$code';

/// The code a shared link carries, or '' when it has none or it cannot
/// be a code (the box then starts empty, as if typed by hand).
String roomCodeFromLink(String? raw) =>
    raw == null ? '' : normaliseRoomCode(raw) ?? '';

/// Where `/rooms/:code` (or `/rooms/:code/host`, [pattern]) should go
/// instead, or null to stay. A code from the address bar skips the join
/// screen's checks and names a Firestore document, so anything that
/// cannot be a code goes to /join, and a code typed in lower case or with
/// a dash is tidied to its canonical form. Built from the route's pattern,
/// never the address, so it can never redirect to itself.
String? roomPathRedirect(String raw, String pattern) {
  final code = normaliseRoomCode(raw);
  if (code == null) return '/join';
  if (code == raw) return null;
  return pattern.replaceFirst(':code', code);
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

// ─── Speed scoring (2026-10-17) ───────────────────────────────────────

const kSpeedMaxPoints = 1000;
const kSpeedMinPoints = 500;
const kStreakStep = 100;
const kStreakCap = 500;

/// The time limits a host can choose, in seconds.
const kRoomTimeLimits = [10, 20, 30, 60, 90];

/// A right answer's points in a speed room: [kSpeedMaxPoints] at once,
/// falling in a straight line to [kSpeedMinPoints] at the time limit.
/// Measured from the server's clock at both ends, so a phone's clock
/// changes nothing.
int speedPoints(Duration elapsed, int limitSeconds) {
  if (limitSeconds <= 0) return kSpeedMaxPoints;
  final f = (elapsed.inMilliseconds / (limitSeconds * 1000)).clamp(0.0, 1.0);
  return (kSpeedMaxPoints - (kSpeedMaxPoints - kSpeedMinPoints) * f).round();
}

/// The bonus for the [run]-th right answer in a row: nothing for the
/// first, then [kStreakStep] more each time, up to [kStreakCap].
int streakBonus(int run) =>
    run <= 1 ? 0 : ((run - 1) * kStreakStep).clamp(0, kStreakCap);

typedef TimedAnswer = ({String uid, int index, int selected, DateTime? at});

/// The scores and runs after question [index]: what the host writes at
/// the reveal. A player with no answer, or a wrong one, loses their run.
/// Answers from anyone not in [players] are ignored. Pure.
({Map<String, int> scores, Map<String, int> streaks}) scoreQuestion({
  required Map<String, int> scores,
  required Map<String, int> streaks,
  required Iterable<String> players,
  required Iterable<TimedAnswer> answers,
  required int index,
  required int correctIndex,
  required RoomMode mode,
  required int timeLimit,
  DateTime? startedAt,
}) {
  final byUid = {
    for (final a in answers)
      if (a.index == index) a.uid: a,
  };
  final nextScores = <String, int>{};
  final nextStreaks = <String, int>{};
  for (final p in players) {
    final a = byUid[p];
    final right = a != null && a.selected == correctIndex;
    final run = right ? (streaks[p] ?? 0) + 1 : 0;
    var gained = 0;
    if (right) {
      if (mode == RoomMode.classic) {
        gained = 1;
      } else {
        final elapsed = (a.at != null && startedAt != null)
            ? a.at!.difference(startedAt)
            : Duration.zero;
        gained = speedPoints(elapsed, timeLimit) + streakBonus(run);
      }
    }
    nextScores[p] = (scores[p] ?? 0) + gained;
    nextStreaks[p] = run;
  }
  return (scores: nextScores, streaks: nextStreaks);
}

/// What a phone shows after a reveal: the points just earned.
int pointsEarned(Map<String, int> before, Map<String, int> after, String uid) =>
    (after[uid] ?? 0) - (before[uid] ?? 0);
