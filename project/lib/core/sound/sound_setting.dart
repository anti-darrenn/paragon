import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reading_settings_provider.dart';

/// The device's sound-effects switch. **On unless turned off** (owner's
/// decision, 2026-10-23).
///
/// Kept in SharedPreferences on this device only — not in
/// `users/{uid}.prefs`, whose keys the rules fix (`prefsAreValid`), and
/// not cleared on sign-out: it belongs to the device, like its volume.
class SoundEffectsNotifier extends Notifier<bool> {
  static const key = 'fx.sound';

  @override
  bool build() {
    final prefs = ref.watch(readingPrefsProvider).asData?.value;
    return prefs?.getBool(key) ?? true;
  }

  Future<void> setEnabled(bool on) async {
    state = on;
    final prefs = ref.read(readingPrefsProvider).asData?.value;
    try {
      await prefs?.setBool(key, on);
    } catch (_) {
      // Storage refused; the choice still holds for this session.
    }
  }
}

final soundEffectsProvider = NotifierProvider<SoundEffectsNotifier, bool>(
  SoundEffectsNotifier.new,
);
