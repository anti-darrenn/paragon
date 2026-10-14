/// What guests are told. What they may *use* is `canUse` in
/// `feature_access.dart`, the one policy table.
///
/// Guests are real Firebase Anonymous Auth users: a real uid, the same
/// `users/{uid}` document shape, the same rules, the same writes. What
/// they are not is *durable* — signing out issues a brand new uid, and the
/// previous guest's document, attempts and progress are orphaned with no
/// way back to them. Everything here follows from that.
///
/// A guest who makes an account from `/account/upgrade` keeps their uid
/// (it is linked, not replaced — `features/account/guest_upgrade.dart`),
/// so nothing is lost *if they upgrade before leaving*. The limits below
/// still stand for the guest who never does.
///
/// **Why this file exists.** The subject lock was written inline in
/// `waec_subject_screen.dart` as `subject.name.toLowerCase() !=
/// 'mathematics'`, which was fine while WAEC was the only screen that
/// restricted anything. It is not fine once Learning Mode restricts the
/// same thing: two copies of a product rule drift, and the drift shows up
/// as a guest who can drill Physics but not sit a Physics exam, with
/// nothing in the code explaining which was intended.
///
/// **The honesty rule.** A guest whose mastery quietly evaporates — on
/// signing out, clearing the browser, or 30 days unused — has been misled
/// by a product that showed them a filling ring. Anywhere progress is
/// displayed to a guest, say how long it lasts — see
/// [GuestLimits.progressNotKeptMessage].
library;

import 'feature_access.dart';

class GuestLimits {
  const GuestLimits._();

  /// True when [subjectName]'s WAEC Prep should be shown locked to this
  /// viewer. Guests used to get Mathematics only; since 2026-10-14 they
  /// get every subject untimed (`canUse(Feature.waecUntimed)`), so this
  /// is false for everyone unless the policy table changes back.
  static bool locks({required bool isGuest, required String subjectName}) =>
      !canUse(Feature.waecUntimed, isGuest: isGuest);

  /// Shown when a guest taps something they cannot have. Names what to do
  /// rather than what went wrong — a guest is one tap from an account.
  static const String lockedSubjectMessage =
      'Make a free account to practise this subject.';

  /// Shown to a guest who reaches a drill the policy table closes to them
  /// — none, today. Kept so the screen has words if the table changes.
  static const String drillNeedsAccountMessage =
      'Drill practice needs an account. Make one free — anything you have '
      'done as a guest comes with you.';

  /// The sign-up prompt at a moment of value — the end of a drill, an
  /// exam result — naming what is worth keeping ("your 8/10").
  static String saveResultMessage(String result) =>
      'Save $result: create a free account to keep it on every device.';

  /// Shown wherever a guest is looking at progress.
  ///
  /// True as written: a guest's progress is stored under their anonymous
  /// account, which the browser keeps; `jobs.js --job=guests` deletes a
  /// guest unused for 30 days; and making an account carries it all over.
  /// It used to say progress was kept in the browser while drill refused
  /// guests, so there was no progress to keep — keep the two in step.
  static const String progressNotKeptMessage =
      "You're using Paragon as a guest. Your progress is saved in this "
      'browser for 30 days after your last visit. Create an account to '
      'keep it everywhere.';
}
