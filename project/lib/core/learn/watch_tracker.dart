/// Decides whether a video lesson has actually been watched.
///
/// Counts seconds of playback, not the furthest position reached, so
/// dragging the scrubber to the end earns nothing. Each position update
/// adds the time since the previous one, but only when that step is a
/// small forward move — a jump larger than [maxStepSeconds] (either way)
/// is a seek and adds nothing.
///
/// Complete at [completeFraction] of the duration, or when the video ends
/// having played at least [endedFraction] of it — the second rule forgives
/// a student who skipped a slow intro but sat through the rest.
///
/// With no known duration it never completes: there is nothing to measure
/// against, and a checkmark that means nothing is worse than none.
class WatchTracker {
  WatchTracker({double? durationSeconds}) : _duration = durationSeconds;

  static const double maxStepSeconds = 2.0;
  static const double completeFraction = 0.9;
  static const double endedFraction = 0.5;

  double? _duration;
  double _watched = 0;
  double? _last;
  bool _ended = false;

  /// The player's own duration beats the authored one, which can be wrong.
  set durationSeconds(double? seconds) {
    if (seconds != null && seconds > 0) _duration = seconds;
  }

  double? get durationSeconds => _duration;
  double get watchedSeconds => _watched;

  void onPosition(double seconds) {
    final last = _last;
    if (last != null) {
      final step = seconds - last;
      if (step > 0 && step <= maxStepSeconds) _watched += step;
    }
    _last = seconds;
  }

  void onEnded() => _ended = true;

  bool get isComplete {
    final duration = _duration;
    if (duration == null || duration <= 0) return false;
    final fraction = _watched / duration;
    return fraction >= completeFraction ||
        (_ended && fraction >= endedFraction);
  }
}
