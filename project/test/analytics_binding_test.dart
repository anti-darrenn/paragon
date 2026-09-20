import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/analytics_binding.dart';

/// `AnalyticsBinding` is the only place in the app that turns navigation
/// into an analytics event, and it has exactly two ways to be wrong:
///
///   1. log the concrete URL — `/subject/8fK2.../unit/xQ.../topic/9dR...`
///      — which puts content ids into screen names and makes the report a
///      list of thousands of one-view rows;
///   2. log the same screen repeatedly, because the router delegate
///      notifies for things that are not navigation.
///
/// Both are pinned below against a real [GoRouter], which is why the
/// binding takes a callback rather than `Analytics` — see its doc comment.
void main() {
  /// A router shaped like the app's: flat routes, some parameterised.
  (GoRouter, List<String>) build() {
    final logged = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
        GoRoute(
          path: '/subject/:subjectId/unit/:unitId/topic/:topicId',
          builder: (_, _) => const Text('drill'),
        ),
      ],
    );
    return (router, logged);
  }

  Future<void> pump(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('logs the route pattern, never the concrete path', (
    tester,
  ) async {
    final (router, logged) = build();
    await pump(tester, router);
    final binding = AnalyticsBinding(onScreen: logged.add, router: router);
    addTearDown(binding.dispose);

    router.go('/subject/8fK2xQ/unit/xQ7bd1/topic/9dRm4z');
    await tester.pumpAndSettle();

    expect(logged, contains('/subject/:subjectId/unit/:unitId/topic/:topicId'));
    // The control that gives the test meaning: no logged name may carry a
    // real document id.
    for (final name in logged) {
      expect(name.contains('8fK2xQ'), isFalse, reason: 'leaked a subject id');
      expect(name.contains('9dRm4z'), isFalse, reason: 'leaked a topic id');
    }
  });

  testWidgets('logs the screen that is already open when it is built', (
    tester,
  ) async {
    final (router, logged) = build();
    await pump(tester, router);

    final binding = AnalyticsBinding(onScreen: logged.add, router: router);
    addTearDown(binding.dispose);

    // The delegate will not notify for a screen that was already there, so
    // without the constructor's own first call the app's landing screen
    // would never be counted.
    expect(logged, ['/']);
  });

  testWidgets('does not log a screen the user never left', (tester) async {
    final (router, logged) = build();
    await pump(tester, router);
    final binding = AnalyticsBinding(onScreen: logged.add, router: router);
    addTearDown(binding.dispose);

    router.go('/settings');
    await tester.pumpAndSettle();
    // Re-navigating to where we already are, plus delegate notifications
    // that are not navigation at all.
    router.go('/settings');
    await tester.pumpAndSettle();
    router.routerDelegate.notifyListeners();
    router.routerDelegate.notifyListeners();
    await tester.pumpAndSettle();

    expect(logged.where((n) => n == '/settings').length, 1);
  });

  testWidgets('stops logging once disposed', (tester) async {
    final (router, logged) = build();
    await pump(tester, router);
    final binding = AnalyticsBinding(onScreen: logged.add, router: router);

    binding.dispose();
    router.go('/settings');
    await tester.pumpAndSettle();

    expect(logged, isNot(contains('/settings')));
  });
}
