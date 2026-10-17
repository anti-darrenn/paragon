import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/core/repositories/admin_question_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/features/admin/admin_flag_screen.dart';
import 'package:paragon/features/admin/studio/launch_panels.dart';
import 'package:paragon/features/admin/studio/staff_profile.dart';

// ignore: subtype_of_sealed_class
class _Reviewer implements User {
  @override
  String get uid => 'rev';
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The question workbench: a reviewer edits and saves with a reason, and
/// the save carries its history record; anyone else reads only.
void main() {
  Future<FakeFirebaseFirestore> pump(
    WidgetTester tester, {
    StaffRole role = StaffRole.reviewer,
  }) async {
    tester.view.physicalSize = const Size(1500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await db.collection('questions').doc('q1').set({
      'subjectId': 's1',
      'topicId': 't1',
      'source': 'waec',
      'year': 2018,
      'hasAnswer': true,
      'text': 'Expression 0.612 in the form x/y',
      'options': ['153/250', '68/111', '61/100', '21/33'],
      'correctIndex': 0,
      'explanation': '612/1000 = 153/250',
    });
    final router = GoRouter(
      initialLocation: '/admin/question/q1',
      routes: [
        GoRoute(path: '/admin', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/admin/question/:id',
          builder: (_, s) =>
              AdminFlagScreen(questionId: s.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminFlagRepositoryProvider.overrideWithValue(
            AdminFlagRepository(db),
          ),
          adminQuestionRepositoryProvider.overrideWithValue(
            AdminQuestionRepository(db),
          ),
          staffAccessProvider.overrideWithValue(StaffAccess(role)),
          currentUserProvider.overrideWithValue(_Reviewer()),
          contentAuditProvider.overrideWith((ref) async => null),
          subjectsProvider.overrideWith((ref) async => const []),
          topicByIdProvider.overrideWith((ref, id) async => null),
          staffProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('a reviewer fixes a question; the save keeps its history', (
    tester,
  ) async {
    final db = await pump(tester);
    // Live checks see the 2018 typo before anything is typed.
    expect(
      find.text('"Expression" at the start probably means "Express".'),
      findsOneWidget,
    );
    expect(find.textContaining('No changes'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Express 0.612 in the form x/y',
    );
    // Mark B (68/111) as the answer.
    // A is marked, so the first "Mark as the answer" is B.
    // Once there are changes the save bar appears; it must not cover the
    // page (it did: a bottom bar's Center took the whole height).
    await tester.tap(find.byTooltip('Mark as the answer').first);
    await tester.pump();

    // No reason, no save.
    final save = find.widgetWithText(ElevatedButton, 'Say what you fixed');
    expect(save, findsOneWidget);
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'What did you fix? (kept in the history)'),
      'Typo, and the paper has recurring dots',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    final q = (await db.doc('questions/q1').get()).data()!;
    expect(q['text'], 'Express 0.612 in the form x/y');
    expect(q['correctIndex'], 1);
    final history = await db.collection('questions/q1/history').get();
    expect(history.docs, hasLength(1));
    expect(
      history.docs.single['reason'],
      'Typo, and the paper has recurring dots',
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('CONTROL: a writer sees the question but cannot edit it', (
    tester,
  ) async {
    await pump(tester, role: StaffRole.writer);
    expect(
      find.text('Read-only. Reviewers of this subject can edit questions.'),
      findsOneWidget,
    );
    expect(find.textContaining('No changes'), findsNothing);
    final stem = tester.widget<TextField>(find.byType(TextField).first);
    expect(stem.readOnly, isTrue);
  });
}
