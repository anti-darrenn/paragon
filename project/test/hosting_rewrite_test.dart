import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/router/app_router.dart';
import 'package:paragon/features/not_found_screen.dart';

// ignore: subtype_of_sealed_class
class _Guest implements User {
  @override
  String get uid => 'guest-1';
  @override
  bool get isAnonymous => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hosting sends a path to the app only when its first segment is one of
/// the app's own (`firebase.json`), so a missing static page or file gets
/// a real 404 instead of the app with a 200 (audit A6, 2026-10-15).
///
/// That list is written out by hand, because Hosting's regex is RE2 and has
/// no lookahead to say "everything except /past-questions/". This test is
/// what keeps it whole: a new top-level route that is not added there
/// would load from inside the app and 404 on a reload or a shared link.
void main() {
  final hosting =
      (jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, dynamic>)['hosting']
          as Map<String, dynamic>;
  final spa = (hosting['rewrites'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((r) => r['destination'] == '/index.html');
  final pattern = spa['regex'] as String;
  final regex = RegExp(pattern);

  final headerRules = (hosting['headers'] as List).cast<Map<String, dynamic>>();
  Map<String, String> headersOf(Map<String, dynamic> rule) => {
    for (final h in (rule['headers'] as List).cast<Map<String, dynamic>>())
      h['key'] as String: h['value'] as String,
  };

  test('every regex is RE2-compatible (no lookaround)', () {
    final patterns = [
      pattern,
      for (final r in headerRules)
        if (r['regex'] case final String p) p,
    ];
    for (final p in patterns) {
      expect(p, isNot(contains('(?=')));
      expect(p, isNot(contains('(?!')));
      expect(p, isNot(contains('(?<')));
    }
  });

  test('app pages are never cached: the no-cache list is the rewrite list', () {
    final noCache = headerRules.where(
      (r) =>
          r['regex'] == pattern && headersOf(r)['Cache-Control'] == 'no-cache',
    );
    expect(noCache, hasLength(1));
  });

  test('security headers cover pages but not Firebase\'s /__/ paths', () {
    // /__/auth/iframe is framed by the app during sign-in; DENY there
    // would break it.
    final rule = headerRules.singleWhere(
      (r) => headersOf(r).containsKey('X-Frame-Options'),
    );
    expect(headersOf(rule)['X-Frame-Options'], 'DENY');
    expect(
      headersOf(rule)['Content-Security-Policy'],
      "frame-ancestors 'none'",
    );
    final scope = RegExp(rule['regex'] as String);
    for (final p in [
      '/',
      '/courses',
      '/past-questions/x/',
      '/_x',
      '/_',
      '/main.dart.js',
    ]) {
      expect(scope.hasMatch(p), isTrue, reason: p);
    }
    for (final p in [
      '/__/auth/iframe',
      '/__/auth/handler',
      '/__/firebase/init.js',
    ]) {
      expect(scope.hasMatch(p), isFalse, reason: p);
    }
  });

  testWidgets('every top-level route reaches the app', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(const AsyncData(null)),
        userDataProvider.overrideWith((ref) => Stream.value(null)),
        idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(const SizedBox());
    final router = container.read(appRouterProvider);

    final segments = <String>{};
    void walk(List<RouteBase> routes) {
      for (final r in routes) {
        if (r is GoRoute && r.path.startsWith('/') && r.path != '/') {
          segments.add(r.path.split('/')[1]);
        }
        walk(r.routes);
      }
    }

    walk(router.configuration.routes);
    expect(
      segments,
      contains('waec'),
      reason: 'control: the walk found routes',
    );
    for (final s in segments) {
      final path = s.startsWith(':') ? '/x' : '/$s';
      expect(regex.hasMatch(path), isTrue, reason: '$path is not rewritten');
      expect(regex.hasMatch('$path/a/b'), isTrue, reason: '$path/… is not');
    }
    expect(regex.hasMatch('/'), isTrue);
  });

  testWidgets('an unknown in-app path shows the not-found screen', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AsyncData(_Guest())),
        userDataProvider.overrideWith((ref) => Stream.value(null)),
        idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go('/subject/x/no-such-page/at-all');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
  });

  test('static misses and files are not rewritten', () {
    for (final path in [
      '/past-questions/nonexistent/',
      '/past-questions/waec/mathematics/2050/',
      '/og-image.png',
      '/.well-known/security.txt',
      '/this-page-does-not-exist',
      '/waecx',
    ]) {
      expect(regex.hasMatch(path), isFalse, reason: path);
    }
  });
}
