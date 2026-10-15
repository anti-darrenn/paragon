import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/exam/saved_exam.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/providers/analytics_provider.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';
import 'package:paragon/core/repositories/exam_result_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/features/waec_exam_screen.dart';
import 'package:paragon/features/waec_exam_setup_screen.dart';
import 'package:paragon/features/waec_subject_screen.dart';

// ignore: subtype_of_sealed_class
class _Guest implements User {
  @override
  String get uid => 'guest-1';
  @override
  bool get isAnonymous => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStore implements SavedExamStore {
  @override
  Future<SavedExam?> load(String uid, String subjectId) async => null;
  @override
  Future<void> save(String uid, SavedExam exam) async {}
  @override
  Future<void> clear(String uid, String subjectId) async {}
}

Question _q(String id) => Question(
  id: id,
  topicId: 't1',
  subjectId: 's1',
  text: 'Question $id',
  options: const ['alpha', 'beta', 'gamma', 'delta'],
  correctIndex: 1,
  explanation: '',
  source: 'waec',
  year: 2019,
);

/// Audit A1 (2026-10-15): a guest pressing Start Exam was reported as
/// thrown to /welcome. Guests may sit untimed papers in every subject
/// (`canUse(Feature.waecUntimed)`), so Start must reach question 1.
void main() {
  Future<GoRouter> pumpSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final router = GoRouter(
      initialLocation: '/waec/s1/setup',
      routes: [
        GoRoute(
          path: '/waec/:subjectId/setup',
          builder: (_, s) =>
              WaecExamSetupScreen(subjectId: s.pathParameters['subjectId']!),
        ),
        GoRoute(
          path: '/waec/:subjectId/exam',
          builder: (_, s) => WaecExamScreen(
            subjectId: s.pathParameters['subjectId']!,
            session: s.extra is WaecExamSessionData
                ? s.extra as WaecExamSessionData
                : null,
          ),
        ),
        GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
        GoRoute(
          path: '/account/upgrade',
          builder: (_, _) => const Text('UPGRADE'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_Guest()),
          isGuestProvider.overrideWithValue(true),
          subjectsProvider.overrideWith(
            (ref) async => const [
              Subject(id: 's1', name: 'Mathematics', unitCount: 1),
            ],
          ),
          waecYearRangeProvider.overrideWith((ref, id) async => (2015, 2024)),
          waecAvailableCountProvider.overrideWith((ref, q) async => 120),
          waecExamQuestionsProvider.overrideWith(
            (ref, config) async => [_q('q1'), _q('q2'), _q('q3')],
          ),
          examHistoryProvider.overrideWith((ref, s) async => const []),
          savedExamStoreProvider.overrideWithValue(_NoStore()),
          attemptRepositoryProvider.overrideWithValue(AttemptRepository(db)),
          examResultRepositoryProvider.overrideWithValue(
            ExamResultRepository(db),
          ),
          analyticsProvider.overrideWithValue(
            Analytics(
              instance: () => throw StateError('no analytics in tests'),
              isEnabled: () => false,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('a guest starts the full paper and sees question 1', (
    tester,
  ) async {
    final router = await pumpSetup(tester);
    expect(find.text('Full paper'), findsOneWidget);
    await tester.tap(find.text('Start Exam'));
    await tester.pumpAndSettle();
    expect(location(router), '/waec/s1/exam');
    expect(find.text('Question q1'), findsOneWidget);
    expect(find.text('WELCOME'), findsNothing);
  });

  testWidgets('the guest chip sits below Start and opens the upgrade page', (
    tester,
  ) async {
    await pumpSetup(tester);
    final chip = find.text('Make an account for timed exams');
    expect(chip, findsOneWidget);
    expect(
      tester.getTopLeft(chip).dy,
      greaterThan(tester.getTopLeft(find.text('Start Exam')).dy),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.text('WELCOME'), findsNothing);
  });

  group('WAEC Prep subject order (audit C6)', () {
    const maths = Subject(
      id: 'm',
      name: 'Mathematics',
      unitCount: 1,
      pastQuestionCount: 1702,
      practiceQuestionCount: 12900,
    );
    const chem = Subject(
      id: 'c',
      name: 'Chemistry',
      unitCount: 1,
      practiceQuestionCount: 300,
    );
    const physics = Subject(
      id: 'p',
      name: 'Physics',
      unitCount: 1,
      pastQuestionCount: 1762,
      practiceQuestionCount: 9000,
    );
    const unsplit = Subject(id: 'u', name: 'Biology', unitCount: 1);

    test('papers that can be sat come first, empty ones last', () {
      expect(
        waecSubjectOrder([chem, maths, unsplit, physics], true).map((s) => s.id),
        ['m', 'u', 'p', 'c'],
      );
    });

    test('control: nothing moves when every subject has papers', () {
      expect(
        waecSubjectOrder([physics, maths], false).map((s) => s.id),
        ['p', 'm'],
      );
    });
  });
}
