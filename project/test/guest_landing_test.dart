import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/router/app_router.dart';

class _Guest implements User {
  @override
  String get uid => 'guest-1';
  @override
  bool get isAnonymous => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// F5 from the live-site review: reloading the site root as a guest landed
/// on /welcome, because the app opens there and the guest branch of the
/// redirect lets guests stay on welcome.
void main() {
  Future<(GoRouter, BuildContext)> setUp(
    WidgetTester tester,
    User? user,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AsyncData(user)),
        userDataProvider.overrideWith((ref) => Stream.value(null)),
        idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(const SizedBox());
    return (
      container.read(appRouterProvider),
      tester.element(find.byType(SizedBox)),
    );
  }

  Future<String?> redirect(
    GoRouter router,
    BuildContext context,
    String at,
  ) async => await router.configuration.topRedirect(
    context,
    GoRouterState(
      router.configuration,
      uri: Uri.parse(at),
      matchedLocation: at,
      fullPath: at,
      pathParameters: const {},
      pageKey: const ValueKey('k'),
    ),
  );

  testWidgets('a returning guest opening the app goes home', (tester) async {
    final (router, context) = await setUp(tester, _Guest());
    expect(await redirect(router, context, '/welcome'), '/');
  });

  testWidgets('control: a guest who later chooses welcome may stay', (
    tester,
  ) async {
    final (router, context) = await setUp(tester, _Guest());
    await redirect(router, context, '/courses');
    expect(await redirect(router, context, '/welcome'), isNull);
  });

  testWidgets('control: a signed-out visitor stays on welcome', (tester) async {
    final (router, context) = await setUp(tester, null);
    expect(await redirect(router, context, '/welcome'), isNull);
    expect(await redirect(router, context, '/courses'), '/welcome');
  });
}
