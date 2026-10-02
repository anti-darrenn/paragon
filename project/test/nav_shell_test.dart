import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/router/app_router.dart';
import 'package:paragon/core/search/search.dart';
import 'package:paragon/core/widgets/nav/app_shell.dart';
import 'package:paragon/core/widgets/nav/bottom_tabs.dart';
import 'package:paragon/core/widgets/nav/nav_destinations.dart';
import 'package:paragon/core/widgets/nav/top_bar.dart';
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

Future<GoRouter> _pump(
  WidgetTester tester, {
  required double width,
  StaffRole role = StaffRole.none,
  bool guest = false,
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

    testWidgets('a guest is offered saving, never signing out', (
      tester,
    ) async {
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

    testWidgets('typing shows matches; arrow and Enter open one', (
      tester,
    ) async {
      await _pump(tester, width: 1280, corpus: corpus);
      await tester.tap(find.byKey(const ValueKey('topbar.search')));
      await tester.enterText(find.byKey(const ValueKey('topbar.search')), 'mat');
      await tester.pumpAndSettle();
      expect(find.text('Physics'), findsNothing);
      expect(find.textContaining('hematics', findRichText: true), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('course 0'), findsOneWidget);
    });

    testWidgets('Enter with nothing highlighted opens the results page', (
      tester,
    ) async {
      await _pump(tester, width: 1280, corpus: corpus);
      await tester.tap(find.byKey(const ValueKey('topbar.search')));
      await tester.enterText(find.byKey(const ValueKey('topbar.search')), 'mat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('search page'), findsOneWidget);
    });

    testWidgets('Ctrl+K focuses the field from anywhere', (tester) async {
      await _pump(tester, width: 1280, corpus: corpus);
      final field = find.byKey(const ValueKey('topbar.search'));
      bool focused() => tester.widget<TextField>(field).focusNode!.hasFocus;
      expect(focused(), isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(focused(), isTrue);
    });

    testWidgets('a narrow wide window gets a search icon instead', (
      tester,
    ) async {
      await _pump(tester, width: 860, corpus: corpus);
      expect(find.byKey(const ValueKey('topbar.search')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('topbar.searchIcon')));
      await tester.pumpAndSettle();
      expect(find.text('search page'), findsOneWidget);
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

    StatefulShellRoute shell() => router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;

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
