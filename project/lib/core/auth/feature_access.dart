/// What a guest and a signed-in student may use — the one table.
///
/// Every guest gate in the app asks [canUse]. Before this, the rules were
/// scattered: a drill refusal in `drillAccessFor`, a subject lock in
/// `GuestLimits`, forced exam settings in the setup screen, and a topic
/// page that still offered drill to a guest it would then refuse.
///
/// Guests are real Firebase anonymous users. Their attempts, `progress`
/// and topic tests are stored under their uid like anyone's, kept while
/// the browser keeps the session, and carried over when they link an
/// account (`features/account/guest_upgrade.dart`). What they lose is
/// anything tied to *other* devices or to time — so those are what ask for
/// an account. `jobs.js --job=guests` deletes a guest idle for 30 days,
/// which [GuestLimits.progressNotKeptMessage] says.
///
/// Policy agreed 2026-10-14 (PLAN.md P1.4.4).
library;

enum Feature {
  /// Published lessons: articles, videos, exercises.
  readLessons,

  /// Topic drill — still behind each topic's test, for everyone.
  drill,

  /// Unit tests and the course challenge, which open drill like a topic
  /// test does — so they follow [drill].
  challenges,

  /// WAEC Prep in every subject, untimed.
  waecUntimed,

  /// WAEC Prep against the clock.
  waecTimed,

  /// The mistakes notebook and practising from it.
  mistakesNotebook,

  /// Revision cards and their review schedule.
  reviewCards,

  /// A study plan with an exam date — worth having on every device, so
  /// worth an account.
  studyPlan,

  /// Past WAEC results and their reviews.
  examHistory,

  /// "Save for offline" on a topic.
  offlinePacks,
}

const Map<Feature, ({bool guest, bool signedIn})> kFeaturePolicy = {
  Feature.readLessons: (guest: true, signedIn: true),
  Feature.drill: (guest: true, signedIn: true),
  Feature.challenges: (guest: true, signedIn: true),
  Feature.waecUntimed: (guest: true, signedIn: true),
  Feature.waecTimed: (guest: false, signedIn: true),
  Feature.mistakesNotebook: (guest: true, signedIn: true),
  Feature.reviewCards: (guest: true, signedIn: true),
  Feature.studyPlan: (guest: false, signedIn: true),
  // PLAN.md proposed closing these two to guests. Both already worked for
  // guests when it was adopted, and taking them away would cost a guest
  // something for no gain, so they stay open.
  Feature.examHistory: (guest: true, signedIn: true),
  Feature.offlinePacks: (guest: true, signedIn: true),
};

/// Whether this viewer may use [feature]. Signed-out visitors are handled
/// by the router (everything but the welcome and legal pages needs a
/// session), so this is only ever asked about guests and accounts.
bool canUse(Feature feature, {required bool isGuest}) {
  final rule = kFeaturePolicy[feature]!;
  return isGuest ? rule.guest : rule.signedIn;
}
