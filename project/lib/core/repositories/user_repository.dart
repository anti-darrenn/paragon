import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  const UserRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> createUserIfNew(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── Onboarding writes ──────────────────────────────────────────────

  /// Reserves [raw] for [uid] and records it on the user document.
  ///
  /// Two phases, deliberately not one transaction:
  ///
  ///   1. Atomically claim `usernames/{key}` if free.
  ///   2. Write `username`/`usernameKey` onto `users/{uid}`.
  ///
  /// It has to be this order because `firestore.rules` guards step 2 with
  /// `exists()`/`get()` on the reservation, and those read *committed*
  /// data — inside a single transaction the reservation would not be
  /// visible yet and every claim would be rejected. Splitting the write
  /// is what makes the rule enforceable, which is the whole point: the
  /// server, not the client, decides that a username is yours.
  ///
  /// Phase 1 is itself a transaction, so two people racing the same handle
  /// cannot both win.
  ///
  /// Returns true on success, false if the handle belongs to someone else.
  /// Throws for anything that is not a uniqueness failure, so an outage is
  /// never reported to the user as "that name is taken".
  ///
  /// A crash between the phases leaves a reservation owned by [uid] and a
  /// user document without it. That is recoverable and not a collision:
  /// re-running finds the reservation already ours and completes phase 2.
  Future<bool> reserveUsername({
    required String uid,
    required String raw,
    required String key,
  }) async {
    final reservation = _db.collection('usernames').doc(key);
    final trimmed = raw.trim();

    final claimed = await _db.runTransaction<bool>((tx) async {
      final existing = await tx.get(reservation);
      if (existing.exists) {
        // Already ours from a half-finished attempt is a success, not a
        // collision — otherwise the user is stranded on a name they own
        // but cannot use.
        return existing.data()?['uid'] == uid;
      }
      tx.set(reservation, {'uid': uid, 'raw': trimmed});
      return true;
    });

    if (!claimed) return false;

    await _db.collection('users').doc(uid).set({
      'username': trimmed,
      'usernameKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Whether [key] is free. Advisory only — [reserveUsername] is what
  /// actually decides, since anything can be taken between the check and
  /// the submit.
  Future<bool> isUsernameAvailable(String key) async {
    final snap = await _db.collection('usernames').doc(key).get();
    return !snap.exists;
  }

  Future<void> setDisplayName({
    required String uid,
    required String displayName,
  }) {
    return _db.collection('users').doc(uid).set({
      'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setSelectedSubjects({
    required String uid,
    required List<String> subjectKeys,
  }) {
    return _db.collection('users').doc(uid).set({
      'selectedSubjects': subjectKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Optional profile step. Every field is nullable and the whole step is
  /// skippable, so this merges only the keys actually supplied — skipping
  /// with two fields filled saves those two rather than wiping the rest.
  Future<void> setProfile({
    required String uid,
    required Map<String, Object?> profile,
  }) {
    final supplied = <String, Object?>{
      for (final entry in profile.entries)
        if (entry.value != null && entry.value != '') entry.key: entry.value,
    };
    if (supplied.isEmpty) return Future.value();

    // A nested map with merge: true, rather than dotted field paths —
    // SetOptions(merge:) deep-merges the profile map, so this fills in the
    // supplied keys and leaves previously saved siblings alone, and works
    // whether or not `profile` exists yet.
    return _db.collection('users').doc(uid).set({
      'profile': supplied,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Replaces the profile from the settings editor, clearing what was
  /// emptied.
  ///
  /// [setProfile] deliberately ignores blank values — it serves the
  /// onboarding step, where "left blank" means "not answered yet" and must
  /// not wipe a sibling field. That is exactly wrong for an editor: a
  /// student who clears their age is asking for it to be deleted, and
  /// silently keeping it would be the worst possible answer on a screen
  /// holding data about minors.
  ///
  /// Dotted paths with [FieldValue.delete], so only the named keys move
  /// and the rest of the profile is untouched. `affectedKeys()` in
  /// `firestore.rules` sees the top-level `profile`, which is
  /// allow-listed, so nested deletes need no rules change.
  ///
  /// Uses `update`, not `set`: there is no sensible way to clear a field
  /// on a user document that does not exist, and creating one here would
  /// bypass the create rule's field checks.
  Future<void> updateProfile({
    required String uid,
    required Map<String, Object?> profile,
  }) {
    if (profile.isEmpty) return Future.value();

    final data = <String, Object?>{'updatedAt': FieldValue.serverTimestamp()};
    for (final entry in profile.entries) {
      final isBlank = entry.value == null || entry.value == '';
      data['profile.${entry.key}'] = isBlank
          ? FieldValue.delete()
          : entry.value;
    }
    return _db.collection('users').doc(uid).update(data);
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});
