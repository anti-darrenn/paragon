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
/// without an account. Turning it off calls
/// `setAnalyticsCollectionEnabled(false)`, which stops the SDK at source —
/// not merely a flag this class checks.
///
/// Whatever is logged here must stay consistent with what
/// `legal_documents.dart` tells users. Adding an event changes both files.
class Analytics {
  Analytics(this._analytics, {required this.enabled});

  final FirebaseAnalytics _analytics;
  final bool enabled;

  /// Belt and braces: collection is disabled at the SDK level when the
  /// user opts out, and every call here is also a no-op. Either alone
  /// would do; both means a missed `await` cannot leak an event.
  Future<void> _log(Future<void> Function() action) async {
    if (!enabled) return;
    try {
      await action();
    } catch (_) {
      // Analytics must never break a user flow.
    }
  }

  Future<void> screen(String name) =>
      _log(() => _analytics.logScreenView(screenName: name));

  /// Onboarding funnel — one event per completed step, so drop-off
  /// between steps is visible.
  Future<void> onboardingStepCompleted(String step) => _log(
    () => _analytics.logEvent(name: 'onboarding_step', parameters: {
      'step': step,
    }),
  );

  Future<void> onboardingCompleted({required int subjectCount}) => _log(
    () => _analytics.logEvent(
      name: 'onboarding_complete',
      parameters: {'subject_count': subjectCount},
    ),
  );

  /// A finished drill session. Ids and counts only — never question text.
  Future<void> drillCompleted({
    required String subjectId,
    required String topicId,
    required int answered,
    required int correct,
  }) => _log(
    () => _analytics.logEvent(
      name: 'drill_complete',
      parameters: {
        'subject_id': subjectId,
        'topic_id': topicId,
        'answered': answered,
        'correct': correct,
      },
    ),
  );

  Future<void> examCompleted({
    required String subjectId,
    required int answered,
    required int correct,
  }) => _log(
    () => _analytics.logEvent(
      name: 'exam_complete',
      parameters: {
        'subject_id': subjectId,
        'answered': answered,
        'correct': correct,
      },
    ),
  );

  /// Separates guest sessions from real accounts in reporting without
  /// attaching anything identifying.
  Future<void> setIsGuest({required bool isGuest}) => _log(
    () => _analytics.setUserProperty(
      name: 'is_guest',
      value: isGuest ? 'true' : 'false',
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

final analyticsEnabledProvider =
    NotifierProvider<AnalyticsEnabledNotifier, bool>(
      AnalyticsEnabledNotifier.new,
    );

final analyticsProvider = Provider<Analytics>((ref) {
  return Analytics(
    FirebaseAnalytics.instance,
    enabled: ref.watch(analyticsEnabledProvider),
  );
});
