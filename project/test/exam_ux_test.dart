import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/exam/exam_formats.dart';
import 'package:paragon/core/exam/saved_exam.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/exam_result_repository.dart';
import 'package:paragon/features/waec_exam_screen.dart';

class _User implements User {
  @override
  String get uid => 'u1';
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryStore implements SavedExamStore {
  final saved = <String, SavedExam>{};
  int saves = 0;

  @override
  Future<SavedExam?> load(String uid, String subjectId) async =>
      saved['$uid/$subjectId'];
  @override
  Future<void> save(String uid, SavedExam exam) async {
    saves++;
    saved['$uid/${exam.subjectId}'] = exam;
  }

  @override
  Future<void> clear(String uid, String subjectId) async =>
      saved.remove('$uid/$subjectId');
}

Question _q(String id, int year) => Question(
  id: id,
  topicId: 't1',
  subjectId: 's1',
  text: 'Question $id',
  options: const ['alpha', 'beta', 'gamma', 'delta'],
  correctIndex: 1,
  explanation: '',
  source: 'waec',
  year: year,
);

final _questions = [_q('q1', 2018), _q('q2', 2019), _q('q3', 2020)];

SavedExam _saved({Map<int, int>? answers, DateTime? savedAt}) => SavedExam(
  subjectId: 's1',
  questions: _questions,
  answers: answers ?? {0: 1, 2: 3},
  flagged: {2},
  currentIndex: 2,
  timerEnabled: true,
  timerMinutes: 60,
  remainingSeconds: 1234,
  startedAt: DateTime(2026, 10, 14, 9),
  savedAt: savedAt ?? DateTime(2026, 10, 14, 9, 20),
);

void main() {
  group('SavedExam', () {
    test('round-trips through JSON, questions included', () {
      final back = SavedExam.fromJson(_saved().toJson())!;
      expect(back.answers, {0: 1, 2: 3});
      expect(back.flagged, {2});
      expect(back.currentIndex, 2);
      expect(back.remainingSeconds, 1234);
      expect(back.questions.map((q) => q.id), ['q1', 'q2', 'q3']);
      expect(back.questions.first.year, 2018);
      expect(back.questions.first.correctIndex, 1);
    });

    test('control: a corrupt or out-of-range save is dropped, not resumed', () {
      final json = _saved().toJson();
      expect(SavedExam.fromJson({...json, 'v': 2}), isNull);
      expect(SavedExam.fromJson({...json, 'questions': []}), isNull);
      expect(
        SavedExam.fromJson({
          ...json,
          'answers': {'7': 0},
        }),
        isNull,
      );
      expect(
        SavedExam.fromJson({
          ...json,
          'answers': {'0': 9},
        }),
        isNull,
      );
      expect(SavedExam.fromJson({'v': 1}), isNull);
    });

    test('older than a day is stale', () {
      final s = _saved();
      expect(s.isStale(DateTime(2026, 10, 15, 9)), isFalse);
      expect(s.isStale(DateTime(2026, 10, 15, 9, 21)), isTrue);
    });
  });

  test('summary and next-matching', () {
    final s = examSummary(total: 5, answers: {0: 1, 3: 0}, flagged: {3, 4});
    expect((s.answered, s.unanswered, s.flagged), (2, 3, 2));
    expect(nextMatching(5, 0, (i) => i == 3), 3);
    expect(nextMatching(5, 4, (i) => i == 1), 1); // wraps
    expect(nextMatching(5, 0, (i) => false), isNull);
  });

  test('exam formats', () {
    expect(examFormatFor('Mathematics').questions, 50);
    expect(examFormatFor('  further mathematics ').questions, 40);
    expect(examFormatFor('Unknown subject'), kDefaultExamFormat);
    expect(formatMinutes(90), '1 h 30 min');
    expect(formatMinutes(60), '1 h');
    expect(formatMinutes(45), '45 min');
    // Not confirmed yet, and the setup screen says so.
    expect(kExamFormats.values.every((f) => !f.verified), isTrue);
  });

  group('the exam screen', () {
    late _MemoryStore store;

    Future<void> pump(WidgetTester tester, WaecExamSessionData session) async {
      store = _MemoryStore();
      final db = FakeFirebaseFirestore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
            examResultRepositoryProvider.overrideWithValue(
              ExamResultRepository(db),
            ),
            currentUserProvider.overrideWithValue(_User()),
            isGuestProvider.overrideWithValue(false),
            savedExamStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: WaecExamScreen(subjectId: 's1', session: session),
          ),
        ),
      );
      await tester.pump();
    }

    Finder strip(int n, String state) =>
        find.bySemanticsLabel('Question $n, $state');

    testWidgets('keyboard answers, flags and moves; the strip says so', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        WaecExamSessionData(
          questions: _questions,
          timerEnabled: false,
          timerDurationMinutes: 0,
        ),
      );
      expect(strip(1, 'not answered, current'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(strip(1, 'answered, flagged, current'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Option B: beta')),
        matchesSemantics(
          label: 'Option B: beta',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          // One answer per question: a screen reader says "1 of 4".
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(strip(2, 'not answered, current'), findsOneWidget);
      expect(strip(1, 'answered, flagged'), findsOneWidget);

      // Saved to the device half a second after the last change.
      await tester.pump(const Duration(milliseconds: 600));
      final saved = store.saved['u1/s1']!;
      expect(saved.answers, {0: 1});
      expect(saved.flagged, {0});
      expect(saved.currentIndex, 1);
      handle.dispose();
    });

    testWidgets('the end of the paper shows the summary, then submit clears '
        'the saved exam', (tester) async {
      await pump(
        tester,
        WaecExamSessionData(
          questions: _questions,
          timerEnabled: false,
          timerDurationMinutes: 0,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Submit exam?'), findsOneWidget);
      expect(find.text('Flagged for review'), findsOneWidget);
      expect(find.text('Go to unanswered'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(store.saved, isNotEmpty);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Exam Complete'), findsOneWidget);
      expect(store.saved, isEmpty);
    });

    testWidgets('resuming restores answers, flags, place and clock', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, WaecExamSessionData.resuming(_saved()));
      expect(strip(3, 'answered, flagged, current'), findsOneWidget);
      expect(strip(1, 'answered'), findsOneWidget);
      expect(strip(2, 'not answered'), findsOneWidget);
      expect(find.text('20:34'), findsOneWidget);
      handle.dispose();
    });
  });
}
