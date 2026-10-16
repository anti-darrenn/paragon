import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/account_repository.dart';
import 'reauth.dart';

/// Deletes the signed-in account immediately, confirming it is them first
/// if Firebase asks. Returns null on success (the auth listener then sends
/// them to /welcome), or a message to show.
///
/// Used by Settings for a guest, and by "Delete now" on the
/// pending-deletion screen for everyone else.
Future<String?> deleteAccountNow(BuildContext context, WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  try {
    final repo = ref.read(accountRepositoryProvider);
    var outcome = await repo.deleteAccount(user);
    // A guest cannot sign in again to confirm. Their documents are already
    // gone by now, so sign them out instead: the empty anonymous account is
    // deleted by the guest clean-up job (`jobs.js --job=guests`).
    if (outcome == AccountDeletionOutcome.needsRecentLogin &&
        user.isAnonymous) {
      await FirebaseAuth.instance.signOut();
      return null;
    }
    // Firebase wants a recent sign-in before deleting. Confirm it here
    // and try once more, rather than sending them away to sign out.
    if (outcome == AccountDeletionOutcome.needsRecentLogin && context.mounted) {
      if (!await reauthenticate(context, user)) {
        return 'Nothing has been deleted.';
      }
      outcome = await repo.deleteAccount(user);
    }
    return switch (outcome) {
      AccountDeletionOutcome.deleted => null,
      AccountDeletionOutcome.partial =>
        'Your account was deleted, but some data may not have been '
            'removed. Please email $contactEmail so we can finish the job.',
      AccountDeletionOutcome.needsRecentLogin =>
        "We couldn't confirm it was you, so nothing has been deleted. "
            'Please try again.',
    };
  } catch (_) {
    return "Couldn't delete your account. Please try again.";
  }
}
