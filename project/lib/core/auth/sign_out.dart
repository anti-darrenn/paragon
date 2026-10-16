import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signs out and lands on the welcome page, every time.
///
/// Left to the router alone, signing out redirected to
/// `/welcome?next=<the page you were on>`, and signing back in returned
/// there. Sign-out is a deliberate exit, so it goes to a clean welcome.
/// Used by every sign-out in the app; a guest leaving guest mode too.
/// A guest's way out. Asked first, because a guest's progress belongs to
/// an anonymous account that cannot be signed back into: leaving abandons
/// it (it is deleted after 30 days), unless they save it to an account.
Future<void> confirmLeaveGuestMode(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Leave guest mode?'),
      content: const Text(
        "Your guest progress can't be opened again after you leave. "
        'Save it to a free account first if you want to keep it.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop(false);
            GoRouter.of(context).push('/account/upgrade');
          },
          child: const Text('Save my progress'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  if (leave == true && context.mounted) await signOutToWelcome(context);
}

Future<void> signOutToWelcome(BuildContext context) async {
  final router = GoRouter.of(context);
  final user = FirebaseAuth.instance.currentUser;
  await FirebaseAuth.instance.signOut();
  if (user != null) {
    await clearDeviceDataFor(uid: user.uid, wasGuest: user.isAnonymous);
  }
  router.go('/welcome');
}

/// What signing out removes from this device, for the next person on a
/// shared computer (school labs, cafés).
///
/// - Their WAEC exam in progress (`SavedExam`), questions and answers.
/// - A guest's notes, highlights, bookmarks and revision cards, which live
///   only on the device: the guest account cannot be signed back into, so
///   nobody could ever open them again, but the next person could read
///   them out of browser storage. An account's copy is NOT removed — for
///   an upgraded guest it may still be waiting to be copied up
///   (`guestDataCopyProvider`).
///
/// Kept on purpose: the studio's autosave backups, which exist to save
/// unsaved lesson work, and settings like text size or theme.
Future<void> clearDeviceDataFor({
  required String uid,
  required bool wasGuest,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (deviceKeyBelongsTo(key, uid: uid, wasGuest: wasGuest)) {
        await prefs.remove(key);
      }
    }
  } catch (_) {
    // Best effort: signing out must never fail because storage did.
  }
}

/// Whether [key] is one [clearDeviceDataFor] removes. Pure, tested.
bool deviceKeyBelongsTo(
  String key, {
  required String uid,
  required bool wasGuest,
}) {
  if (uid.isEmpty) return false;
  if (key.startsWith('waec_exam_in_progress:$uid:')) return true;
  return wasGuest && key.startsWith('study.v1.$uid.');
}
