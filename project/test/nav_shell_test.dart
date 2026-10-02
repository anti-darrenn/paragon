import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/providers/connectivity_provider.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/router/app_router.dart';
import 'package:paragon/core/search/search.dart';
import 'package:paragon/core/widgets/nav/app_shell.dart';
import 'package:paragon/core/widgets/nav/bottom_tabs.dart';
import 'package:paragon/core/widgets/nav/nav_destinations.dart';
import 'package:paragon/core/widgets/nav/top_bar.dart';
import 'package:paragon/features/lesson/continue_learning.dart';
import 'package:paragon/features/search/search_providers.dart';

/// A page that counts taps, so a test can tell whether its state survived.
class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => n++),
        child: Text('${widget.name} $n'),
      ),
    ),
  );
}

/// The real [AppShell] over stand-in pages, one branch per [NavTab].
GoRouter _shellRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        for (final tab in NavTab.values)
          StatefulShellBranch(
            routes: [
              GoRoute(path: tab.path, builder: (_, _) => _Counter(tab.name)),
              if (tab == NavTab.courses) ...[
                GoRoute(
                  path: '/subject/:s/course',
                  builder: (_, _) => const _Counter('course'),
                ),
                GoRoute(
                  path: '/search',
                  builder: (_, _) => const Text('search page'),
                ),
              ],
            ],
          ),
      ],
    ),
  ],
);

const _catalog = [
  CourseSummary(
    key: 'maths',
    slug: 'mathematics',
    name: 'Mathematics',
    blurb: '',
    status: CourseStatus.live,
    moduleCount: 8,
    topicCount: 60,
  ),
  CourseSummary(
    key: 'phys',
    slug: 'physics',
    name: 'Physics',
    blurb: '',
    status: CourseStatus.live,
    moduleCount: 6,
  ),
  CourseSummary(
    key: 'music',
    slug: 'music',
    name: 'Music',
    blurb: '',
    status: CourseStatus.planned,
    moduleCount: 3,
  ),
];

Future<GoRouter> _pump(
  WidgetTester tester, {
  required double width,
  StaffRole role = StaffRole.none,
  bool guest = false,
  bool online = true,
  List<SearchItem> corpus = const [],
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _shellRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        userDataProvider.overrideWith(
          (ref) => Stream.value({'displayName': 'Ada', 'username': 'ada'}),
        ),
        isGuestProvider.overrideWithValue(guest),
        staffRoleProvider.overrideWithValue(role),
        searchCorpusProvider.overrideWith((ref) async => corpus),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        continueLearningProvider.overrideWithValue(null),
        courseCatalogProvider.overrideWith((ref) async => _catalog),
        selectedSubjectSlugsProvider.overrideWithValue({'physics'}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('layout', () {
    testWidgets('a phone gets bottom tabs and no top bar', (tester) async {
      await _pump(tester, width: 400);
      expect(find.byType(BottomTabs), findsOneWidget);
      expect(find.byType(TopBar), findsNothing);
    });

    testWidgets('CONTROL: a wide window gets the top bar instead', (
      tester,
    ) async {
      await _pump(tester, width: 1280);
      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byType(BottomTabs), findsNothing);
    });

    testWidgets('the switch is at the breakpoint', (tester) async {
      await _pump(tester, width: kNavWideBreakpoint - 1);
      expect(find.byType(BottomTabs), findsOneWidget);
      await _pump(tester, width: kNavWideBreakpoint);
      expect(find.byType(TopBar), findsOneWidget);
    });

    testWidgets('resizing across the breakpoint keeps every open screen', (
      tester,
    ) async {
      // Re-parenting the branch navigators would rebuild the page — and
      // restart a playing lesson video. The counter's state is the proof.
      await _pump(tester, width: 1280);
      await tester.tap(find.text('home 0'));
      await tester.pump();
      expect(find.text('home 1'), findsOneWidget);

      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpAndSettle();
      expect(find.byType(BottomTabs), findsOneWidget);
      expect(find.text('home 1'), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('each tab keeps its own state', (tester) async {
      await _pump(tester, width: 400);
      await tester.tap(find.text('home 0'));
      await tester.tap(find.byKey(const ValueKey('tabs.courses')));
      await tester.pumpAndSettle();
      expect(find.text('courses 0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tabs.home')));
      await tester.pumpAndSettle();
      expect(find.text('home 1'), findsOneWidget);
    });

    testWidgets('tapping the active tab returns to its first screen', (
      tester,
    ) async {
      final router = await _pump(tester, width: 400);
      router.go('/subject/maths/course');
      await tester.pumpAndSettle();
      expect(find.text('course 0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tabs.courses')));
      await tester.pumpAndSettle();
      expect(find.text('courses 0'), findsOneWidget);
    });

    testWidgets('the top bar lights the section a deep page belongs to', (
      tester,
    ) async {
      final router = await _pump(tester, width: 1280);
      router.go('/subject/maths/course');
      await tester.pumpAndSettle();
      final bar = tester.widget<TopBar>(find.byType(TopBar));
      expect(bar.current, NavTab.courses);
    });
  });

  group('profile menu', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('topbar.avatar')));
      await tester.pumpAndSettle();
    }

    testWidgets('a writer sees the content studio', (tester) async {
      await _pump(tester, width: 1280, role: StaffRole.writer);
      await open(tester);
      expect(find.byKey(const ValueKey('menu.studio')), findsOneWidget);
    });

    testWidgets('CONTROL: a student does not', (tester) async {
      await _pump(tester, width: 1280);
      await open(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('menu.studio')), findsNothing);
      expect(find.byKey(const ValueKey('menu.signOut')), findsOneWidget);
    });

    testWidgets('a guest is offered saving, never signing out', (tester) async {
      await _pump(tester, width: 1280, guest: true);
      await open(tester);
      expect(find.byKey(const ValueKey('menu.upgrade')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu.signOut')), findsNothing);
    });
  });

  group('top bar search', () {
    final corpus = [
      SearchItem(
        kind: SearchKind.course,
        title: 'Mathematics',
        path: '/subject/maths/course',
      ),
      SearchItem(kind: SearchKind.course, title: 'Physics', path: '/x'),
    ];
    final field = find.byKey(const ValueKey('search.paletteField'));

    Future<void> openAndType(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const ValueKey('topbar.search')));
      await tester.pumpAndSettle();
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }

    testWidgets('the search button opens a palette; arrow and Enter open', (
      tester,
    ) async {
      await _pump(tester, width: 1280, corpus: corpus);
      await openAndType(tester, 'mat');
      expect(find.text('Physics'), findsNothing);
      expect(find.textContaining('hematics', findRichText: true), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search.palette')), findsNothing);
      expect(find.text('course 0'), findsOneWidget);
    });

    testWidgets('Enter with nothing highlighted opens the results page', (
      tester,
    ) async {
      await _pump(tester, width: 1280, corpus: corpus);
      await openAndType(tester, 'mat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('search page'), findsOneWidget);
    });

    testWidgets('Ctrl+K opens the palette from anywhere', (tester) async {
      await _pump(tester, width: 1280, corpus: corpus);
      expect(find.byKey(const ValueKey('search.palette')), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search.palette')), findsOneWidget);
    });

    testWidgets('CONTROL: K alone types nothing and opens nothing', (
      tester,
    ) async {
      await _pump(tester, width: 1280, corpus: corpus);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search.palette')), findsNothing);
    });
  });

  group('top bar', () {
    testWidgets('Courses opens a dropdown of every subject, yours first', (
      tester,
    ) async {
      await _pump(tester, width: 1280);
      await tester.tap(find.byKey(const ValueKey('topbar.courses')));
      await tester.pumpAndSettle();
      expect(find.text('YOUR SUBJECTS'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav.course.mathematics')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav.coursesPanel')), findsNothing);
      expect(find.text('course 0'), findsOneWidget);
    });

    testWidgets('a guest gets a Save progress button', (tester) async {
      await _pump(tester, width: 1280, guest: true);
      expect(find.text('Save progress'), findsOneWidget);
    });

    testWidgets('CONTROL: a student with no lesson yet gets no button', (
      tester,
    ) async {
      await _pump(tester, width: 1280);
      expect(find.byKey(const ValueKey('topbar.action')), findsNothing);
    });

    testWidgets('says so when offline', (tester) async {
      await _pump(tester, width: 1280, online: false);
      expect(find.byKey(const ValueKey('topbar.offline')), findsOneWidget);
    });

    testWidgets('CONTROL: says nothing when online', (tester) async {
      await _pump(tester, width: 1280);
      expect(find.byKey(const ValueKey('topbar.offline')), findsNothing);
    });

    testWidgets('pages scroll beneath the bar: their top inset includes it', (
      tester,
    ) async {
      await _pump(tester, width: 1280);
      final ctx = tester.element(find.text('home 0'));
      expect(MediaQuery.paddingOf(ctx).top, kTopBarHeight);
    });
  });

  group('the app router', () {
    late GoRouter router;

    setUp(() {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userDataProvider.overrideWith((ref) => Stream.value(null)),
          idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      router = container.read(appRouterProvider);
    });

    StatefulShellRoute shell() =>
        router.configuration.routes.whereType<StatefulShellRoute>().single;

    Set<String> pathsIn(List<RouteBase> routes) => {
      for (final r in routes) ...[
        if (r is GoRoute) r.path,
        ...pathsIn(r.routes),
      ],
    };

    test("each tab's first screen is its branch's first route", () {
      final branches = shell().branches;
      expect(branches, hasLength(NavTab.values.length));
      for (final tab in NavTab.values) {
        final first = branches[tab.index].routes.first as GoRoute;
        expect(first.path, tab.path, reason: tab.name);
      }
    });

    test('focus sessions and full-window screens are outside the shell', () {
      final inShell = pathsIn(shell().routes);
      for (final path in [
        '/subject/:subjectId/unit/:unitId/topic/:topicId', // drill
        '/subject/:subjectId/unit/:unitId/topic/:topicId/test',
        '/subject/:subjectId/course/challenge',
        '/subject/:subjectId/course/unit/:moduleId/test',
        '/waec/:subjectId/exam',
        '/mistakes/practice',
        '/welcome',
        '/signin',
        '/admin',
      ]) {
        expect(inShell, isNot(contains(path)), reason: path);
      }
      // CONTROL: the set really does hold the shell's screens.
      for (final path in ['/courses', '/review', '/search', '/me', '/waec']) {
        expect(inShell, contains(path), reason: path);
      }
    });

    testWidgets('the retired list screens redirect to the course pages', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      String? redirect(String pattern, String location, Map<String, String> p) {
        final route = router.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((r) => r.path == pattern);
        final state = GoRouterState(
          router.configuration,
          uri: Uri.parse(location),
          matchedLocation: location,
          fullPath: pattern,
          pathParameters: p,
          pageKey: const ValueKey('k'),
        );
        return route.redirect!(context, state) as String?;
      }

      expect(redirect('/subjects', '/subjects', {}), '/courses');
      expect(
        redirect('/subject/:subjectId', '/subject/abc', {'subjectId': 'abc'}),
        '/subject/abc/course',
      );
      expect(
        redirect('/subject/:subjectId/unit/:unitId', '/subject/abc/unit/u1', {
          'subjectId': 'abc',
          'unitId': 'u1',
        }),
        '/subject/abc/course',
      );
    });
  });
}
