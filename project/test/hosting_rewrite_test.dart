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
    // Enforced since a clean preview run (2026-10-16), and still refusing
    // to be framed.
    final csp = headersOf(rule)['Content-Security-Policy']!;
    expect(csp, contains("frame-ancestors 'none'"));
    expect(csp, contains("default-src 'self'"));
    expect(
      headersOf(rule),
      isNot(contains('Content-Security-Policy-Report-Only')),
    );
    // Hosting matches a header regex against the WHOLE path. A partial
    // match here is how `^/(?:[^_]|…)` passed while production sent these
    // headers on `/` and one-letter paths only (found 2026-10-16).
    final scope = RegExp('^(?:${rule['regex']})\$');
    for (final p in [
      '/',
      '/welcome',
      '/courses',
      '/subject/mathematics/course/topic/indices',
      '/past-questions/x/',
      '/past-questions/img/abc.svg',
      '/privacy/',
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

  test('the CSP lets the YouTube player load its API', () {
    // youtube_player_iframe draws the player in a srcdoc iframe, which
    // inherits this policy, and that page loads www.youtube.com/iframe_api.
    // Without the host every video is a grey box (measured in headless
    // Chrome against production, 2026-10-16).
    final rule = headerRules.singleWhere(
      (r) => headersOf(r).containsKey('X-Frame-Options'),
    );
    final csp = headersOf(rule)['Content-Security-Policy']!;
    final scriptSrc = csp
        .split(';')
        .map((d) => d.trim())
        .firstWhere((d) => d.startsWith('script-src '));
    expect(scriptSrc, contains('https://www.youtube.com'));
    expect(csp, contains('https://www.youtube-nocookie.com'));
  });

  test('question images cannot run anything when opened directly', () {
    // An SVG opened as a page is a document on this origin; the sandbox
    // and default-src 'none' keep any script in one inert.
    final rule = headerRules.singleWhere(
      (r) => r['source'] == '/past-questions/img/**',
    );
    final csp = headersOf(rule)['Content-Security-Policy']!;
    expect(csp, contains("default-src 'none'"));
    expect(csp, contains('sandbox'));
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
