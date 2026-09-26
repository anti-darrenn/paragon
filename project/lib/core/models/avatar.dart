import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A student's avatar: one of a fixed set of presets, or their initials
/// on a colour they chose.
///
/// Stored as a single string on `users/{uid}.avatar` — `preset:<id>` or
/// `initials:<colorKey>` — and nothing else. There are deliberately no
/// uploads: most students are minors, and a picture only they can see is
/// not worth a moderation queue. `firestore.rules` checks the same shape
/// (`^(preset|initials):[a-z_]{2,20}$`), so the two must change together.
///
/// Everything here is pure, so the parse and the fallback are testable
/// without a widget tree.
@immutable
class Avatar {
  const Avatar._({required this.preset, required this.colorKey});

  /// Set for a preset avatar, null for initials.
  final AvatarPreset? preset;

  /// The colour key initials are drawn on. For a preset it is the preset's
  /// own colour.
  final String colorKey;

  bool get isPreset => preset != null;

  Color get color => avatarSwatch(colorKey);

  /// The stored form, or what would be stored.
  String get storageValue =>
      preset != null ? 'preset:${preset!.id}' : 'initials:$colorKey';

  static Avatar forPreset(AvatarPreset preset) =>
      Avatar._(preset: preset, colorKey: preset.colorKey);

  static Avatar initials(String colorKey) => Avatar._(
    preset: null,
    colorKey: AppColors.avatarSwatches.containsKey(colorKey)
        ? colorKey
        : AppColors.avatarSwatches.keys.first,
  );

  /// Reads a stored value. Anything missing, malformed or naming a preset
  /// or colour that no longer exists falls back to initials on a colour
  /// derived from [seed] (the uid), so an avatar can never fail to draw and
  /// the fallback is stable across sessions and devices.
  static Avatar parse(Object? raw, {required String seed}) {
    if (raw is String) {
      final colon = raw.indexOf(':');
      if (colon > 0) {
        final kind = raw.substring(0, colon);
        final value = raw.substring(colon + 1);
        if (kind == 'preset') {
          final preset = AvatarPreset.byId(value);
          if (preset != null) return forPreset(preset);
        } else if (kind == 'initials' &&
            AppColors.avatarSwatches.containsKey(value)) {
          return Avatar._(preset: null, colorKey: value);
        }
      }
    }
    return Avatar._(preset: null, colorKey: fallbackColorKey(seed));
  }

  /// A colour key picked from [seed]. A plain sum of code units: the same
  /// answer on web (where ints are doubles) and native, with no hashing
  /// library.
  static String fallbackColorKey(String seed) {
    final keys = AppColors.avatarSwatches.keys.toList(growable: false);
    var sum = 0;
    for (final unit in seed.codeUnits) {
      sum = (sum + unit) % 1000003;
    }
    return keys[sum % keys.length];
  }

  @override
  bool operator ==(Object other) =>
      other is Avatar && other.storageValue == storageValue;

  @override
  int get hashCode => storageValue.hashCode;
}

Color avatarSwatch(String key) =>
    AppColors.avatarSwatches[key] ?? AppColors.primary;

/// Up to two letters for an initials avatar: the first letter of the first
/// two words of [name], or of [fallback] (the username) when the name is
/// blank, or `?` when both are.
String initialsFor(String? name, {String? fallback}) {
  String pick(String? source) {
    final words = (source ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words[1].characters.first).toUpperCase();
  }

  final fromName = pick(name);
  if (fromName.isNotEmpty) return fromName;
  final fromFallback = pick(fallback);
  return fromFallback.isNotEmpty ? fromFallback : '?';
}

/// One preset: an icon on a colour. Ids are stored in user documents, so
/// they are permanent — add new ones, never rename or remove one (a
/// removed id falls back to initials, which is survivable but a surprise).
@immutable
class AvatarPreset {
  const AvatarPreset(this.id, this.icon, this.colorKey);

  final String id;
  final IconData icon;
  final String colorKey;

  static const List<AvatarPreset> all = [
    AvatarPreset('owl', Icons.nightlight_round, 'violet'),
    AvatarPreset('rocket', Icons.rocket_launch_rounded, 'orange'),
    AvatarPreset('atom', Icons.science_rounded, 'teal'),
    AvatarPreset('pi', Icons.calculate_rounded, 'red'),
    AvatarPreset('book', Icons.auto_stories_rounded, 'amber'),
    AvatarPreset('leaf', Icons.eco_rounded, 'green'),
    AvatarPreset('bolt', Icons.bolt_rounded, 'lime'),
    AvatarPreset('globe', Icons.public_rounded, 'sky'),
    AvatarPreset('idea', Icons.lightbulb_rounded, 'amber'),
    AvatarPreset('music', Icons.music_note_rounded, 'pink'),
    AvatarPreset('palette', Icons.palette_rounded, 'purple'),
    AvatarPreset('ball', Icons.sports_soccer_rounded, 'green'),
    AvatarPreset('star', Icons.star_rounded, 'orange'),
    AvatarPreset('paw', Icons.pets_rounded, 'slate'),
    AvatarPreset('brain', Icons.psychology_rounded, 'indigo'),
    AvatarPreset('plane', Icons.flight_rounded, 'blue'),
  ];

  static AvatarPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
