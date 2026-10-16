import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/plan_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/plan/plan_screen.dart';
import 'package:paragon/core/widgets/ui/ui.dart';
import 'package:paragon/features/plan/plan_widgets.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool guest = false,
    PlanSettings plan = PlanSettings.none,
    int thisWeek = 0,
    bool counting = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        isGuestProvider.overrideWithValue(guest),
        planSettingsProvider.overrideWithValue(AsyncData(plan)),
        weeklyAttemptsCountProvider.overrideWithValue(
          counting ? const AsyncLoading() : AsyncData(thisWeek),
        ),
        userProgressProvider.overrideWithValue(
          const AsyncData(UserProgress.empty),
        ),
        selectedSubjectSlugsProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );

  testWidgets('a guest is offered an account, not a plan', (tester) async {
    await pump(tester, const PlanScreen(), guest: true);
    expect(find.text('Make an account'), findsOneWidget);
    expect(find.text('Weekly goal'), findsNothing);
  });

  testWidgets('control: an account sees the goal, the exam and the subjects '
      'prompt', (tester) async {
    await pump(tester, const PlanScreen());
    expect(find.text('Weekly goal'), findsOneWidget);
    expect(find.text('100 a week'), findsOneWidget);
    expect(find.text('When is your first WASSCE paper?'), findsOneWidget);
    expect(find.text('Choose subjects'), findsOneWidget);
  });

  testWidgets('the Home card counts toward the goal and the exam', (
    tester,
  ) async {
    final exam = DateTime.now().add(const Duration(days: 70));
    await pump(
      tester,
      const ThisWeekCard(),
      plan: PlanSettings(weeklyGoal: 50, examDate: exam),
      thisWeek: 20,
    );
    expect(find.text('20 of 50 questions · 30 to go'), findsOneWidget);
    expect(find.text('10 weeks to your exam'), findsOneWidget);

    await pump(
      tester,
      const ThisWeekCard(),
      plan: const PlanSettings(weeklyGoal: 50),
      thisWeek: 55,
    );
    expect(find.textContaining('Goal met'), findsOneWidget);
    expect(find.text('Set your exam date to plan your weeks'), findsOneWidget);
  });

  testWidgets('a guest sees no Home card', (tester) async {
    await pump(tester, const ThisWeekCard(), guest: true);
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('Plan v2 7.3: no "0 of 50" before the count arrives', (
    tester,
  ) async {
    await pump(
      tester,
      const ThisWeekCard(),
      plan: const PlanSettings(weeklyGoal: 50),
      counting: true,
    );
    expect(find.textContaining('0 of 50'), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
    // CONTROL: a real zero is shown as zero.
    await pump(
      tester,
      const ThisWeekCard(),
      plan: const PlanSettings(weeklyGoal: 50),
    );
    expect(find.text('0 of 50 questions · 50 to go'), findsOneWidget);
  });
}
