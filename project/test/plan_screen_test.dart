import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/plan_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/features/plan/plan_screen.dart';

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
}
