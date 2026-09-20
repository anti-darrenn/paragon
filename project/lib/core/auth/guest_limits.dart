/// What a guest can do, in one place.
///
/// Guests are real Firebase Anonymous Auth users: a real uid, the same
/// `users/{uid}` document shape, the same rules, the same writes. What
/// they are not is *durable* — signing out issues a brand new uid, and the
/// previous guest's document, attempts and progress are orphaned with no
/// way back to them (`auth_provider.dart`; account-linking is deliberately
/// unbuilt). Everything here follows from that.
///
/// **Why this file exists.** The subject lock was written inline in
/// `waec_subject_screen.dart` as `subject.name.toLowerCase() !=
/// 'mathematics'`, which was fine while WAEC was the only screen that
/// restricted anything. It is not fine once Learning Mode restricts the
/// same thing: two copies of a product rule drift, and the drift shows up
/// as a guest who can drill Physics but not sit a Physics exam, with
/// nothing in the code explaining which was intended.
///
/// **The honesty rule.** A guest whose streak and mastery quietly evaporate
/// when they close the tab has been misled by a product that showed them a
/// filling ring. Anywhere progress is displayed to a guest, say that it is
/// not being kept — see [progressNotKeptMessage].
library;

class GuestLimits {
  const GuestLimits._();

  /// The one subject a guest may practise, per spec §2.3.3, which locks
  /// the guest subject picker rather than the content behind it.
  ///
  /// Matched by name because that is what both pickers have: the WAEC
  /// screen holds `Subject` documents and the course catalog holds catalog
  /// entries, and the only field they reliably share is the name. Compared
  /// case-insensitively and trimmed, since one side comes from Firestore
  /// and the other from a hand-written catalog.
  static const String openSubject = 'Mathematics';

  static bool allowsSubject(String subjectName) =>
      subjectName.trim().toLowerCase() == openSubject.toLowerCase();

  /// True when [subjectName] should be shown locked to this viewer.
  static bool locks({required bool isGuest, required String subjectName}) =>
      isGuest && !allowsSubject(subjectName);

  /// Shown when a guest taps something they cannot have. Names what to do
  /// rather than what went wrong — a guest is one tap from an account, and
  /// "not available" would not tell them that.
  static const String lockedSubjectMessage =
      'Sign in to practise this subject. Guests get $openSubject.';

  /// Shown wherever a guest is looking at progress that will not survive
  /// the session.
  static const String progressNotKeptMessage =
      "You're browsing as a guest, so your streak and progress are not "
      'saved. Sign in to keep them.';
}
