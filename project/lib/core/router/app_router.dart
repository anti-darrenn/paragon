import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/legal/legal_documents.dart';
import 'package:paragon/core/onboarding/onboarding_step.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/features/about_screen.dart';
import 'package:paragon/features/account/upgrade_screen.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/features/admin/admin_resource_editor_screen.dart';
import 'package:paragon/features/admin/admin_flag_screen.dart';
import 'package:paragon/features/admin/admin_home_screen.dart';
import 'package:paragon/features/admin/studio/team_screen.dart';
import 'package:paragon/features/admin/studio/topic_planner_screen.dart';
import 'package:paragon/features/lesson/lesson_screen.dart';
import 'package:paragon/features/course_catalog_screen.dart';
import 'package:paragon/features/course_index_screen.dart';
import 'package:paragon/features/dashboard_screen.dart';
import 'package:paragon/features/profile_settings_screen.dart';
import 'package:paragon/features/profile/edit_profile_screen.dart';
import 'package:paragon/features/profile/me_screen.dart';
import 'package:paragon/features/onboarding/avatar_screen.dart';
import 'package:paragon/features/onboarding/display_name_screen.dart';
import 'package:paragon/features/onboarding/profile_screen.dart';
import 'package:paragon/features/onboarding/subjects_screen.dart';
import 'package:paragon/features/onboarding/username_screen.dart';
import 'package:paragon/features/drill_screen.dart';
import 'package:paragon/features/learn_screen.dart';
import 'package:paragon/features/legal_screen.dart';
import 'package:paragon/features/settings_screen.dart';
import 'package:paragon/features/settings/reading_settings_screen.dart';
import 'package:paragon/features/study/offline/offline_topics_screen.dart';
import 'package:paragon/features/sign_in_screen.dart';
import 'package:paragon/features/study/cards/card_review_screen.dart';
import 'package:paragon/features/study/notes/saved_screen.dart';
import 'package:paragon/features/subject_list_screen.dart';
import 'package:paragon/features/subjects_settings_screen.dart';
import 'package:paragon/features/topic_list_screen.dart';
import 'package:paragon/features/topic_test_screen.dart';
import 'package:paragon/features/topic_overview_screen.dart';
import 'package:paragon/features/unit_list_screen.dart';
import 'package:paragon/features/waec_exam_screen.dart';
import 'package:paragon/features/waec_exam_setup_screen.dart';
import 'package:paragon/features/waec_subject_screen.dart';
import 'package:paragon/features/welcome_screen.dart';

// ─── Notifier ─────────────────────────────────────────────────────────────────
// GoRouter needs a ChangeNotifier to know when to re-run the redirect function.
// This class listens to authStateProvider and calls notifyListeners() on every
// auth change, which triggers GoRouter to re-evaluate its redirect.

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
    // The onboarding redirect reads the Firestore user document, so the
    // router has to re-run when that document arrives or changes —
    // otherwise a user who just saved their username would sit on the
    // step they already finished until some unrelated navigation.
    // Listening here also keeps the stream alive for the ref.read() below.
    _ref.listen<AsyncValue<dynamic>>(
      userDataProvider,
      (previous, next) => notifyListeners(),
    );
    // The admin gate reads a custom claim from the ID token, which
    // resolves after auth state does.
    _ref.listen<AsyncValue<dynamic>>(
      idTokenResultProvider,
      (previous, next) => notifyListeners(),
    );
  }
  final Ref _ref;
}

// ─── Router Provider ──────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: notifier,

    // ── Auth redirect ──────────────────────────────────────────────────────
    // Runs on every navigation AND every time notifier fires (i.e. auth change).
    // Returns a redirect path string, or null to allow the navigation through.
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // Auth state is still loading (app just launched) — don't redirect yet.
      // The notifier will fire again once auth resolves and redirect will re-run.
      if (authAsync.isLoading) return null;

      final user = authAsync.asData?.value;
      final isSignedIn = user != null;
      // A guest (anonymous auth) counts as signed in for every protected
      // route, but — unlike a real account — is still allowed to visit
      // welcome and signin. Upgrading from `/account/upgrade` links the
      // guest's own uid, so the same user becomes "really signed in" in
      // place and the onboarding gate below picks them up.
      final isReallySignedIn = isSignedIn && !user.isAnonymous;
      final isOnSignIn = state.matchedLocation == '/signin';
      final isOnUpgrade = state.matchedLocation == '/account/upgrade';
      final isOnWelcome = state.matchedLocation == '/welcome';
      // The welcome screen links to both, so a signed-out visitor has to
      // be able to read them. They are also the one thing a user must be
      // able to consult *before* deciding to create an account.
      final isOnLegal =
          state.matchedLocation == '/privacy' ||
          state.matchedLocation == '/terms';

      // Not signed in and trying to reach any route other than welcome/sign-in
      // → send to the welcome (landing) screen
      if (!isSignedIn && !isOnSignIn && !isOnWelcome && !isOnLegal) {
        return '/welcome';
      }

      // Legal pages are readable in every auth state, including part-way
      // through onboarding — a funnel that hides the privacy policy while
      // asking for a school and an age would be exactly backwards.
      if (isOnLegal) return null;

      // ── Studio gate ────────────────────────────────────────────────
      // UI only. Every read and write the studio makes is checked again
      // by `isWriter()` / `isReviewer()` in firestore.rules, which is what
      // actually protects drafts; this just keeps students off screens
      // that would only show them permission errors. Writers get in;
      // what they may do inside is decided per action.
      final isOnAdmin =
          state.matchedLocation == '/admin' ||
          state.matchedLocation.startsWith('/admin/');
      if (isOnAdmin) {
        if (ref.read(idTokenResultProvider).isLoading) return null;
        if (!ref.read(staffRoleProvider).canWrite) return '/';
      }

      // Guests never onboard: an anonymous session has no profile to
      // complete, and the funnel would be a wall in front of "Browse as
      // Guest". Everything below this line concerns real accounts only.
      if (!isReallySignedIn) {
        // ...and they cannot reach the funnel by deep link either, which
        // would otherwise let a guest write a username onto an anonymous
        // uid — a reservation nobody can ever claim or release, since the
        // rules make usernames permanent.
        if (OnboardingStep.isOnboardingPath(state.matchedLocation)) {
          return '/';
        }
        return null;
      }

      // ── Onboarding gate ────────────────────────────────────────────
      // Three guards keep this from looping, which is the failure mode
      // this whole block risks:
      //   1. the user document is still loading  → decide nothing yet
      //   2. already inside the funnel           → leave it alone
      //   3. finished, but on the optional step  → leave it alone
      final userDataAsync = ref.read(userDataProvider);
      if (userDataAsync.isLoading) return null;

      final isOnOnboarding = OnboardingStep.isOnboardingPath(
        state.matchedLocation,
      );
      final step = resolveOnboardingStep(userDataAsync.asData?.value);

      if (step != OnboardingStep.complete) {
        // Guard 2 — inside the funnel, moving between steps.
        if (isOnOnboarding) return null;
        return step.path;
      }

      // Complete from here. Guard 3: the profile step is optional, so a
      // user who has just finished step 3 is already "complete" and must
      // not be ejected from step 4 the instant they arrive on it.
      if (isOnOnboarding) {
        if (state.matchedLocation == OnboardingStep.profile.path) return null;
        return '/';
      }

      // Really signed in but somehow landed on welcome or sign-in → send
      // home, which is the dashboard. This covers the sign-in hop; a
      // returning user is covered by '/' itself being the dashboard, since
      // on web the browser URL — not initialLocation — picks the route.
      if (isOnSignIn || isOnWelcome || isOnUpgrade) return '/';

      // All other cases: let navigation proceed normally
      return null;
    },

    // ── Routes ────────────────────────────────────────────────────────────
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ── Onboarding funnel ───────────────────────────────────────────
      // Reached only by the redirect above (for a gating step) or by
      // moving forward from the previous step. Paths come from
      // OnboardingStep so the router and the resolver cannot disagree.
      GoRoute(
        path: '/onboarding/username',
        builder: (context, state) => const OnboardingUsernameScreen(),
      ),
      GoRoute(
        path: '/onboarding/displayname',
        builder: (context, state) => const OnboardingDisplayNameScreen(),
      ),
      GoRoute(
        path: '/onboarding/avatar',
        builder: (context, state) => const OnboardingAvatarScreen(),
      ),
      GoRoute(
        path: '/onboarding/subjects',
        builder: (context, state) => const OnboardingSubjectsScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const OnboardingProfileScreen(),
      ),
      // Home. The dashboard is the landing surface for a signed-in user:
      // both the post-sign-in redirect above and a returning visitor
      // opening the bare site root arrive here.
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/subjects',
        builder: (context, state) => const SubjectListScreen(),
      ),
      GoRoute(
        path: '/subject/:subjectId',
        builder: (context, state) =>
            UnitListScreen(subjectId: state.pathParameters['subjectId']!),
      ),

      // ── Course index ────────────────────────────────────────────────
      // Additive: the Khan-Academy-style course pages sit alongside the
      // UnitList/TopicList pair above, which is unchanged. `:subjectId`
      // here accepts either a Firestore subject id or a catalog slug
      // (e.g. /subject/chemistry/course), so the seven subjects with no
      // Firestore document are still reachable — see course_repository.
      // Declared before the `/unit/:unitId` child route so the literal
      // `course` segment can't be swallowed as a unit id.
      GoRoute(
        path: '/courses',
        builder: (context, state) => const CourseCatalogScreen(),
      ),
      GoRoute(
        path: '/subject/:subjectId/course',
        builder: (context, state) =>
            CourseIndexScreen(subjectKey: state.pathParameters['subjectId']!),
      ),
      GoRoute(
        path: '/subject/:subjectId/course/topic/:topicId',
        builder: (context, state) => TopicOverviewScreen(
          subjectKey: state.pathParameters['subjectId']!,
          topicKey: state.pathParameters['topicId']!,
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
        builder: (context, state) => DrillScreen(
          topicId: state.pathParameters['topicId']!,
          // Passed so the locked state can offer this topic's test. Drill
          // itself still only needs the topic id — see DrillScreen.
          subjectId: state.pathParameters['subjectId'],
          unitId: state.pathParameters['unitId'],
        ),
      ),
      // The topic test — the gate that opens the drill route above.
      // Deliberately NOT gated itself: taking it is how you get through.
      GoRoute(
        path: '/subject/:subjectId/unit/:unitId/topic/:topicId/test',
        builder: (context, state) => TopicTestScreen(
          subjectId: state.pathParameters['subjectId']!,
          unitId: state.pathParameters['unitId']!,
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      GoRoute(
        path: '/subject/:subjectId/unit/:unitId/topic/:topicId/learn',
        builder: (context, state) => LearnScreen(
          subjectId: state.pathParameters['subjectId']!,
          unitId: state.pathParameters['unitId']!,
          topicId: state.pathParameters['topicId']!,
        ),
      ),
      // The lesson page: any published Learn item, with the topic's
      // sequence beside it. The article-only URL it replaced redirects.
      GoRoute(
        path: '/learn/topic/:topicId/article/:resourceId',
        redirect: (context, state) => lessonPath(
          state.pathParameters['topicId']!,
          state.pathParameters['resourceId']!,
        ),
      ),
      GoRoute(
        path: '/learn/topic/:topicId/:resourceId',
        builder: (context, state) => LessonScreen(
          topicId: state.pathParameters['topicId']!,
          resourceId: state.pathParameters['resourceId']!,
        ),
      ),
      GoRoute(
        path: '/waec',
        builder: (context, state) => const WaecSubjectScreen(),
      ),
      GoRoute(
        path: '/waec/:subjectId/setup',
        builder: (context, state) =>
            WaecExamSetupScreen(subjectId: state.pathParameters['subjectId']!),
      ),
      GoRoute(
        path: '/waec/:subjectId/exam',
        builder: (context, state) => WaecExamScreen(
          subjectId: state.pathParameters['subjectId']!,
          // Direct URL / bad deep link with no route extra is handled
          // inside WaecExamScreen itself (redirects back to setup) rather
          // than crashing on a bad cast — see its initState.
          session: state.extra is WaecExamSessionData
              ? state.extra as WaecExamSessionData
              : null,
        ),
      ),
      // Back-compat: the dashboard used to live here, and both in-app
      // links and any bookmarks still point at it. Redirect rather than
      // build the screen twice, so there is one canonical home URL.
      GoRoute(path: '/dashboard', redirect: (context, state) => '/'),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      // A guest turning their session into an account. Real accounts are
      // sent home by the redirect above.
      GoRoute(
        path: '/account/upgrade',
        builder: (context, state) => const UpgradeScreen(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Your own profile and progress. Private: nobody else can open
      // anyone's `/me`, because nobody else can read `users/{uid}`.
      GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
      // Editing your subjects after onboarding. Deliberately its own
      // route rather than a re-entry into `/onboarding/subjects`, which
      // the redirect above sends back to `/` for anyone who has finished
      // the funnel — see subjects_settings_screen.dart.
      GoRoute(
        path: '/settings/subjects',
        builder: (context, state) => const SubjectsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/name',
        builder: (context, state) => const EditProfileScreen(),
      ),
      // The optional profile, editable at last. `/onboarding/profile` is
      // still reachable (guard 3 above lets a finished user sit on the
      // optional step) but nothing links there; this is the way in.
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      // Text size, line spacing, reading font, low-data mode. Per device.
      GoRoute(
        path: '/settings/reading',
        builder: (context, state) => const ReadingSettingsScreen(),
      ),
      // Bookmarks and notes. Guests too: theirs are kept on the device.
      GoRoute(
        path: '/saved',
        builder: (context, state) => const SavedScreen(),
      ),
      // A subject's revision cards. Guests too: their schedule is kept on
      // the device.
      GoRoute(
        path: '/cards/:subjectId',
        builder: (context, state) =>
            CardReviewScreen(subjectId: state.pathParameters['subjectId']!),
      ),
      // Topics saved for offline reading. Per device, like the above.
      GoRoute(
        path: '/settings/offline',
        builder: (context, state) => const OfflineTopicsScreen(),
      ),

      // ── Admin ───────────────────────────────────────────────────────
      // Gated by the `admin` claim — see the admin gate above. The edit
      // path is the deep link in the draft-notification email; keep
      // `tools/admin/notify_drafts.js` in step if it changes. The
      // article-only paths from before videos and exercises were editable
      // still redirect, for links in emails already sent.
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      // Who writes and reviews, and for which subjects. Admins only.
      GoRoute(
        path: '/admin/team',
        builder: (context, state) => const TeamScreen(),
      ),
      // One topic's lesson: every item in order, any status.
      GoRoute(
        path: '/admin/topic/:topicId',
        builder: (context, state) =>
            TopicPlannerScreen(topicId: state.pathParameters['topicId']!),
      ),
      GoRoute(
        path: '/admin/topic/:topicId/new/:type',
        builder: (context, state) => AdminResourceEditorScreen(
          topicId: state.pathParameters['topicId']!,
          newType: LearnResourceType.parse(state.pathParameters['type']),
        ),
      ),
      GoRoute(
        path: '/admin/topic/:topicId/resource/:resourceId',
        builder: (context, state) => AdminResourceEditorScreen(
          topicId: state.pathParameters['topicId']!,
          resourceId: state.pathParameters['resourceId']!,
        ),
      ),
      // A flagged question and its reports. Also a deep link, from the
      // report digest email.
      GoRoute(
        path: '/admin/flag/:questionId',
        builder: (context, state) =>
            AdminFlagScreen(questionId: state.pathParameters['questionId']!),
      ),
      GoRoute(
        path: '/admin/topic/:topicId/article/:resourceId',
        redirect: (context, state) {
          final topicId = state.pathParameters['topicId']!;
          final id = state.pathParameters['resourceId']!;
          return id == 'new'
              ? adminNewResourcePath(topicId, LearnResourceType.article)
              : adminResourcePath(topicId, id);
        },
      ),

      // ── Legal ───────────────────────────────────────────────────────
      // Exempt from the auth redirect above — see isOnLegal.
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const LegalScreen(document: privacyPolicy),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) =>
            const LegalScreen(document: termsOfService),
      ),
    ],
  );
});
