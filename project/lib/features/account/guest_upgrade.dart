import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/learn/lesson_progress.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/learn_progress_repository.dart';
import '../../core/repositories/user_repository.dart';
import '../study/cards/card_store.dart';
import '../study/notes/study_store.dart';
import '../study/notes/study_providers.dart';

/// Turning a guest session into an account, without losing it.
///
/// A guest is a real Firebase anonymous user. Upgrading **links** Google or
/// an email and password to that same user, so the uid stays the same and
/// everything already written under it — topic-test results in
/// `learn/{uid}`, answers in `attempts`, the user document — is simply
/// still theirs. What was never written has to be carried across here:
///
/// - lesson completions, kept in memory only for a guest;
/// - notes, highlights, bookmarks and revision cards, kept on the device.
///
/// **When the account already exists** the link is refused
/// (`credential-already-in-use` / `email-already-in-use`). Two accounts
/// cannot be merged from the client — the rules forbid writing another
/// uid's documents, correctly — so the screen offers to sign in to the
/// existing account instead and says plainly that this guest session's
/// progress will not come with it.
enum GuestUpgradeOutcome { linked, accountExists, cancelled }

class GuestUpgrade {
  const GuestUpgrade._();

  static Future<GuestUpgradeOutcome> withGoogle(WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return GuestUpgradeOutcome.cancelled;
    final lessons = ref.read(guestLessonProgressProvider);
    try {
      final linked = await user.linkWithPopup(GoogleAuthProvider());
      await _finish(ref, linked.user!, lessons);
      return GuestUpgradeOutcome.linked;
    } on FirebaseAuthException catch (e) {
      return _outcomeFor(e);
    }
  }

  static Future<GuestUpgradeOutcome> withEmail(
    WidgetRef ref, {
    required String email,
    required String password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return GuestUpgradeOutcome.cancelled;
    final lessons = ref.read(guestLessonProgressProvider);
    try {
      final linked = await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await _finish(ref, linked.user!, lessons);
      return GuestUpgradeOutcome.linked;
    } on FirebaseAuthException catch (e) {
      return _outcomeFor(e);
    }
  }

  /// Account-exists and cancelled are outcomes the screen handles; every
  /// other error (weak password, network) is the caller's to show.
  static GuestUpgradeOutcome _outcomeFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return GuestUpgradeOutcome.accountExists;
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'user-cancelled':
        return GuestUpgradeOutcome.cancelled;
      default:
        throw e;
    }
  }

  static Future<void> _finish(
    WidgetRef ref,
    User user,
    LessonProgress lessons,
  ) async {
    // The rules for notes and study/{uid} refuse an anonymous sign-in
    // provider, and the provider is read from the ID token. Refresh it now
    // rather than let the copy below fail against the guest's old token.
    await user.getIdToken(true);
    await ref.read(userRepositoryProvider).recordUpgrade(user);
    await ref
        .read(learnProgressRepositoryProvider)
        .markAllComplete(uid: user.uid, lessons: lessons);
    // Also run on every start for a real account (guestDataCopyProvider),
    // so a copy interrupted here finishes on the next visit.
    // A failure here must not report the upgrade as failed: the account
    // exists and is linked. What did not copy stays on the device.
    final db = ref.read(studyDbProvider);
    if (db != null) {
      try {
        await _copyOnce(db, user.uid);
      } catch (_) {}
    }
  }
}

/// One copy per uid at a time. The link makes the user non-anonymous,
/// which starts [guestDataCopyProvider] while [GuestUpgrade] is still
/// copying; without this, both would read the same local notes and each
/// would write them, duplicating every one.
final Map<String, Future<int>> _copies = {};

Future<int> _copyOnce(FirebaseFirestore db, String uid) {
  return _copies[uid] ??= copyGuestStudyData(
    localStudy: LocalStudyStore(uid),
    study: FirestoreStudyStore(db, uid),
    localCards: LocalCardStore(uid),
    cards: FirestoreCardStore(db, uid),
  ).whenComplete(() => _copies.remove(uid));
}

/// Copies a former guest's on-device study data into their account, then
/// removes it from the device.
///
/// Safe to run twice, and safe to interrupt. Each note is removed locally
/// as soon as its copy is written, so a retry never duplicates one;
/// bookmarks and cards are keyed, so writing them again changes nothing.
/// Local data is only cleared once everything is across.
///
/// Returns how many items were copied, for tests.
Future<int> copyGuestStudyData({
  required LocalStudyStore localStudy,
  required StudyStore study,
  required LocalCardStore localCards,
  required CardStore cards,
}) async {
  var copied = 0;

  if (await localStudy.hasData) {
    for (final note in await localStudy.allNotes()) {
      await study.createNote(note);
      await localStudy.deleteNote(note.id);
      copied++;
    }
    for (final bookmark in (await localStudy.bookmarks()).values) {
      await study.addBookmark(bookmark);
      copied++;
    }
    await localStudy.clear();
  }

  if (await localCards.hasData) {
    final schedule = await localCards.load();
    await cards.save(schedule);
    copied += schedule.length;
    await localCards.clear();
  }

  return copied;
}

/// Finishes a copy that [GuestUpgrade] started and could not complete —
/// a closed tab, a dropped connection. Watched once by `app.dart`.
///
/// For a real account with nothing on the device (everyone, nearly always)
/// this is two local key lookups and no network.
final guestDataCopyProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isAnonymous) return;
  final db = ref.watch(studyDbProvider);
  if (db == null) return;
  try {
    await _copyOnce(db, user.uid);
  } catch (_) {
    // Left on the device; tried again next start.
  }
});
