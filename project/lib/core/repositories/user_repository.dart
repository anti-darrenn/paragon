import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The longest bio a student may save. `firestore.rules` checks the same
/// number.
const int kBioMaxLength = 160;

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

  /// Records that a guest session has just become a real account.
  ///
  /// The uid is unchanged — the anonymous user was linked, not replaced —
  /// so this is an update to the guest's own document, not a new one. The
  /// Google name, when there is one, fills a blank display name so the
  /// onboarding step can be pressed straight through; a name the guest
  /// never had is not invented.
  Future<void> recordUpgrade(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final storedName = (snap.data()?['displayName'] as String?)?.trim() ?? '';
    final authName = user.displayName?.trim() ?? '';
    final data = <String, Object?>{
      'isAnonymous': false,
      'email': user.email ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      if (storedName.isEmpty && authName.isNotEmpty) 'displayName': authName,
    };
    if (snap.exists) {
      await ref.update(data);
    } else {
      // A guest whose document was never provisioned (a failed first
      // write). Create it the one way the rules accept, then update.
      await createUserIfNew(user);
      await ref.update(data);
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

  /// [avatar] is `Avatar.storageValue`; the rules check its shape.
  Future<void> setAvatar({required String uid, required String avatar}) {
    return _db.collection('users').doc(uid).set({
      'avatar': avatar,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Saves the bio, or deletes it when [bio] is blank — the same rule as
  /// [updateProfile]: an emptied box on an editor is a request to remove
  /// what was there. Over-long input is refused here as well as by the
  /// rules, so the student gets a message rather than a permission error.
  Future<void> setBio({required String uid, required String bio}) async {
    final trimmed = bio.trim();
    if (trimmed.length > kBioMaxLength) {
      throw ArgumentError.value(bio, 'bio', 'longer than $kBioMaxLength');
    }
    await _db.collection('users').doc(uid).update({
      'bio': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
