import 'package:flutter/foundation.dart';

import 'sfx_score.dart';
import 'synth.dart';

export 'sfx_score.dart' show SfxCue;

/// Sound effects: short synthesised tones for a right or wrong answer and
/// a finished session.
///
/// **Off by default**, with a switch in Settings → Reading and display
/// (`soundEffectsProvider`, kept on the device only), which `app.dart`
/// mirrors into [enabled]. A static facade rather than a provider, so a
/// session widget can play a cue without a ProviderScope.
///
/// **Never in the WAEC exam**, and never for a question marked at the end:
/// those screens do not call it (`waec_exam_screen.dart` is checked by a
/// test for any mention of `Sfx`).
abstract final class Sfx {
  static bool enabled = false;

  /// Master volume, 0 to 1. Quiet on purpose: these play in classrooms.
  static double volume = 0.15;

  /// Every cue that would play, for tests. Null in the app.
  @visibleForTesting
  static void Function(SfxCue cue)? debugSink;

  /// Call inside a tap or key press, before any cue: browsers allow sound
  /// only after the person has interacted with the page.
  static void unlock() {
    if (enabled) synthUnlock();
  }

  static void play(SfxCue cue) {
    if (!enabled) return;
    debugSink?.call(cue);
    synthPlay(kSfxScore[cue]!, volume);
  }
}
