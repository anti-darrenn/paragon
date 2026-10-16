import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  await FirebaseAuth.instance.signOut();
  router.go('/welcome');
}
