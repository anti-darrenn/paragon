import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/learn/topic_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/features/topic_test_screen.dart';
import 'package:paragon/features/waec_exam_screen.dart';

const _questions = [
  Question(
    id: 'q1',
    topicId: 't1',
    subjectId: 's1',
    text: 'First question',
    options: ['alpha', 'beta', 'gamma', 'delta'],
    correctIndex: 0,
    explanation: '',
    source: 'drill',
  ),
  Question(
    id: 'q2',
    topicId: 't1',
    subjectId: 's1',
    text: 'Second question',
    options: ['one', 'two', 'three', 'four'],
    correctIndex: 1,
    explanation: '',
    source: 'drill',
  ),
];

/// Starts on a home page, then pushes [path] — so there is somewhere for
/// back to go, exactly as in the app.
Future<void> _pumpFrom(WidgetTester tester, String path) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home')),
      GoRoute(
        path: '/test',
        builder: (_, _) =>
            const TopicTestScreen(subjectId: 's1', unitId: 'u1', topicId: 't1'),
      ),
      GoRoute(
        path: '/exam',
        builder: (_, _) => const WaecExamScreen(
          subjectId: 's1',
          session: WaecExamSessionData(
            questions: _questions,
            timerEnabled: false,
            timerDurationMinutes: 0,
          ),
        ),
      ),
      GoRoute(
        path: '/waec/:subjectId/setup',
        builder: (_, _) => const Text('setup'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topicTestQuestionsProvider.overrideWith((ref, id) async => _questions),
        topicTestProgressProvider.overrideWith(
          (ref) => Stream.value(TopicTestProgress.empty),
        ),
        isGuestProvider.overrideWithValue(false),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(path);
  await tester.pumpAndSettle();
}

/// The Android back button, as the framework delivers it.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('topic test', () {
    testWidgets('control: back before answering leaves with no dialog', (
      tester,
    ) async {
      await _pumpFrom(tester, '/test');
      await _systemBack(tester);

      expect(find.text('Leave the test?'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('back after answering asks first, and Keep going stays', (
      tester,
    ) async {
      await _pumpFrom(tester, '/test');
      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();

      await _systemBack(tester);
      expect(find.text('Leave the test?'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the test?'), findsNothing);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('Leave goes back once, without asking again', (tester) async {
      await _pumpFrom(tester, '/test');
      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();

      await _systemBack(tester);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Leave the test?'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('WAEC exam', () {
    testWidgets('back mid-exam shows the exit dialog instead of leaving', (
      tester,
    ) async {
      await _pumpFrom(tester, '/exam');
      await _systemBack(tester);

      expect(find.text('Exit exam?'), findsOneWidget);
      expect(find.text('home'), findsNothing);

      await tester.tap(find.text('Keep Going'));
      await tester.pumpAndSettle();
      expect(find.text('Exit exam?'), findsNothing);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('Exit Exam from the back dialog leaves the exam', (
      tester,
    ) async {
      await _pumpFrom(tester, '/exam');
      await _systemBack(tester);
      await tester.tap(find.text('Exit Exam'));
      await tester.pumpAndSettle();

      expect(find.text('setup'), findsOneWidget);
    });
  });
}
