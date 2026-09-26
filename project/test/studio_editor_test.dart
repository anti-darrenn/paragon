import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/models/topic.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/admin_resource_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/repositories/lesson_workflow.dart';
import 'package:paragon/features/admin/admin_resource_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _topic = Topic(
  id: 't1',
  unitId: 'u1',
  subjectId: 's1',
  name: 'Number bases',
  questionCount: 0,
  order: 1,
);

LearnResource _article(ResourceStatus status, {String? revisionOf}) =>
    LearnResource(
      id: 'a1',
      type: LearnResourceType.article,
      order: 1,
      title: 'What a base is',
      subjectId: 's1',
      topicId: 't1',
      body: 'Some text.',
      status: status,
      createdBy: 'someone-else',
      revisionOf: revisionOf,
    );

Future<List<String>> _buttons(
  WidgetTester tester, {
  required StaffRole role,
  required LearnResource resource,
  StaffAccess? access,
}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const AdminResourceEditorScreen(topicId: 't1', resourceId: 'a1'),
      ),
    ],
  );
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        staffAccessProvider.overrideWithValue(access ?? StaffAccess(role)),
        currentUserProvider.overrideWithValue(null),
        topicByIdProvider.overrideWith((ref, id) async => _topic),
        adminResourceProvider.overrideWith((ref, key) async => resource),
        adminTopicResourcesProvider.overrideWith((ref, id) async => [resource]),
        resourceCommentsProvider.overrideWith(
          (ref, key) => Stream.value(const <ReviewComment>[]),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  const labels = [
    'Delete',
    'Save',
    'Save draft',
    'Save changes',
    'Unpublish',
    'Start a revision',
    'Request changes',
    'Submit for review',
    'Publish',
    'Approve and publish',
    'Approve revision',
  ];
  return [
    for (final l in labels)
      if (find.text(l).evaluate().isNotEmpty) l,
  ];
}

void main() {
  testWidgets('a writer on a draft can save and submit, but not publish', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.writer,
      resource: _article(ResourceStatus.draft),
    );
    expect(b, containsAll(['Save', 'Submit for review']));
    expect(b, isNot(contains('Publish')));
    // Someone else's draft: a writer may not delete it.
    expect(b, isNot(contains('Delete')));
  });

  testWidgets('a writer on an item in review cannot approve', (tester) async {
    final b = await _buttons(
      tester,
      role: StaffRole.writer,
      resource: _article(ResourceStatus.inReview),
    );
    expect(b, contains('Save'));
    expect(b, isNot(contains('Approve and publish')));
    expect(b, isNot(contains('Request changes')));
  });

  testWidgets('a reviewer on an item in review can approve or send it back', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.reviewer,
      resource: _article(ResourceStatus.inReview),
    );
    expect(
      b,
      containsAll(['Approve and publish', 'Request changes', 'Delete']),
    );
  });

  testWidgets('a revision is approved as a revision', (tester) async {
    final b = await _buttons(
      tester,
      role: StaffRole.reviewer,
      resource: _article(ResourceStatus.inReview, revisionOf: 'orig'),
    );
    expect(b, contains('Approve revision'));
  });

  testWidgets('a writer on a published item can only start a revision', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.writer,
      resource: _article(ResourceStatus.published),
    );
    expect(b, ['Start a revision']);
  });

  testWidgets('control: a reviewer on a published item can edit it live', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.reviewer,
      resource: _article(ResourceStatus.published),
    );
    expect(
      b,
      containsAll(['Save changes', 'Unpublish', 'Start a revision', 'Delete']),
    );
  });

  testWidgets('a reviewer outside their subjects can read but not act', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.reviewer,
      resource: _article(ResourceStatus.inReview),
      access: const StaffAccess(StaffRole.reviewer, {'other-subject'}),
    );
    expect(b, isEmpty);
    expect(find.textContaining('outside the ones you work on'), findsOneWidget);
  });

  testWidgets('control: the same reviewer inside their subject can approve', (
    tester,
  ) async {
    final b = await _buttons(
      tester,
      role: StaffRole.reviewer,
      resource: _article(ResourceStatus.inReview),
      access: const StaffAccess(StaffRole.reviewer, {'s1'}),
    );
    expect(b, contains('Approve and publish'));
  });
}
