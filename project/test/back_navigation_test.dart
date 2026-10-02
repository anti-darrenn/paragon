import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/router/app_router.dart';
import 'package:paragon/core/widgets/nav/back_navigation.dart';
import 'package:paragon/core/widgets/nav/nav_destinations.dart';

void main() {
  group('parentPathFor', () {
    /// Every path the app declares, with sample values for parameters.
    List<String> allPaths() {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userDataProvider.overrideWith((ref) => Stream.value(null)),
          idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final paths = <String>[];
      void walk(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute) paths.add(r.path);
          walk(r.routes);
        }
      }

      walk(router.configuration.routes);
      return [
        for (final p in paths) p.replaceAllMapped(RegExp(r':(\w+)'), (m) => 'x'),
      ];
    }

    test('only the tab roots have nowhere to go back to', () {
      final roots = {for (final t in NavTab.values) t.path};
      for (final path in allPaths()) {
        final parent = parentPathFor(Uri.parse(path));
        if (roots.contains(path)) {
          expect(parent, isNull, reason: path);
        } else {
          expect(parent, isNotNull, reason: '$path is a dead end');
          expect(parent, isNot(path), reason: '$path is its own parent');
        }
      }
    });

    test('pages go back to where they sit', () {
      String? p(String path) => parentPathFor(Uri.parse(path));
      expect(p('/subject/m/course'), '/courses');
      expect(p('/subject/m/course/topic/t'), '/subject/m/course');
      // Drill and the topic test return to their topic, not the list.
      expect(p('/subject/m/unit/u/topic/t'), '/subject/m/course/topic/t');
      expect(p('/subject/m/unit/u/topic/t/test'), '/subject/m/course/topic/t');
      expect(p('/waec/m/setup'), '/waec');
      expect(p('/mistakes/practice'), '/mistakes');
      expect(p('/mistakes'), '/review');
      expect(p('/settings/reading'), '/settings');
      expect(p('/settings'), '/me');
      expect(p('/settings/offline'), '/review');
      expect(p('/admin/topic/t'), '/admin');
    });
  });

  group('ParagonAppBar', () {
    Widget page(String name) => Scaffold(
      appBar: ParagonAppBar(title: Text(name)),
      body: Text('body $name'),
    );

    Future<GoRouter> pump(WidgetTester tester, String initial) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/review', builder: (_, _) => page('review')),
          GoRoute(path: '/mistakes', builder: (_, _) => page('mistakes')),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('a page opened directly still has a way back', (
      tester,
    ) async {
      await pump(tester, '/mistakes');
      await tester.tap(find.byKey(const ValueKey('nav.back')));
      await tester.pumpAndSettle();
      expect(find.text('body review'), findsOneWidget);
    });

    testWidgets('with history, back pops it', (tester) async {
      final router = await pump(tester, '/review');
      router.push('/mistakes');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.back')));
      await tester.pumpAndSettle();
      expect(find.text('body review'), findsOneWidget);
    });

    testWidgets('CONTROL: a tab root shows no back arrow', (tester) async {
      await pump(tester, '/review');
      expect(find.byKey(const ValueKey('nav.back')), findsNothing);
    });
  });
}
