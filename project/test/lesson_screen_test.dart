import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/learn/lesson_progress.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/models/topic.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/providers/connectivity_provider.dart';
import 'package:paragon/core/repositories/learn_progress_repository.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/features/lesson/lesson_screen.dart';

/// The lesson page's navigation: what is highlighted, where "Up next"
/// goes, and that a lesson ends at the topic test. Articles only, so no
/// video player or question bank is involved.
void main() {
  LearnResource article(String id, int order, {String body = 'Some prose.'}) =>
      LearnResource(
        id: id,
        type: LearnResourceType.article,
        order: order,
        title: 'Article $id',
        subjectId: 's1',
        topicId: 't1',
        body: body,
      );

  final resources = [
    article('a', 1),
    article('gap', 2, body: ''), // unwritten: listed, skipped by Up next
    article('b', 3),
  ];

  const topic = Topic(
    id: 't1',
    unitId: 'u1',
    subjectId: 's1',
    name: 'Number bases',
    questionCount: 10,
    order: 1,
  );

  Future<GoRouter> pump(
    WidgetTester tester,
    String start, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/learn/topic/:topicId/:resourceId',
          builder: (_, s) => LessonScreen(
            topicId: s.pathParameters['topicId']!,
            resourceId: s.pathParameters['resourceId']!,
          ),
        ),
        GoRoute(
          path: '/subject/:s/unit/:u/topic/:t/test',
          builder: (_, s) => Scaffold(body: Text('TEST ${s.pathParameters['t']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topicResourcesProvider.overrideWith((ref, id) async => resources),
          topicByIdProvider.overrideWith((ref, id) async => topic),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          currentUserProvider.overrideWithValue(null),
          lessonProgressProvider.overrideWithValue(
            LessonProgress.empty.withCompleted('t1', 'a'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Up next skips the unwritten item', (tester) async {
    final router = await pump(tester, '/learn/topic/t1/a');
    expect(find.text('Up next: Article b'), findsOneWidget);
    await tester.tap(find.text('Up next: Article b'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/learn/topic/t1/b');
  });

  testWidgets('the last item leads to the topic test', (tester) async {
    await pump(tester, '/learn/topic/t1/b');
    await tester.tap(find.text('Up next: Topic test'));
    await tester.pumpAndSettle();
    expect(find.text('TEST t1'), findsOneWidget);
  });

  testWidgets('the sidebar shows progress and marks done items', (tester) async {
    await pump(tester, '/learn/topic/t1/b');
    expect(find.text('Number bases'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsOneWidget);
    expect(find.text('Not available yet'), findsOneWidget);
    // One check for the completed item.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('on a phone the sequence moves into a sheet', (tester) async {
    await pump(tester, '/learn/topic/t1/b', size: const Size(400, 800));
    // No sidebar header on a phone: the compact bar replaces it.
    expect(find.text('1 of 2 done'), findsNothing);
    expect(find.text('Number bases · 3 of 3'), findsOneWidget);

    await tester.tap(find.text('Number bases · 3 of 3'));
    await tester.pumpAndSettle();
    expect(find.text('Article a'), findsOneWidget);

    await tester.tap(find.text('Article a'));
    await tester.pumpAndSettle();
    expect(find.text('Up next: Article b'), findsOneWidget);
  });

  testWidgets('an unwritten or unknown item is not opened', (tester) async {
    await pump(tester, '/learn/topic/t1/gap');
    expect(find.text('This lesson is not available.'), findsOneWidget);
  });
}
