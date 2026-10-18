import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/avatar.dart';
import '../providers/auth_provider.dart';
import '../repositories/avatar_photo_repository.dart';

/// The only thing that draws an avatar.
///
/// [UserAvatar.new] draws the signed-in student's own, from the user
/// document already being streamed. [UserAvatar.of] draws one from values
/// supplied by the caller — the studio, which cannot read anyone else's
/// user document and gets these from `staffProfiles` instead.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.size = 40})
    : _raw = null,
      _name = null,
      _seed = null,
      _explicit = false;

  const UserAvatar.of({
    super.key,
    required Object? avatar,
    required String? name,
    required String seed,
    this.size = 40,
  }) : _raw = avatar,
       _name = name,
       _seed = seed,
       _explicit = true;

  final double size;
  final Object? _raw;
  final String? _name;
  final String? _seed;
  final bool _explicit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_explicit) {
      return AvatarDisc(
        avatar: Avatar.parse(_raw, seed: _seed!),
        initials: initialsFor(_name),
        size: size,
        uid: _seed,
      );
    }

    final user = ref.watch(currentUserProvider);
    final data = ref.watch(userDataProvider).asData?.value;
    return AvatarDisc(
      avatar: Avatar.parse(data?['avatar'], seed: user?.uid ?? ''),
      initials: initialsFor(
        data?['displayName'] as String?,
        fallback: data?['username'] as String?,
      ),
      size: size,
      uid: user?.uid,
    );
  }
}

/// A resolved [Avatar] drawn as a disc. Separate from [UserAvatar] so the
/// picker can draw candidates that are not saved yet.
class AvatarDisc extends ConsumerWidget {
  const AvatarDisc({
    super.key,
    required this.avatar,
    required this.initials,
    this.size = 40,
    this.uid,
  });

  final Avatar avatar;
  final String initials;
  final double size;

  /// Whose photo, when [avatar] is one (`avatarImages/{uid}`). Without it
  /// a photo avatar draws its initials.
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = avatar.preset;
    final photo = avatar.isPhoto && uid != null && uid!.isNotEmpty
        ? ref
              .watch(avatarPhotoProvider('${uid!}@${avatar.photoVersion}'))
              .asData
              ?.value
        : null;
    if (photo != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: avatar.color,
            width: size >= 64 ? 2.5 : 1.5,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            photo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // A photo that will not decode falls back to the initials.
            errorBuilder: (_, _, _) => _initials(avatar, null),
          ),
        ),
      );
    }
    return _initials(avatar, preset);
  }

  Widget _initials(Avatar avatar, AvatarPreset? preset) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatar.color.withAlpha((0.22 * 255).round()),
        border: Border.all(color: avatar.color, width: size >= 64 ? 2.5 : 1.5),
      ),
      child: preset != null
          ? Icon(preset.icon, size: size * 0.52, color: avatar.color)
          : Text(
              initials,
              maxLines: 1,
              style: TextStyle(
                color: avatar.color,
                fontSize: size * (initials.length > 1 ? 0.36 : 0.44),
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
    );
  }
}
