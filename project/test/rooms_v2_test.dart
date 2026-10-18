import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/rooms/quiz_history.dart';
import 'package:paragon/core/rooms/room.dart';
import 'package:paragon/core/rooms/teacher_quiz.dart';
import 'package:paragon/features/rooms/new_room_screen.dart';

/// Live quiz rooms v2 (owner's request, 2026-10-17): Kahoot-style speed
/// scoring, a timer, many topics or a host's own quiz, and history.
void main() {
  final start = DateTime(2026, 10, 18, 9);

  group('speed points', () {
    test('1000 at once, 500 at the time limit, a straight line between', () {
      expect(speedPoints(Duration.zero, 20), 1000);
      expect(speedPoints(const Duration(seconds: 10), 20), 750);
      expect(speedPoints(const Duration(seconds: 20), 20), 500);
    });
    test('never below 500 for a right answer, even late', () {
      expect(speedPoints(const Duration(seconds: 25), 20), 500);
    });
    test('a run of right answers earns a capped bonus', () {
      expect(streakBonus(1), 0);
      expect(streakBonus(2), 100);
      expect(streakBonus(6), 500);
      expect(streakBonus(20), 500);
    });
  });

  group('scoreQuestion', () {
    TimedAnswer ans(String uid, int selected, int ms) => (
      uid: uid,
      index: 0,
      selected: selected,
      at: start.add(Duration(milliseconds: ms)),
    );

    test('speed: faster right answers score more; wrong and silent score 0', () {
      final r = scoreQuestion(
        scores: const {},
        streaks: const {},
        players: ['fast', 'slow', 'wrong', 'quiet'],
        answers: [ans('fast', 2, 1000), ans('slow', 2, 15000), ans('wrong', 1, 500)],
        index: 0,
        correctIndex: 2,
        mode: RoomMode.speed,
        timeLimit: 20,
        startedAt: start,
      );
      expect(r.scores['fast']! > r.scores['slow']!, isTrue);
      expect(r.scores['wrong'], 0);
      expect(r.scores['quiet'], 0);
      expect(r.streaks['fast'], 1);
      expect(r.streaks['wrong'], 0);
    });

    test('a second right answer in a row carries the bonus', () {
      final r = scoreQuestion(
        scores: const {'a': 1000},
        streaks: const {'a': 1},
        players: ['a'],
        answers: [ans('a', 0, 0)],
        index: 0,
        correctIndex: 0,
        mode: RoomMode.speed,
        timeLimit: 20,
        startedAt: start,
      );
      expect(r.scores['a'], 1000 + 1000 + 100);
      expect(r.streaks['a'], 2);
    });

    test('a wrong answer ends the run', () {
      final r = scoreQuestion(
        scores: const {'a': 2100},
        streaks: const {'a': 2},
        players: ['a'],
        answers: [ans('a', 3, 0)],
        index: 0,
        correctIndex: 0,
        mode: RoomMode.speed,
        timeLimit: 20,
        startedAt: start,
      );
      expect(r.scores['a'], 2100);
      expect(r.streaks['a'], 0);
    });

    test('CONTROL: classic is one point a right answer, whatever the time', () {
      final r = scoreQuestion(
        scores: const {},
        streaks: const {},
        players: ['fast', 'slow'],
        answers: [ans('fast', 2, 100), ans('slow', 2, 19000)],
        index: 0,
        correctIndex: 2,
        mode: RoomMode.classic,
        timeLimit: 20,
        startedAt: start,
      );
      expect(r.scores, {'fast': 1, 'slow': 1});
    });

    test('someone who never joined scores nothing', () {
      final r = scoreQuestion(
        scores: const {},
        streaks: const {},
        players: ['a'],
        answers: [ans('ghost', 2, 0)],
        index: 0,
        correctIndex: 2,
        mode: RoomMode.speed,
        timeLimit: 20,
        startedAt: start,
      );
      expect(r.scores.containsKey('ghost'), isFalse);
    });
  });

  group('the room order', () {
    test('Paragon questions then the quiz, mixed, capped at 30', () {
      final order = roomOrder(
        bankIds: [for (var i = 0; i < 25; i++) 'q$i'],
        quizCount: 10,
      );
      expect(order, hasLength(30));
      expect(order.where((i) => i.startsWith('q:')), isNotEmpty);
    });
    test('an old room with only questionIds keeps its order', () {
      const room = Room(
        code: 'ABC234',
        hostUid: 'h',
        subjectId: 's',
        topicId: 't',
        topicName: 'Indices',
        questionIds: ['x', 'y'],
        state: RoomState.lobby,
        index: 0,
      );
      expect(room.order, ['b:x', 'b:y']);
      expect(room.questionCount, 2);
    });
  });

  group('a host\'s quiz', () {
    test('only complete questions are playable', () {
      const quiz = TeacherQuiz(
        id: 'q',
        title: 'Indices',
        questions: [
          QuizQuestion(text: '2^3?', options: ['6', '8'], correctIndex: 1),
          QuizQuestion(text: '', options: ['a', 'b'], correctIndex: 0),
          QuizQuestion(text: 'x', options: ['a', ''], correctIndex: 0),
          QuizQuestion(text: 'y', options: ['a', 'b'], correctIndex: -1),
        ],
      );
      expect(quiz.playable, hasLength(1));
      final q = quiz.asQuestion(0);
      expect(q.id, 'q:0');
      expect(q.provenanceLabel, 'From your quiz host');
    });
  });

  group('history', () {
    QuizHistoryEntry e({String role = 'player', int place = 1, int players = 3}) =>
        QuizHistoryEntry(
          roomCode: 'ABC234',
          title: 'Indices',
          role: role,
          score: 900,
          place: place,
          players: players,
          total: 10,
          mode: RoomMode.speed,
        );

    test('wins, games and rooms hosted', () {
      final t = historyTotals([
        e(),
        e(place: 2),
        e(role: 'host', place: 0),
        e(players: 1), // alone: not a win
      ]);
      expect(t.games, 3);
      expect(t.wins, 1);
      expect(t.hosted, 1);
    });
  });
}
