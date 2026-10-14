import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Analytics for Firebase, with a working opt-out.
///
/// The dependency was already in `pubspec.yaml` and the web plugin was
/// registered, but nothing ever called it — a network capture confirmed
/// no requests to `google-analytics.com`. This wires it up, and gates it.
///
/// **What is never sent.** No username, display name, email, school, age,
/// gender, or anything a student typed. Most users here are minors; the
/// useful analytics is which subjects and topics get practised and where
/// people abandon a flow, none of which needs to identify anyone. Event
/// parameters are ids and counts only.
///
/// **Opt-out.** [analyticsEnabledProvider] is the switch. It is stored per
/// device in SharedPreferences rather than in Firestore on purpose: the
/// preference has to be readable before and independently of sign-in, and
/// a signed-out or guest visitor must be able to turn collection off
/// without an account. For a signed-in account the choice is also copied
/// to `users/{uid}.prefs.analytics` (`account_prefs_sync.dart`), so an
/// opt-out on one device reaches the others. Turning it off calls
/// `setAnalyticsCollectionEnabled(false)`, which stops the SDK at source —
/// not merely a flag this class checks.
///
/// Whatever is logged here must stay consistent with what
/// `legal_documents.dart` tells users. Adding an event changes both files.
class Analytics {
  Analytics({
    required FirebaseAnalytics Function() instance,
    required bool Function() isEnabled,
  }) : _instance = instance,
       _isEnabled = isEnabled;

  /// Resolved on each call, inside [_log]'s try, rather than held.
  ///
  /// `FirebaseAnalytics.instance` throws if Firebase has not been
  /// initialised, and holding the result meant that throw happened while
  /// *building the provider* — outside every guard this class has, and
  /// early enough to take the whole widget tree down with it. The class
  /// already promises that analytics never breaks a user flow; that
  /// promise covered logging but not construction.
  final FirebaseAnalytics Function() _instance;

  /// Read at call time, not captured at construction.
  ///
  /// Riverpod 3 forbids touching `ref` inside `State.dispose()` and tells
  /// you to hold the provider's value in a field instead — which
  /// `DrillScreen` does, so it can log a session that the student
  /// abandoned by navigating away. A captured `bool` would make that held
  /// instance remember the preference as it stood when the screen opened,
  /// so a student who opted out mid-drill would still have their session
  /// logged on the way out. Reading the flag here closes that: the
  /// instance is stable and always reflects the current answer.
  final bool Function() _isEnabled;

  bool get enabled => _isEnabled();

  /// Belt and braces: collection is disabled at the SDK level when the
  /// user opts out, and every call here is also a no-op. Either alone
  /// would do; both means a missed `await` cannot leak an event.
  Future<void> _log(Future<void> Function(FirebaseAnalytics) action) async {
    if (!_isEnabled()) return;
    try {
      await action(_instance());
    } catch (_) {
      // Analytics must never break a user flow.
    }
  }

  Future<void> screen(String name) =>
      _log((a) => a.logScreenView(screenName: name));

  /// Onboarding funnel — one event per completed step, so drop-off
  /// between steps is visible.
  Future<void> onboardingStepCompleted(String step) => _log(
    (a) => a.logEvent(name: 'onboarding_step', parameters: {'step': step}),
  );

  Future<void> onboardingCompleted({required int subjectCount}) => _log(
    (a) => a.logEvent(
      name: 'onboarding_complete',
      parameters: {'subject_count': subjectCount},
    ),
  );

  // ── The first-visit funnel (PLAN.md P6.4) ──────────────────────────
  // welcome -> guest or sign-up -> a topic -> a drill or an exam. The
  // welcome view itself is the `/welcome` screen view, logged already.
  // Methods are a fixed word ("google", "email", "google_link"…), never
  // an address.

  /// "Browse as guest" made a guest session.
  Future<void> guestStart() => _log((a) => a.logEvent(name: 'guest_start'));

  /// A sign-in or sign-up flow began with [method].
  Future<void> signupStart({required String method}) => _log(
    (a) => a.logEvent(name: 'signup_start', parameters: {'method': method}),
  );

  /// A new account exists: made fresh, or a guest linked to one.
  Future<void> signupComplete({required String method}) => _log(
    (a) => a.logEvent(name: 'signup_complete', parameters: {'method': method}),
  );

  /// A topic page opened.
  Future<void> topicOpen({required String subjectId, required String topicId}) =>
      _log(
        (a) => a.logEvent(
          name: 'topic_open',
          parameters: {'subject_id': subjectId, 'topic_id': topicId},
        ),
      );

  /// A drill session began (its end is `drill_complete`).
  Future<void> drillStart({required String topicId}) => _log(
    (a) => a.logEvent(name: 'drill_start', parameters: {'topic_id': topicId}),
  );

  /// A WAEC exam began. `preset` is `full_paper`, `custom` or `resume`.
  Future<void> examStart({required String subjectId, required String preset}) =>
      _log(
        (a) => a.logEvent(
          name: 'exam_start',
          parameters: {'subject_id': subjectId, 'preset': preset},
        ),
      );

  /// The five-question taster finished (`/try`).
  Future<void> tasterComplete({required String subjectId, required int correct}) =>
      _log(
        (a) => a.logEvent(
          name: 'taster_complete',
          parameters: {'subject_id': subjectId, 'correct': correct},
        ),
      );

  /// A live quiz room was made.
  Future<void> roomHosted({required int questions}) => _log(
    (a) => a.logEvent(name: 'room_hosted', parameters: {'questions': questions}),
  );

  /// Someone joined a live quiz room.
  Future<void> roomJoined() => _log((a) => a.logEvent(name: 'room_joined'));

  /// A "challenge a friend" link was made.
  Future<void> challengeCreated({required String topicId}) => _log(
    (a) => a.logEvent(
      name: 'challenge_created',
      parameters: {'topic_id': topicId},
    ),
  );

  /// Someone answered a challenge link; whether they beat the score.
  Future<void> challengePlayed({required String topicId, required bool beat}) =>
      _log(
        (a) => a.logEvent(
          name: 'challenge_played',
          parameters: {'topic_id': topicId, 'beat': beat ? 1 : 0},
        ),
      );

  /// "Notify me" on a coming-soon subject: the catalog slug only.
  Future<void> waitlistJoin({required String subject}) => _log(
    (a) => a.logEvent(name: 'waitlist_join', parameters: {'subject': subject}),
  );

  /// A finished drill session. Ids and counts only — never question text.
  Future<void> drillCompleted({
    required String subjectId,
    required String topicId,
    required int answered,
    required int correct,
  }) => _log(
    (a) => a.logEvent(
      name: 'drill_complete',
      parameters: {
        'subject_id': subjectId,
        'topic_id': topicId,
        'answered': answered,
        'correct': correct,
      },
    ),
  );

  /// A finished topic test — the drill gate.
  ///
  /// `passed` is the parameter worth having: the pass rate per topic is
  /// how we find out whether the 80% threshold is calibrated, or whether
  /// one topic's question bank is simply harder than its lesson prepares
  /// students for. Ids and counts only, as everywhere else.
  Future<void> topicTestCompleted({
    required String subjectId,
    required String topicId,
    required int score,
    required bool passed,
  }) => _log(
    (a) => a.logEvent(
      name: 'topic_test_complete',
      parameters: {
        'subject_id': subjectId,
        'topic_id': topicId,
        'score': score,
        'passed': passed ? 1 : 0,
      },
    ),
  );

  /// One Learn item finished — a video watched through, an article read,
  /// an exercise set done. `type` is `video`, `article` or `exercise`.
  Future<void> lessonItemComplete({
    required String topicId,
    required String type,
  }) => _log(
    (a) => a.logEvent(
      name: 'lesson_item_complete',
      parameters: {'topic_id': topicId, 'type': type},
    ),
  );

  /// A finished in-lesson exercise set, scored on first tries.
  Future<void> exerciseCompleted({
    required String topicId,
    required int correct,
    required int total,
  }) => _log(
    (a) => a.logEvent(
      name: 'exercise_complete',
      parameters: {'topic_id': topicId, 'correct': correct, 'total': total},
    ),
  );

  Future<void> examCompleted({
    required String subjectId,
    required int answered,
    required int correct,
  }) => _log(
    (a) => a.logEvent(
      name: 'exam_complete',
      parameters: {
        'subject_id': subjectId,
        'answered': answered,
        'correct': correct,
      },
    ),
  );

  /// An uncaught error: its type or Firebase code and the screen's route
  /// pattern, nothing from the message (see `ErrorReporter`).
  Future<void> appError({required String kind, required String screen}) => _log(
    (a) => a.logEvent(
      name: 'app_error',
      parameters: {'kind': kind, 'screen': screen},
    ),
  );

  /// Separates guest sessions from real accounts in reporting without
  /// attaching anything identifying.
  ///
  /// Null clears the property, which is what a sign-out means: without
  /// that, a guest who signs out would leave `is_guest = true` attached to
  /// whatever the next person on that browser does.
  Future<void> setIsGuest({required bool? isGuest}) => _log(
    (a) => a.setUserProperty(
      name: 'is_guest',
      value: isGuest == null ? null : (isGuest ? 'true' : 'false'),
    ),
  );
}

const String _analyticsPrefKey = 'analytics_enabled';

/// Whether usage analytics are collected on this device.
///
/// Defaults to on, which is the posture the privacy policy describes. The
/// setter also tells the Firebase SDK directly, so opting out stops
/// collection rather than just stopping our own calls.
class AnalyticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_analyticsPrefKey);
      if (stored != null) {
        state = stored;
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(stored);
      }
    } catch (_) {
      // Storage unavailable (private browsing, blocked site data) — keep
      // the default rather than failing to start.
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsPrefKey, value);
    } catch (_) {
      // The in-memory state still took effect for this session.
    }
  }
}

extension AccountOptOut on AnalyticsEnabledNotifier {
  /// Switches collection off because the student's account says so — they
  /// opted out on another device. Only ever off: an opt-out is never
  /// undone from elsewhere. See `account_prefs_sync.dart`.
  Future<void> applyAccountOptOut() => set(false);
}

final analyticsEnabledProvider =
    NotifierProvider<AnalyticsEnabledNotifier, bool>(
      AnalyticsEnabledNotifier.new,
    );

/// Deliberately does **not** `watch` [analyticsEnabledProvider].
///
/// Watching it would rebuild a new [Analytics] on every toggle, which
/// makes any instance a caller is holding silently stale. Since [Analytics]
/// now reads the flag on each call, one long-lived instance is both
/// correct and safe to hold in a `State` field.
final analyticsProvider = Provider<Analytics>((ref) {
  return Analytics(
    instance: () => FirebaseAnalytics.instance,
    isEnabled: () => ref.read(analyticsEnabledProvider),
  );
});
