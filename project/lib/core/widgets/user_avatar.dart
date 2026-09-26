import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/avatar.dart';
import '../providers/auth_provider.dart';

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
    );
  }
}

/// A resolved [Avatar] drawn as a disc. Separate from [UserAvatar] so the
/// picker can draw candidates that are not saved yet.
class AvatarDisc extends StatelessWidget {
  const AvatarDisc({
    super.key,
    required this.avatar,
    required this.initials,
    this.size = 40,
  });

  final Avatar avatar;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final preset = avatar.preset;
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
