/// Onboarding funnel: which step a signed-in user still owes, and the
/// username rules the first step enforces.
///
/// Everything here is pure — no Firestore, no widgets — so the router,
/// the screens and the tests all reason about the same rules.
///
/// **Gating vs. optional.** Three fields gate entry to the app: `username`,
/// `displayName` and `selectedSubjects`. The optional profile step
/// (school, class, age, gender, country, state) never gates anything and
/// is never reached by a redirect — only by walking forward through the
/// funnel, or later from settings. That matches the spec's own definition
/// of a complete profile ("username + subjects present"), with
/// `displayName` added because an email sign-up starts with an empty one
/// and would otherwise be greeted as "Student" forever.
///
/// **Guests never onboard.** Anonymous users are excluded upstream, in the
/// router — see `app_router.dart`.
library;

/// A step in the funnel, in the order they are presented.
enum OnboardingStep {
  username('/onboarding/username'),
  displayName('/onboarding/displayname'),
  subjects('/onboarding/subjects'),

  /// Optional final step. Never produced by [resolveOnboardingStep] — it
  /// is only reached by continuing forward from [subjects].
  profile('/onboarding/profile'),

  /// Nothing outstanding; the user belongs in the app.
  complete('/');

  const OnboardingStep(this.path);

  /// Route this step lives at.
  final String path;

  /// Position in the funnel, for the "Step 2 of 4" indicator. Null for
  /// [complete], which is not a screen.
  int? get stepNumber => switch (this) {
    OnboardingStep.username => 1,
    OnboardingStep.displayName => 2,
    OnboardingStep.subjects => 3,
    OnboardingStep.profile => 4,
    OnboardingStep.complete => null,
  };

  /// The step that follows this one when moving forward through the
  /// funnel. [profile] and [complete] both end it.
  OnboardingStep get next => switch (this) {
    OnboardingStep.username => OnboardingStep.displayName,
    OnboardingStep.displayName => OnboardingStep.subjects,
    OnboardingStep.subjects => OnboardingStep.profile,
    OnboardingStep.profile => OnboardingStep.complete,
    OnboardingStep.complete => OnboardingStep.complete,
  };

  static const int totalSteps = 4;

  /// True if [path] is any onboarding route. Used by the router to leave
  /// the funnel alone once the user is inside it.
  static bool isOnboardingPath(String path) => path.startsWith('/onboarding');
}

/// The first step [userData] has not satisfied, or [OnboardingStep.complete].
///
/// [userData] is the raw `users/{uid}` document — null while it is still
/// loading or genuinely absent. A null document resolves to the first
/// step rather than to complete, so a missing doc can never wave someone
/// past the funnel; the router separately refuses to act while loading.
OnboardingStep resolveOnboardingStep(Map<String, dynamic>? userData) {
  if (userData == null) return OnboardingStep.username;

  if (_isBlank(userData['username'])) return OnboardingStep.username;
  if (_isBlank(userData['displayName'])) return OnboardingStep.displayName;
  if (_isEmptyList(userData['selectedSubjects'])) {
    return OnboardingStep.subjects;
  }
  return OnboardingStep.complete;
}

bool _isBlank(Object? value) {
  if (value is! String) return true;
  return value.trim().isEmpty;
}

bool _isEmptyList(Object? value) {
  if (value is! List) return true;
  return value.isEmpty;
}

// ─── Username rules ────────────────────────────────────────────────────

/// Username constraints, per spec §2.1 step 1.
class UsernameRules {
  const UsernameRules._();

  static const int minLength = 4;
  static const int maxLength = 20;

  /// Letters, digits and underscore only.
  ///
  /// Periods were in the original spec (cosmetic, stripped on
  /// normalisation) and are deliberately dropped. Firestore security rules
  /// can lower-case a string but cannot strip characters from one, so with
  /// periods allowed no rule can check that `usernameKey` is really the
  /// normalisation of `username` — leaving a hole where someone reserves
  /// the key `zzz` but displays `ada.lovelace`, and two accounts show the
  /// same handle. Without periods, normalisation is just `.lower()`, which
  /// rules *can* verify, so uniqueness becomes server-enforced instead of
  /// merely client-observed.
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9_]+$');

  /// The key a username is reserved under in `usernames/{key}`.
  ///
  /// Lower-cased, nothing else — so `AdaLovelace` and `adalovelace`
  /// collide. Kept trivial on purpose: `firestore.rules` performs the
  /// identical transform to verify a claim, and any step it cannot
  /// reproduce is a step the server cannot enforce.
  static String normalise(String raw) => raw.trim().toLowerCase();

  /// Null when [raw] is acceptable, otherwise a message to show the user.
  static String? validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Pick a username.';
    if (!_allowed.hasMatch(trimmed)) {
      return 'Use only letters, numbers and underscores.';
    }

    final key = normalise(trimmed);
    if (key.length < minLength) {
      return 'Usernames need at least $minLength characters.';
    }
    if (key.length > maxLength) {
      return 'Usernames can be at most $maxLength characters.';
    }
    return null;
  }
}
