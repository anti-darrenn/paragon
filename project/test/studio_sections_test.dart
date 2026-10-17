import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/core/repositories/admin_resource_repository.dart';
import 'package:paragon/core/repositories/flag_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/features/admin/admin_home_screen.dart';
import 'package:paragon/features/admin/studio/launch_panels.dart';

/// The studio's sections: who sees which, and the overview's counts.
void main() {
  Future<void> pump(WidgetTester tester, StaffRole role) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        GoRoute(
          path: '/admin',
          builder: (_, s) =>
              AdminHomeScreen(section: s.uri.queryParameters['s']),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          staffAccessProvider.overrideWithValue(StaffAccess(role)),
          adminStatusQueueProvider.overrideWith((ref, s) async => const []),
          adminFlagQueueProvider.overrideWith(
            (ref) async => [
              const FlaggedQuestion(
                questionId: 'q1',
                reports: [
                  ProblemReport(
                    id: 'f1',
                    questionId: 'q1',
                    reason: FlagReason.wrongAnswer,
                    status: FlagStatus.open,
                  ),
                ],
              ),
            ],
          ),
          adminLessonReportsProvider.overrideWith((ref) async => const []),
          contentAuditProvider.overrideWith(
            (ref) async => ContentAudit.fromDocument({
              'total': 4206,
              'rules': {
                'recurring-decimal-suspect': {'level': 'S', 'count': 1},
                'equivalent-options': {'level': 'A', 'count': 2},
                'missing-explanation': {'level': 'B', 'count': 923},
              },
            }),
          ),
          subjectsProvider.overrideWith((ref) async => const []),
          userDataProvider.overrideWith((ref) => Stream.value(null)),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a reviewer sees every section and what needs them', (
    tester,
  ) async {
    await pump(tester, StaffRole.reviewer);
    for (final s in StudioSection.values) {
      expect(find.text(s.label), findsWidgets, reason: s.label);
    }
    // The overview's counts, from lists the studio loads anyway.
    expect(find.text('Questions students reported'), findsOneWidget);
    expect(find.text('Answers that may be wrong'), findsOneWidget);
    expect(find.text('923'), findsOneWidget);
    expect(find.text('Waiting for your review'), findsOneWidget);
  });

  testWidgets('CONTROL: a writer sees only lessons and questions', (
    tester,
  ) async {
    await pump(tester, StaffRole.writer);
    expect(find.text('Questions'), findsWidgets);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Quality'), findsNothing);
    expect(find.text('Answers that may be wrong'), findsNothing);
  });

  test('a section is its own address; anything else is the overview', () {
    expect(StudioSection.parse('quality'), StudioSection.quality);
    expect(StudioSection.parse('nope'), StudioSection.overview);
    expect(StudioSection.parse(null), StudioSection.overview);
  });
}
