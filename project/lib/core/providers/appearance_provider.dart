import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reading_settings_provider.dart';

/// Dark, light, or whatever the device uses.
///
/// Dark is the default and was the only theme until the palette refactor
/// (`core/theme/app_palette.dart`) made every screen able to draw either.
/// Stored on the device like the reading settings, and — for a signed-in
/// account — copied to `users/{uid}.prefs.theme` by
/// `account_prefs_sync.dart`. The stored names are what the rules accept
/// (`dark`, `light`, `system`), so do not rename them.
enum Appearance {
  dark(ThemeMode.dark, 'Dark'),
  light(ThemeMode.light, 'Light'),
  system(ThemeMode.system, 'Match device');

  const Appearance(this.mode, this.label);
  final ThemeMode mode;
  final String label;

  static Appearance parse(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return dark;
  }
}

const _kAppearanceKey = 'appearance.theme';

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    final prefs = ref.watch(readingPrefsProvider).asData?.value;
    return Appearance.parse(prefs?.getString(_kAppearanceKey));
  }

  /// Changes the theme on this device. The account copy, if any, follows
  /// through the prefs sync.
  Future<void> set(Appearance value) async {
    state = value;
    try {
      final SharedPreferences? prefs = await ref.read(
        readingPrefsProvider.future,
      );
      await prefs?.setString(_kAppearanceKey, value.name);
    } catch (_) {
      // Storage refused; the choice still holds this session.
    }
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);
