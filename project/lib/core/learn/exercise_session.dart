import '../models/question.dart';

/// The rules of one in-lesson exercise set, kept out of the widget so they
/// can be tested without pumping one.
///
/// Khan-style: check an answer, get told at once; a wrong answer may be
/// tried again once, and a second miss reveals the right option. Only the
/// **first** try on each question is scored and recorded — retrying until
/// something turns green is learning, not evidence of knowing it.
///
/// Questions arriving here all have a verified answer (the providers
/// filter `hasAnswer`), but a `correctIndex` outside the options is still
/// treated as unanswerable rather than trusted: such a question is skipped
/// by [check] marking it revealed, never scored.
enum ExerciseStep { answering, retrying, correct, revealed, finished }

typedef FirstTry = ({String questionId, int selectedIndex, bool isCorrect});

class ExerciseSession {
  ExerciseSession(this.questions)
    : _step = questions.isEmpty ? ExerciseStep.finished : ExerciseStep.answering;

  static const int triesBeforeReveal = 2;

  final List<Question> questions;

  int _index = 0;
  int? _selected;
  int _tries = 0;
  final Set<int> _wrong = {};
  final List<FirstTry> _firstTries = [];
  ExerciseStep _step;

  int get index => _index;
  ExerciseStep get step => _step;
  int? get selected => _selected;

  /// Options already tried and wrong on the current question.
  Set<int> get wrongOptions => Set.unmodifiable(_wrong);

  List<FirstTry> get firstTries => List.unmodifiable(_firstTries);

  Question? get current =>
      _step == ExerciseStep.finished ? null : questions[_index];

  bool get isFinished => _step == ExerciseStep.finished;

  int get firstTryCorrect => _firstTries.where((t) => t.isCorrect).length;

  bool get canCheck =>
      _selected != null &&
      (_step == ExerciseStep.answering || _step == ExerciseStep.retrying);

  bool _validAnswer(Question q) =>
      q.correctIndex >= 0 && q.correctIndex < q.options.length;

  void select(int option) {
    final q = current;
    if (q == null) return;
    if (_step != ExerciseStep.answering && _step != ExerciseStep.retrying) {
      return;
    }
    if (option < 0 || option >= q.options.length || _wrong.contains(option)) {
      return;
    }
    _selected = option;
  }

  void check() {
    final q = current;
    if (q == null || !canCheck) return;
    if (!_validAnswer(q)) {
      _step = ExerciseStep.revealed;
      return;
    }
    final picked = _selected!;
    final right = picked == q.correctIndex;
    _tries++;
    if (_tries == 1) {
      _firstTries.add((questionId: q.id, selectedIndex: picked, isCorrect: right));
    }
    if (right) {
      _step = ExerciseStep.correct;
    } else if (_tries >= triesBeforeReveal) {
      _step = ExerciseStep.revealed;
    } else {
      _wrong.add(picked);
      _selected = null;
      _step = ExerciseStep.retrying;
    }
  }

  void next() {
    if (_step != ExerciseStep.correct && _step != ExerciseStep.revealed) return;
    _index++;
    _selected = null;
    _tries = 0;
    _wrong.clear();
    _step = _index >= questions.length
        ? ExerciseStep.finished
        : ExerciseStep.answering;
  }
}
