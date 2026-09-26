import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/firestore_parsing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/user_avatar.dart';

/// What the content team sees of each other: a name and an avatar.
///
/// `users/{uid}` is readable only by its owner, and that stays true for
/// staff too — so a reviewer cannot read a writer's user document to draw
/// their picture. Instead each team member publishes this small copy to
/// `staffProfiles/{uid}`, readable only by the team (`isWriter()`).
/// Students never write or read it; nothing about them is ever in it.
///
/// Kept current by [staffProfileSyncProvider], which rewrites it whenever
/// the member's own name or avatar differs from it, so a changed picture
/// shows up in every comment at once — stamping it onto each comment
/// would freeze it at the time of writing.
@immutable
class StaffProfile {
  const StaffProfile({required this.displayName, required this.avatar});

  final String displayName;
  final String? avatar;

  static StaffProfile? fromData(Map<String, dynamic>? d) {
    if (d == null) return null;
    return StaffProfile(
      displayName: asString(d['displayName']),
      avatar: asStringOrNull(d['avatar']),
    );
  }
}

/// One team member's profile. A listener per distinct author on screen —
/// a handful in any comment thread.
final staffProfileProvider = StreamProvider.family<StaffProfile?, String>((
  ref,
  uid,
) {
  if (uid.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('staffProfiles')
      .doc(uid)
      .snapshots()
      .map((s) => StaffProfile.fromData(s.data()));
});

/// Publishes the signed-in team member's name and avatar when they differ
/// from what is published. Does nothing for students. Watched by the
/// studio home, so it runs when a team member is working, not on every
/// student's app start.
final staffProfileSyncProvider = Provider<void>((ref) {
  if (!ref.watch(staffRoleProvider).canWrite) return;
  final user = ref.watch(currentUserProvider);
  final data = ref.watch(userDataProvider).asData?.value;
  final published = ref.watch(staffProfileProvider(user?.uid ?? ''));
  if (user == null || data == null || published.isLoading) return;

  final name = (data['displayName'] as String?)?.trim() ?? '';
  final avatar = data['avatar'] as String?;
  final current = published.asData?.value;
  if (!staffProfileIsStale(current, displayName: name, avatar: avatar)) {
    return;
  }
  FirebaseFirestore.instance
      .collection('staffProfiles')
      .doc(user.uid)
      .set({
        'displayName': name,
        'avatar': ?avatar,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      .catchError((_) {});
});

/// Whether [published] no longer matches the member's own profile.
bool staffProfileIsStale(
  StaffProfile? published, {
  required String displayName,
  required String? avatar,
}) {
  if (published == null) return true;
  return published.displayName != displayName || published.avatar != avatar;
}

/// A team member's avatar, by uid. Falls back to initials from
/// [fallbackName] — the name stamped on a comment — while the profile
/// loads, or for someone who has not opened the studio since this shipped.
class StaffAvatar extends ConsumerWidget {
  const StaffAvatar({
    super.key,
    required this.uid,
    this.fallbackName,
    this.size = 28,
  });

  final String uid;
  final String? fallbackName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(staffProfileProvider(uid)).asData?.value;
    return UserAvatar.of(
      avatar: profile?.avatar,
      name: (profile?.displayName.isNotEmpty ?? false)
          ? profile!.displayName
          : fallbackName,
      seed: uid,
      size: size,
    );
  }
}
