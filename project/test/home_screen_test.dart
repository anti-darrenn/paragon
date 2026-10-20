import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/plan/planner.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/plan_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/dashboard_screen.dart';
import 'package:paragon/features/lesson/continue_learning.dart';
import 'package:paragon/features/study/planner/planner_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home (redesigned 2026-10-19): a greeting with the date and the tip of
/// the day, today's plan, and places to jump in. No counters of
/// questions answered.
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    double width = 1280,
    PlanSettings plan = PlanSettings.none,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        userDataProvider.overrideWith(
          (ref) => Stream.value({'displayName': 'Ada'}),
        ),
        currentUserProvider.overrideWithValue(null),
        isGuestProvider.overrideWithValue(false),
        continueLearningProvider.overrideWithValue(null),
        continueLearningLoadingProvider.overrideWithValue(false),
        selectedSubjectSlugsProvider.overrideWithValue(const {}),
        courseCatalogProvider.overrideWith((ref) async => const []),
        userProgressProvider.overrideWithValue(
          const AsyncData(UserProgress.empty),
        ),
        planSettingsProvider.overrideWithValue(AsyncData(plan)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('greets by name, with the tip of the day', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('home.hero')), findsOneWidget);
    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining(tipFor(DateTime.now())), findsOneWidget);
    expect(find.byKey(const ValueKey('home.today')), findsOneWidget);
    expect(find.text('Jump in'), findsOneWidget);
  });

  testWidgets('no counters of questions answered (owner, 2026-10-19)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Topics practised'), findsNothing);
    expect(find.text('Questions this week'), findsNothing);
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('counts down to the exam once a date is set', (tester) async {
    final now = DateTime.now();
    await pump(
      tester,
      plan: PlanSettings(examDate: DateTime(now.year, now.month, now.day + 5)),
    );
    expect(find.text('5 days to your exam'), findsOneWidget);
  });

  testWidgets("today's plan can be ticked off from Home", (tester) async {
    final container = await pump(tester, width: 420);
    await container
        .read(plannerProvider.notifier)
        .add(
          PlannerTask(
            id: 't1',
            day: dayKey(DateTime.now()),
            title: 'Indices',
            subject: 'Mathematics',
            minutes: 30,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 done'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home.today.t1')));
    await tester.pumpAndSettle();
    expect(find.text('All done. Brilliant.'), findsOneWidget);
  });
}
