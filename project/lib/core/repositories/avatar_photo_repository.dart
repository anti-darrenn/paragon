import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../providers/auth_provider.dart';

/// Profile photos (owner's decision, 2026-10-17: visible to others in quiz
/// rooms, moderated by reports).
///
/// The image is a small JPEG (256 px square, about 25 KB) kept as base64 in
/// `avatarImages/{uid}`, as lesson images are: no Cloud Storage, so no new
/// billing. `users/{uid}.avatar` says `photo:<version>`; a new upload is a
/// new version, so a cached old photo is never shown.
///
/// **Moderation.** Anyone who sees someone else's photo can report it
/// (`flags` with `avatarUid`). A reviewer's "Remove" deletes the image and
/// writes `avatarBlocks/{uid}`, which the rules check before any new upload.
class AvatarPhotoRepository {
  AvatarPhotoRepository([this._override]);

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  /// The largest stored image, in base64 characters; the rules hold the
  /// same cap.
  static const maxChars = 120000;

  DocumentReference<Map<String, dynamic>> _image(String uid) =>
      _db.collection('avatarImages').doc(uid);

  Future<Uint8List?> load(String uid) async {
    final snap = await _image(uid).get().metered();
    final data = snap.data()?['data'];
    if (data is! String || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }

  /// Stores [jpegBase64] and returns the avatar value to save on the user
  /// (`photo:<version>`). Refused by the rules while the account is
  /// blocked from photos.
  Future<String> upload(String uid, String jpegBase64) async {
    if (jpegBase64.length > maxChars) {
      throw ArgumentError('That photo is too large.');
    }
    await _image(uid).set({
      'mime': 'image/jpeg',
      'data': jpegBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 'photo:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> remove(String uid) => _image(uid).delete();

  /// Whether the Paragon team removed this account's photo and blocked new
  /// ones (`avatarBlocks/{uid}`); readable by its owner.
  Future<bool> isBlocked(String uid) async {
    final snap = await _db.doc('avatarBlocks/$uid').get().metered();
    return snap.exists;
  }
}

final avatarPhotoRepositoryProvider = Provider<AvatarPhotoRepository>(
  (ref) => AvatarPhotoRepository(),
);

/// A photo's bytes, keyed `uid@version` so a new upload is fetched fresh
/// and an old one stays cached for the session. Null while missing.
final avatarPhotoProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  key,
) async {
  final uid = key.split('@').first;
  if (uid.isEmpty) return null;
  try {
    return await ref.read(avatarPhotoRepositoryProvider).load(uid);
  } catch (_) {
    // A photo that cannot be read shows as initials.
    return null;
  }
});

/// Whether the signed-in student is blocked from uploading a photo.
final avatarBlockedProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isAnonymous) return false;
  try {
    return await ref.read(avatarPhotoRepositoryProvider).isBlocked(user.uid);
  } catch (_) {
    return false;
  }
});
