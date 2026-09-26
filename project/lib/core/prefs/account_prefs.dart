/// Settings that follow a signed-in account between devices, stored as
/// `users/{uid}.prefs`:
///
/// `{textScaleStep, lineSpacing, font, lowDataMode, analytics, theme}`
///
/// Every key is optional and every value is checked by
/// `firestore.rules`, so this and the rules change together.
///
/// **What does not sync.** Saved-for-offline topics — the cache is on the
/// device, so the list must be too. Guests — they have no account; their
/// settings stay on the device exactly as before.
///
/// **Who wins.** The account's reading settings are applied to a device
/// when they arrive; a change made on a device is written to both. For
/// analytics, turning it **off** anywhere turns it off everywhere, while
/// turning it on applies to that device and is never pushed onto another
/// device that has it off — an opt-out is the one preference that must
/// never be undone from somewhere else.
library;

import '../models/firestore_parsing.dart';
import '../providers/appearance_provider.dart';
import '../providers/reading_settings_provider.dart';

/// The account's copy of [settings].
Map<String, Object> readingToPrefs(ReadingSettings settings) => {
  'textScaleStep': settings.textScaleStep,
  'lineSpacing': settings.lineSpacing.name,
  'font': settings.font.name,
  'lowDataMode': settings.lowDataMode,
};

/// The reading settings stored on the account, or null when it holds
/// none yet. Values from a newer or older build fall back to defaults one
/// by one, as the device store does.
ReadingSettings? readingFromPrefs(Object? prefs) {
  if (prefs is! Map) return null;
  const keys = ['textScaleStep', 'lineSpacing', 'font', 'lowDataMode'];
  if (!keys.any(prefs.containsKey)) return null;

  T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  final step = asIntOrNull(prefs['textScaleStep']);
  return ReadingSettings(
    textScaleStep: step != null && step >= 0 && step < kTextScaleSteps.length
        ? step
        : kDefaultTextScaleStep,
    lineSpacing: byName(
      LineSpacing.values,
      prefs['lineSpacing'],
      LineSpacing.normal,
    ),
    font: byName(ReadingFont.values, prefs['font'], ReadingFont.standard),
    lowDataMode: asBool(prefs['lowDataMode']),
  );
}

/// The account's theme, or null when never chosen.
Appearance? appearanceFromPrefs(Object? prefs) {
  if (prefs is! Map || prefs['theme'] is! String) return null;
  return Appearance.parse(prefs['theme']);
}

/// The account's analytics choice, or null when never made.
bool? analyticsFromPrefs(Object? prefs) {
  if (prefs is! Map) return null;
  final v = prefs['analytics'];
  return v is bool ? v : null;
}

/// Whether a device with analytics [deviceEnabled] should switch it off
/// because the account says so. Never switches it on.
bool accountTurnsAnalyticsOff({
  required bool deviceEnabled,
  required bool? account,
}) => deviceEnabled && account == false;
