import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import 'analytics_provider.dart';
import 'auth_provider.dart';

/// Connects [Analytics] to the two app-wide signals no single screen can
/// report for itself: which screen the user is on, and whether this is a
/// guest session.
///
/// Both were declared on [Analytics] and never called. `is_guest` in
/// particular was already described to users in `legal_documents.dart`
/// ("...and whether a session was a guest session") while nothing set it —
/// the privacy policy promised *more* collection than actually happened,
/// which is the harmless direction but still a claim the code did not
/// support.
///
/// **Screen names are route patterns, not URLs.** `/subject/abc123/unit/
/// def456/topic/ghi789` is logged as
/// `/subject/:subjectId/unit/:unitId/topic/:topicId`. Two reasons, in
/// order of importance: the pattern carries no document ids, so screen
/// views stay consistent with the promise that only deliberate,
/// named parameters identify content; and Google Analytics buckets by
/// screen name, so concrete paths would produce one row per topic —
/// thousands of rows, each with a handful of views, and no usable funnel.
/// Where a topic id genuinely matters it is sent as an explicit event
/// parameter on `drill_complete`, where it can be reasoned about.
class AnalyticsBinding {
  /// Takes the screen-view callback rather than [Analytics] itself.
  ///
  /// The two things that can actually go wrong here — logging a concrete
  /// URL instead of a route pattern, and logging the same screen twice —
  /// are both testable against a real [GoRouter], but only if constructing
  /// one of these does not require a live Firebase app. Hence the
  /// callback; `analyticsBindingProvider` passes `analytics.screen`.
  AnalyticsBinding({
    required void Function(String) onScreen,
    required GoRouter router,
  }) : _onScreen = onScreen,
       _router = router {
    _router.routerDelegate.addListener(_onRouterChanged);
    // The first screen is already on screen by the time this is built, and
    // the delegate will not notify for it.
    _onRouterChanged();
  }

  final void Function(String) _onScreen;
  final GoRouter _router;

  String? _lastScreen;

  /// The delegate notifies on more than navigation — a redirect that
  /// resolves to the same place, or an unrelated rebuild, both fire it. A
  /// screen the user never left must not be logged twice.
  void _onRouterChanged() {
    final name = _currentRoutePattern();
    if (name == null || name == _lastScreen) return;
    _lastScreen = name;
    _onScreen(name);
  }

  /// The declared `path` of the deepest matched route.
  ///
  /// Wrapped in a try/catch on the same principle as `Analytics._log`:
  /// this runs on every navigation in the app, and no reporting concern is
  /// worth a thrown exception in the router's own listener.
  String? _currentRoutePattern() {
    try {
      final matches = _router.routerDelegate.currentConfiguration.matches;
      if (matches.isEmpty) return null;
      final route = matches.last.route;
      return route is GoRoute ? route.path : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _router.routerDelegate.removeListener(_onRouterChanged);
  }
}

/// Built once, for its side effects. `app.dart` watches it so that it
/// exists for as long as the app does; nothing reads its value.
final analyticsBindingProvider = Provider<AnalyticsBinding>((ref) {
  final analytics = ref.watch(analyticsProvider);

  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    // Loading and error states say nothing about who is here; only a
    // resolved value should move the property, and a resolved null (signed
    // out) should clear it.
    final resolved = next.asData;
    if (resolved == null) return;
    analytics.setIsGuest(isGuest: resolved.value?.isAnonymous);
  }, fireImmediately: true);

  final binding = AnalyticsBinding(
    onScreen: analytics.screen,
    router: ref.watch(appRouterProvider),
  );
  ref.onDispose(binding.dispose);
  return binding;
});
