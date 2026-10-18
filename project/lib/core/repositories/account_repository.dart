import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragon/core/data/read_meter.dart';

/// Account deletion.
///
/// Runs entirely from the client, which shapes the design in two ways
/// worth knowing before reading the code.
///
/// **Order matters.** Firebase refuses to delete an auth user whose
/// sign-in is not recent. If we deleted the Firestore data first and *then*
/// hit `requires-recent-login`, the student would be left signed in with
/// their history gone and their account still alive. So the sign-in's age
/// is checked first, from the ID token's `auth_time` (what Firebase itself
/// checks): too old, and nothing is touched and
/// [AccountDeletionOutcome.needsRecentLogin] asks them to confirm it is
/// them.
///
/// Then the documents, **while still signed in**, and only then the auth
/// user. The other order — auth first — was used until 2026-10-16 and never
/// worked: once the auth user is deleted the client is signed out, every
/// owner-only delete is refused, and "Delete now" left everything for the
/// nightly orphans job (reproduced against the emulators). A guest is
/// deleted the same way minus the age check, since a guest cannot sign in
/// again.
///
/// If a delete fails mid-way the auth user still goes, and the result is
/// [AccountDeletionOutcome.partial] so the UI can say so; `jobs.js
/// --job=orphans` collects what is left.
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

  /// The account is not deleted; the user must confirm it is them (sign in
  /// again) and retry. Usually nothing has been touched either; see the
  /// class doc for the one case where the documents already went.
  needsRecentLogin,
}

/// How long a scheduled deletion waits. `jobs.js` (`GRACE_DAYS`) and the
/// privacy policy say the same; change all three together.
const Duration kDeletionGracePeriod = Duration(days: 30);

/// When an account whose deletion was requested at [requestedAt] goes.
DateTime deletionDateFor(DateTime requestedAt) =>
    requestedAt.add(kDeletionGracePeriod);

class AccountRepository {
  const AccountRepository(this._db);
  final FirebaseFirestore _db;

  /// Firestore allows 500 writes per batch; stay clear of it.
  static const _batchChunkSize = 450;

  /// How recent a sign-in Firebase accepts for deleting an account. Its
  /// own window is five minutes; a little less here leaves room for the
  /// requests in between.
  static const recentSignIn = Duration(minutes: 4);

  Future<AccountDeletionOutcome> deleteAccount(User user) async {
    final uid = user.uid;

    // 1. Recent enough? Checked before anything is destroyed.
    if (!user.isAnonymous) {
      final authTime = (await user.getIdTokenResult()).authTime;
      if (authTime == null ||
          DateTime.now().difference(authTime) > recentSignIn) {
        return AccountDeletionOutcome.needsRecentLogin;
      }
    }

    // 2. Owned documents, while the rules still know who is asking.
    var partial = false;
    try {
      await deleteOwnedDocuments(uid);
    } catch (_) {
      partial = true;
    }

    // 3. The auth user. A clock that disagrees with Firebase's can still
    //    get `requires-recent-login` here; the documents are gone by then,
    //    and the retry after confirming deletes the account.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AccountDeletionOutcome.needsRecentLogin;
      }
      rethrow;
    }

    return partial
        ? AccountDeletionOutcome.partial
        : AccountDeletionOutcome.deleted;
  }

  /// Removes every Firestore document owned by [uid].
  ///
  /// Split out from [deleteAccount] so it can be tested without a real
  /// Firebase Auth user, and so the same logic is available to a
  /// server-side cleanup later without being rewritten.
  ///
  /// Does not touch `usernames/{key}` — reservations are permanent by
  /// design; see the class doc.
  ///
  /// Anything that stores data against a uid belongs in this list. When a
  /// collection is added and this is not updated, the result is not a
  /// crash but something worse and quieter: a student who asked to be
  /// deleted, and mostly was.
  Future<void> deleteOwnedDocuments(String uid) async {
    await _deleteQuery(
      _db.collection('attempts').where('userId', isEqualTo: uid),
    );
    await _deleteQuery(_db.collection('flags').where('userId', isEqualTo: uid));
    // "Challenge a friend" links this student made.
    await _deleteQuery(
      _db.collection('challenges').where('userId', isEqualTo: uid),
    );
    // "Send feedback" messages.
    await _deleteQuery(
      _db.collection('feedback').where('userId', isEqualTo: uid),
    );
    // Flashcard decks the student made.
    await _deleteQuery(
      _db.collection('decks').where('userId', isEqualTo: uid),
    );
    // "How hard was this?" ratings not yet added up by the nightly job.
    await _deleteQuery(
      _db.collection('difficultyVotes').where('userId', isEqualTo: uid),
    );
    // One document per finished WAEC exam, for its review and history.
    await _deleteQuery(
      _db.collection('examResults').where('userId', isEqualTo: uid),
    );
    // Highlights and notes: one document per annotated block.
    await _deleteQuery(_db.collection('notes').where('userId', isEqualTo: uid));
    // One document, id'd by uid — no query needed. Deleting a document
    // that was never created is a no-op in Firestore, so a student who
    // never practised needs no special case.
    await _db.collection('progress').doc(uid).delete();
    // Topic-test results — the drill gate. Same shape as `progress`: one
    // document, id'd by uid, so no query is needed.
    await _db.collection('learn').doc(uid).delete();
    // Bookmarks (and anything else study features add to the same
    // document later) — one document, id'd by uid.
    await _db.collection('study').doc(uid).delete();
    // A pending "sign out everywhere" — see [requestSignOutEverywhere].
    await _db.collection('accountRequests').doc(uid).delete();
    // A content-team member's name and avatar for the studio. A student
    // has none; deleting a document that is not there is a no-op.
    await _db.collection('staffProfiles').doc(uid).delete();
    // "Notify me" sign-ups for coming-soon subjects.
    await _db.collection('waitlist').doc(uid).delete();
    // Weekly goal and exam date.
    await _db.collection('plan').doc(uid).delete();
    await _db.collection('users').doc(uid).delete();
  }

  // ─── Deletion grace period ─────────────────────────────────────────

  /// Schedules [uid]'s account for deletion in [kDeletionGracePeriod].
  ///
  /// Nothing is removed now. The router holds the account on
  /// `/account/deleting` from here on, where it can be restored or deleted
  /// at once, and `tools/admin/jobs.js --job=deletions` finishes it when
  /// the period runs out. Students are mostly children, and a delete
  /// button pressed in a temper should not cost them a year of work.
  /// "Delete now" stays available, so the right to erasure is never
  /// slower than it was.
  Future<void> scheduleDeletion(String uid) {
    return _db.collection('users').doc(uid).update({
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels a scheduled deletion.
  Future<void> cancelDeletion(String uid) {
    return _db.collection('users').doc(uid).update({
      'deletionRequestedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Download my data ──────────────────────────────────────────────

  /// The collections queried by owner, in export order. The documents
  /// keyed by uid are listed in [_ownedById]. Together these are the same
  /// set [deleteOwnedDocuments] removes — keep all three in step (and
  /// `OWNED` in tools/admin/jobs.js).
  static const _ownedByQuery = [
    'attempts',
    'notes',
    'flags',
    'feedback',
    'examResults',
    'challenges',
    'difficultyVotes',
    'decks',
  ];
  static const _ownedById = [
    'users',
    'progress',
    'learn',
    'study',
    'accountRequests',
    'staffProfiles',
    'waitlist',
    'plan',
  ];

  /// How many documents an export of [uid] would read, from `count()`
  /// aggregates (billed per 1000 index entries, not per document). Shown
  /// before exporting, because a student with thousands of answers costs
  /// thousands of reads against the shared daily quota.
  Future<int> exportSize(String uid) async {
    var total = _ownedById.length;
    for (final collection in _ownedByQuery) {
      final agg = await _db
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .count()
          .get()
          .metered();
      total += agg.count ?? 0;
    }
    return total;
  }

  /// Everything stored about [uid], as one JSON-safe map — the student's
  /// copy of their data. Timestamps become ISO-8601 strings; documents
  /// that do not exist are left out rather than shown as empty.
  ///
  /// The username reservation is not included: it holds only the handle
  /// and the uid, both of which are already in `users`.
  Future<Map<String, Object?>> exportOwnedDocuments(String uid) async {
    final out = <String, Object?>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'uid': uid,
    };
    for (final collection in _ownedById) {
      final snap = await _db.collection(collection).doc(uid).get().metered();
      if (snap.exists) out[collection] = toJsonSafe(snap.data());
    }
    for (final collection in _ownedByQuery) {
      final snap = await _db
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .get()
          .metered();
      out[collection] = [
        for (final d in snap.docs)
          {'id': d.id, ...?toJsonSafe(d.data()) as Map<String, Object?>?},
      ];
    }
    return out;
  }

  /// Asks the server to end every session on this account.
  ///
  /// Revoking sessions needs the Admin SDK, which never ships in the app,
  /// so this files a request that `tools/admin/apply_account_requests.js`
  /// carries out within about 15 minutes. Revocation stops sessions from
  /// being *renewed*; each device keeps its current access until that
  /// runs out, up to an hour. The screen says so rather than promising an
  /// instant sign-out it cannot deliver.
  Future<void> requestSignOutEverywhere(String uid) {
    return _db.collection('accountRequests').doc(uid).set({
      'type': 'revokeSessions',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes every document a query matches, in chunks.
  ///
  /// Re-queries each pass rather than paging with a cursor: documents are
  /// disappearing underneath us, which is exactly the case a cursor
  /// handles badly.
  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(_batchChunkSize).get().metered();
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

/// Converts Firestore values into what `jsonEncode` accepts: timestamps to
/// ISO-8601 (UTC), references to their path, geo points to lat/lng, bytes
/// to their length. Maps and lists are converted all the way down.
Object? toJsonSafe(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is DocumentReference) return value.path;
  if (value is GeoPoint) {
    return {'latitude': value.latitude, 'longitude': value.longitude};
  }
  if (value is Blob) return '<${value.bytes.length} bytes>';
  if (value is Map) {
    return <String, Object?>{
      for (final e in value.entries) '${e.key}': toJsonSafe(e.value),
    };
  }
  if (value is Iterable) return [for (final v in value) toJsonSafe(v)];
  return '$value';
}
