import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Account deletion.
///
/// Runs entirely from the client, which shapes the design in two ways
/// worth knowing before reading the code.
///
/// **Order matters.** Firebase refuses to delete an auth user whose
/// sign-in is not recent, and the failure is only discoverable by trying.
/// If we deleted the Firestore data first and *then* hit
/// `requires-recent-login`, the student would be left signed in with all
/// their history gone and their account still alive — the worst possible
/// half-state. So the auth user goes first: if that fails, nothing has
/// been destroyed and [AccountDeletionOutcome.needsRecentLogin] asks them
/// to sign in again.
///
/// The residual risk runs the other way — auth deleted, then the network
/// drops mid-cleanup, orphaning documents whose owner no longer exists.
/// That is the better failure: no user is locked out of a broken account,
/// and orphans are collectable server-side. [deleteAccount] returns
/// [AccountDeletionOutcome.partial] when it happens so the UI can say so
/// rather than claiming success.
///
/// **What is not deleted.** The `usernames/{key}` reservation stays. The
/// rules make reservations permanent and the privacy policy says so: a
/// released handle could be claimed by someone else and inherit the
/// previous owner's identity. This is the same choice most social
/// platforms make.
///
/// A Cloud Function triggered on auth deletion would be more robust than
/// any of this — atomic from the user's point of view, and able to reach
/// documents the client cannot. That needs the Blaze plan; until then,
/// this is the honest version.
enum AccountDeletionOutcome {
  /// Auth user and all owned documents are gone.
  deleted,

  /// Auth user is gone but some documents survived an error mid-cleanup.
  partial,

  /// Nothing was deleted; the user must sign in again and retry.
  needsRecentLogin,
}

class AccountRepository {
  const AccountRepository(this._db);
  final FirebaseFirestore _db;

  /// Firestore allows 500 writes per batch; stay clear of it.
  static const _batchChunkSize = 450;

  Future<AccountDeletionOutcome> deleteAccount(User user) async {
    final uid = user.uid;

    // 1. Auth first — see the class doc. This is the only step that can
    //    fail in a way that should abort the whole operation.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AccountDeletionOutcome.needsRecentLogin;
      }
      rethrow;
    }

    // 2. Owned documents. The auth user is already gone, so a failure
    //    here cannot strand anyone — it only leaves collectable orphans,
    //    which the caller is told about rather than hidden from.
    try {
      await deleteOwnedDocuments(uid);
    } catch (_) {
      return AccountDeletionOutcome.partial;
    }

    return AccountDeletionOutcome.deleted;
  }

  /// Removes every Firestore document owned by [uid].
  ///
  /// Split out from [deleteAccount] so it can be tested without a real
  /// Firebase Auth user, and so the same logic is available to a
  /// server-side cleanup later without being rewritten.
  ///
  /// Does not touch `usernames/{key}` — reservations are permanent by
  /// design; see the class doc.
  Future<void> deleteOwnedDocuments(String uid) async {
    await _deleteQuery(
      _db.collection('attempts').where('userId', isEqualTo: uid),
    );
    await _deleteQuery(
      _db.collection('flags').where('userId', isEqualTo: uid),
    );
    await _db.collection('users').doc(uid).delete();
  }

  /// Deletes every document a query matches, in chunks.
  ///
  /// Re-queries each pass rather than paging with a cursor: documents are
  /// disappearing underneath us, which is exactly the case a cursor
  /// handles badly.
  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(_batchChunkSize).get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // A short page means that was the last one.
      if (snap.docs.length < _batchChunkSize) return;
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(FirebaseFirestore.instance);
});
