import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/lesson_progress.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/features/lesson/lesson_nudge.dart';

LearnResource _article(String id) => LearnResource(
  id: id,
  type: LearnResourceType.article,
  order: 1,
  title: id,
  subjectId: 's',
  topicId: 't1',
  body: 'Text.',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<LearnResource> resources,
  required Set<String> completed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topicResourcesProvider.overrideWith((ref, id) async => resources),
        lessonProgressProvider.overrideWithValue(
          LessonProgress.fromDocument({
            'topics': {
              't1': {
                'completed': {for (final id in completed) id: true},
              },
            },
          }),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: LessonNudge(topicId: 't1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unfinished lesson is mentioned, with a way in', (
    tester,
  ) async {
    await _pump(
      tester,
      resources: [_article('a'), _article('b'), _article('c')],
      completed: {'a'},
    );
    expect(find.textContaining('1 of 3 lesson items'), findsOneWidget);
    expect(find.text('Continue lesson'), findsOneWidget);
  });

  testWidgets('it can be dismissed', (tester) async {
    await _pump(tester, resources: [_article('a')], completed: {});
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lesson'), findsNothing);
  });

  testWidgets('control: a finished lesson shows nothing', (tester) async {
    await _pump(tester, resources: [_article('a')], completed: {'a'});
    expect(find.textContaining('lesson'), findsNothing);
  });

  testWidgets('control: a topic with no lesson shows nothing', (tester) async {
    await _pump(tester, resources: const [], completed: {});
    expect(find.textContaining('lesson'), findsNothing);
  });
}
