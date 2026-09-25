/// Reading settings — text size, line spacing, reading font, low-data mode.
///
/// **Per device, not per account.** Stored in SharedPreferences, like the
/// analytics opt-out and for the same reasons: they must work before
/// sign-in and for guests, and the right text size for a cracked phone
/// is not the right one for a school desktop. Nothing here touches
/// Firestore.
///
/// **What each setting reaches today**
///
/// * [textScaleProvider] — applied app-wide by [ReadingSettingsScope]
///   (wired in `app.dart`). It *multiplies* the operating system's text
///   scaler; it never replaces it, so a student who already enlarged text
///   in their phone settings keeps that.
/// * [lineSpacingProvider] — a multiplier for article body line height.
///   Nothing applies it yet; see its doc comment for the renderer contract.
/// * [readingFontProvider] — exposed for renderers, *not* applied app-wide.
///   Widgets across the app use `AppTheme.bodyMd` & co., which name Space
///   Grotesk explicitly, so a theme-level `textTheme` swap would change a
///   random subset of text (Material defaults) and leave the rest. That is
///   worse than not applying it. Article/lesson renderers opt in through
///   [ReadingFont.apply].
/// * [lowDataModeProvider] — lesson videos load on tap (`video_pane.dart`).
///   Article images are the renderer owner's; see its doc comment.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Values ──────────────────────────────────────────────────────────────

/// The five text-size steps. Index 1 (1.0) is the default.
const List<double> kTextScaleSteps = [0.9, 1.0, 1.15, 1.3, 1.5];
const int kDefaultTextScaleStep = 1;

/// Line spacing for long-form reading, as a multiplier on a renderer's own
/// base line height (not an absolute `height`).
enum LineSpacing {
  normal(1.0, 'Normal'),
  relaxed(1.15, 'Relaxed'),
  loose(1.3, 'Loose');

  const LineSpacing(this.multiplier, this.label);
  final double multiplier;
  final String label;
}

/// The reading font.
///
/// The alternative is **Atkinson Hyperlegible**, from the Braille
/// Institute, rather than Lexend or OpenDyslexic. It was designed and
/// tested for low-vision readers, and its whole point is making
/// confusable glyphs distinct — `I`/`l`/`1`, `O`/`0`, `b`/`d`/`p`/`q`.
/// On a maths-heavy app that matters more than for prose: `x1` vs `xl`,
/// `10` vs `1O` are exactly the misreads a WAEC candidate cannot afford.
/// Lexend's evidence is about reading speed at wider letter spacing and
/// it keeps a fairly ambiguous `l`/`I`; OpenDyslexic's evidence is weak
/// and it is not on Google Fonts. Atkinson is also available through the
/// `google_fonts` package already in the app, so this adds no dependency.
enum ReadingFont {
  standard('Default (Space Grotesk)'),
  hyperlegible('Atkinson Hyperlegible');

  const ReadingFont(this.label);
  final String label;

  /// [style] in this font. For [standard] the style is returned untouched,
  /// so a renderer that always calls this changes nothing by default.
  TextStyle apply(TextStyle style) => switch (this) {
    ReadingFont.standard => style,
    ReadingFont.hyperlegible => GoogleFonts.atkinsonHyperlegible(
      textStyle: style,
    ),
  };
}

@immutable
class ReadingSettings {
  const ReadingSettings({
    this.textScaleStep = kDefaultTextScaleStep,
    this.lineSpacing = LineSpacing.normal,
    this.font = ReadingFont.standard,
    this.lowDataMode = false,
  });

  static const defaults = ReadingSettings();

  /// Index into [kTextScaleSteps].
  final int textScaleStep;
  final LineSpacing lineSpacing;
  final ReadingFont font;
  final bool lowDataMode;

  double get textScale => kTextScaleSteps[textScaleStep];

  bool get isDefault => this == defaults;

  ReadingSettings copyWith({
    int? textScaleStep,
    LineSpacing? lineSpacing,
    ReadingFont? font,
    bool? lowDataMode,
  }) => ReadingSettings(
    textScaleStep: textScaleStep ?? this.textScaleStep,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    font: font ?? this.font,
    lowDataMode: lowDataMode ?? this.lowDataMode,
  );

  @override
  bool operator ==(Object other) =>
      other is ReadingSettings &&
      other.textScaleStep == textScaleStep &&
      other.lineSpacing == lineSpacing &&
      other.font == font &&
      other.lowDataMode == lowDataMode;

  @override
  int get hashCode =>
      Object.hash(textScaleStep, lineSpacing, font, lowDataMode);
}

// ─── Storage ─────────────────────────────────────────────────────────────

const _kTextScaleKey = 'reading.textScaleStep';
const _kLineSpacingKey = 'reading.lineSpacing';
const _kFontKey = 'reading.font';
const _kLowDataKey = 'reading.lowDataMode';

/// Every stored value is validated rather than trusted: an out-of-range
/// index or an enum name from a future build falls back to the default
/// instead of throwing during app startup.
ReadingSettings _fromPrefs(SharedPreferences prefs) {
  T byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  final step = prefs.getInt(_kTextScaleKey);
  return ReadingSettings(
    textScaleStep: step != null && step >= 0 && step < kTextScaleSteps.length
        ? step
        : kDefaultTextScaleStep,
    lineSpacing: byName(
      LineSpacing.values,
      prefs.getString(_kLineSpacingKey),
      LineSpacing.normal,
    ),
    font: byName(
      ReadingFont.values,
      prefs.getString(_kFontKey),
      ReadingFont.standard,
    ),
    lowDataMode: prefs.getBool(_kLowDataKey) ?? false,
  );
}

/// The device's SharedPreferences, or null when storage is unavailable
/// (private browsing, blocked site data, no plugin in a test). Null means
/// "use the defaults and don't persist" — never a startup failure.
///
/// `app.dart` holds the first frame until this resolves, so a student who
/// chose large text does not see the app flash at the default size first.
/// On web it resolves from localStorage within a frame.
final readingPrefsProvider = FutureProvider<SharedPreferences?>((ref) async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
});

// ─── Notifier ────────────────────────────────────────────────────────────

class ReadingSettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() {
    final prefs = ref.watch(readingPrefsProvider).asData?.value;
    return prefs == null ? ReadingSettings.defaults : _fromPrefs(prefs);
  }

  SharedPreferences? get _prefs => ref.read(readingPrefsProvider).asData?.value;

  /// Takes effect in memory at once; persisting is best-effort.
  Future<void> _save(
    ReadingSettings next,
    Future<void> Function(SharedPreferences) write,
  ) async {
    state = next;
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await write(prefs);
    } catch (_) {
      // Storage refused the write; the setting still holds this session.
    }
  }

  Future<void> setTextScaleStep(int step) => _save(
    state.copyWith(textScaleStep: step.clamp(0, kTextScaleSteps.length - 1)),
    (p) => p.setInt(_kTextScaleKey, step.clamp(0, kTextScaleSteps.length - 1)),
  );

  Future<void> setLineSpacing(LineSpacing value) => _save(
    state.copyWith(lineSpacing: value),
    (p) => p.setString(_kLineSpacingKey, value.name),
  );

  Future<void> setFont(ReadingFont value) => _save(
    state.copyWith(font: value),
    (p) => p.setString(_kFontKey, value.name),
  );

  Future<void> setLowDataMode(bool value) => _save(
    state.copyWith(lowDataMode: value),
    (p) => p.setBool(_kLowDataKey, value),
  );

  /// Removes the stored keys rather than writing default values, so a
  /// future change of default reaches students who reset.
  Future<void> reset() => _save(ReadingSettings.defaults, (p) async {
    await p.remove(_kTextScaleKey);
    await p.remove(_kLineSpacingKey);
    await p.remove(_kFontKey);
    await p.remove(_kLowDataKey);
  });
}

final readingSettingsProvider =
    NotifierProvider<ReadingSettingsNotifier, ReadingSettings>(
      ReadingSettingsNotifier.new,
    );

// ─── Read-only views, for other features ─────────────────────────────────

/// The student's text-size multiplier: one of [kTextScaleSteps], 1.0 by
/// default. Already applied app-wide by [ReadingSettingsScope]; renderers
/// must **not** multiply font sizes by it again.
final textScaleProvider = Provider<double>(
  (ref) => ref.watch(readingSettingsProvider.select((s) => s.textScale)),
);

/// Line-spacing multiplier for long-form reading: 1.0 (normal), 1.15
/// (relaxed) or 1.3 (loose).
///
/// **Contract for the article renderer:** multiply the body text's own
/// base `height` by this value (e.g. `height: 1.6 * multiplier`), for
/// prose paragraphs, list items and quotes. Leave headings, display maths
/// and code alone — their spacing is structural, not a reading aid.
/// Nothing applies this yet.
final lineSpacingProvider = Provider<double>(
  (ref) => ref.watch(
    readingSettingsProvider.select((s) => s.lineSpacing.multiplier),
  ),
);

/// The student's reading font. Renderers apply it with
/// [ReadingFont.apply] on body-text styles (a no-op for the default).
/// Not applied app-wide — see the file comment.
final readingFontProvider = Provider<ReadingFont>(
  (ref) => ref.watch(readingSettingsProvider.select((s) => s.font)),
);

/// Low-data mode, off by default.
///
/// **Contract:** when true, heavy media loads only on an explicit tap and
/// nothing is prefetched.
/// * Lesson videos: implemented — `VideoPane` shows a "Tap to load video"
///   card and does not create the YouTube iframe until tapped.
/// * Article images: for the article renderer owner — when true, images
///   load on tap (show a placeholder with the alt text / caption and a
///   "Tap to load image" affordance); nothing is prefetched or precached.
///   A tap loads that one image only.
final lowDataModeProvider = Provider<bool>(
  (ref) => ref.watch(readingSettingsProvider.select((s) => s.lowDataMode)),
);

// ─── App-wide application ────────────────────────────────────────────────

/// A [TextScaler] that multiplies [base] by [factor], preserving whatever
/// the base does (including a non-linear OS scaler on Android 14+).
class MultipliedTextScaler extends TextScaler {
  const MultipliedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is MultipliedTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'MultipliedTextScaler($base x $factor)';
}

/// Applies the text-size setting below it by rewriting the ambient
/// [MediaQuery]'s `textScaler`. At the default (1.0) the system scaler is
/// passed through **unchanged** — the same object, not a wrapper.
///
/// Wired in `app.dart` via `MaterialApp.builder`, so it sits above the
/// Navigator and reaches every route, dialog and bottom sheet.
class ReadingSettingsScope extends ConsumerWidget {
  const ReadingSettingsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(textScaleProvider);
    final media = MediaQuery.of(context);
    // Always the same shape: returning a bare [child] at 1.0 and a wrapped
    // one otherwise would remount the whole app below (the Navigator, any
    // playing video) the moment the size changed from the default.
    return MediaQuery(
      data: factor == 1.0
          ? media
          : media.copyWith(
              textScaler: MultipliedTextScaler(media.textScaler, factor),
            ),
      child: child,
    );
  }
}
