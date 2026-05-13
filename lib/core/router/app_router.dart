import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/features/about_screen.dart';
import 'package:paragon/features/dashboard_screen.dart';
import 'package:paragon/features/drill_screen.dart';
import 'package:paragon/features/sign_in_screen.dart';
import 'package:paragon/features/subject_list_screen.dart';
import 'package:paragon/features/topic_list_screen.dart';
import 'package:paragon/features/unit_list_screen.dart';
import 'package:paragon/features/waec_exam_screen.dart';
import 'package:paragon/features/waec_subject_screen.dart';

// ─── Notifier ─────────────────────────────────────────────────────────────────
// GoRouter needs a ChangeNotifier to know when to re-run the redirect function.
// This class listens to authStateProvider and calls notifyListeners() on every
// auth change, which triggers GoRouter to re-evaluate its redirect.

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }
  final Ref _ref;
}

// ─── Router Provider ──────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,

    // ── Auth redirect ──────────────────────────────────────────────────────
    // Runs on every navigation AND every time notifier fires (i.e. auth change).
    // Returns a redirect path string, or null to allow the navigation through.
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // Auth state is still loading (app just launched) — don't redirect yet.
      // The notifier will fire again once auth resolves and redirect will re-run.
      if (authAsync.isLoading) return null;

      final isSignedIn = authAsync.asData?.value != null;
      final isOnSignIn = state.matchedLocation == '/signin';

      // Not signed in and trying to reach any route → send to sign in
      if (!isSignedIn && !isOnSignIn) return '/signin';

      // Already signed in but somehow landed on /signin → send to home
      if (isSignedIn && isOnSignIn) return '/';

      // All other cases: let navigation proceed normally
      return null;
    },

    // ── Routes ────────────────────────────────────────────────────────────
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SubjectListScreen(),
      ),
      GoRoute(
        path: '/subject/:subjectId',
        builder: (context, state) => UnitListScreen(
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: '/subject/:subjectId/unit/:unitId',
        builder: (context, state) => TopicListScreen(
          subjectId: state.pathParameters['subjectId']!,
          unitId: state.pathParameters['unitId']!,
        ),
      ),
      GoRoute(
        path: '/subject/:subjectId/unit/:unitId/topic/:topicId',
        // ✅ CORRECT
builder: (context, state) => DrillScreen(
  topicId: state.pathParameters['topicId']!,
),
      ),
      GoRoute(
        path: '/waec',
        builder: (context, state) => const WaecSubjectScreen(),
      ),
      GoRoute(
        path: '/waec/:subjectId/exam',
        builder: (context, state) => WaecExamScreen(
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});