import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';

/// A WAEC exam in progress, kept **on the device** so a dropped connection,
/// a closed tab or a dead battery doesn't throw away forty minutes of work
/// (PLAN.md P5.2.4).
///
/// On the device, not in Firestore: saving each answer to Firestore would
/// cost a write per tap against Spark's 20,000 a day. The questions are
/// stored too, so resuming needs no reads and works offline. One exam per
/// student per subject; a newer one replaces it. Nothing here is uploaded
/// or reaches `attempts` until the exam is submitted, as before.
class SavedExam {
  const SavedExam({
    required this.subjectId,
    required this.questions,
    required this.answers,
    required this.flagged,
    required this.currentIndex,
    required this.timerEnabled,
    required this.timerMinutes,
    required this.remainingSeconds,
    required this.startedAt,
    required this.savedAt,
  });

  final String subjectId;
  final List<Question> questions;
  final Map<int, int> answers;
  final Set<int> flagged;
  final int currentIndex;
  final bool timerEnabled;
  final int timerMinutes;
  final int remainingSeconds;
  final DateTime startedAt;
  final DateTime savedAt;

  /// Older than this and a resume would be a different sitting.
  static const maxAge = Duration(hours: 24);

  bool isStale(DateTime now) => now.difference(savedAt) > maxAge;

  int get answeredCount => answers.length;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'subjectId': subjectId,
    'questions': [for (final q in questions) q.toJson()],
    'answers': {for (final e in answers.entries) '${e.key}': e.value},
    'flagged': flagged.toList()..sort(),
    'currentIndex': currentIndex,
    'timerEnabled': timerEnabled,
    'timerMinutes': timerMinutes,
    'remainingSeconds': remainingSeconds,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  /// Null for anything unreadable, empty, or out of range — a bad save is
  /// dropped, never resumed into a broken exam.
  static SavedExam? fromJson(Map<String, dynamic> d) {
    try {
      if (d['v'] != 1) return null;
      final questions = [
        for (final q in d['questions'] as List)
          Question.fromJson((q as Map).cast<String, dynamic>()),
      ];
      if (questions.isEmpty) return null;
      final answers = <int, int>{};
      for (final e in (d['answers'] as Map).entries) {
        final i = int.parse('${e.key}');
        final a = e.value as int;
        if (i < 0 || i >= questions.length) return null;
        if (a < 0 || a >= questions[i].options.length) return null;
        answers[i] = a;
      }
      final flagged = {for (final f in d['flagged'] as List) f as int}
        ..removeWhere((i) => i < 0 || i >= questions.length);
      return SavedExam(
        subjectId: d['subjectId'] as String,
        questions: questions,
        answers: answers,
        flagged: flagged,
        currentIndex: ((d['currentIndex'] as int?) ?? 0).clamp(
          0,
          questions.length - 1,
        ),
        timerEnabled: d['timerEnabled'] as bool,
        timerMinutes: d['timerMinutes'] as int,
        remainingSeconds: d['remainingSeconds'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(d['startedAt'] as int),
        savedAt: DateTime.fromMillisecondsSinceEpoch(d['savedAt'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where a [SavedExam] lives. An interface so tests run without the plugin.
abstract class SavedExamStore {
  Future<SavedExam?> load(String uid, String subjectId);
  Future<void> save(String uid, SavedExam exam);
  Future<void> clear(String uid, String subjectId);
}

class PrefsSavedExamStore implements SavedExamStore {
  const PrefsSavedExamStore();

  String _key(String uid, String subjectId) =>
      'waec_exam_in_progress:$uid:$subjectId';

  @override
  Future<SavedExam?> load(String uid, String subjectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid, subjectId));
      if (raw == null) return null;
      final exam = SavedExam.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      if (exam == null || exam.isStale(DateTime.now())) {
        await prefs.remove(_key(uid, subjectId));
        return null;
      }
      return exam;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String uid, SavedExam exam) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(uid, exam.subjectId),
        jsonEncode(exam.toJson()),
      );
    } catch (_) {
      // Saving is a safety net; failing to only loses the net.
    }
  }

  @override
  Future<void> clear(String uid, String subjectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid, subjectId));
    } catch (_) {}
  }
}

/// What the pre-submit summary counts.
({int answered, int unanswered, int flagged}) examSummary({
  required int total,
  required Map<int, int> answers,
  required Set<int> flagged,
}) => (
  answered: answers.length,
  unanswered: total - answers.length,
  flagged: flagged.length,
);

/// The first question at or after [from] (wrapping) that matches [test],
/// or null — for "go to the next unanswered / flagged question".
int? nextMatching(int total, int from, bool Function(int) test) {
  for (var k = 0; k < total; k++) {
    final i = (from + k) % total;
    if (test(i)) return i;
  }
  return null;
}

/// The store the exam screens use; tests override it.
final savedExamStoreProvider = Provider<SavedExamStore>(
  (ref) => const PrefsSavedExamStore(),
);
