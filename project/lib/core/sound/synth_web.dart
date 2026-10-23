import 'package:web/web.dart' as web;

import 'sfx_score.dart';

/// One audio context for the whole app, made on first use. Browsers only
/// let a page start sound after the person has interacted with it, so
/// [synthUnlock] is called from inside a tap; later cues then play.
web.AudioContext? _context;

web.AudioContext? _ready() {
  try {
    final c = _context ??= web.AudioContext();
    if (c.state == 'suspended') c.resume();
    return c;
  } catch (_) {
    // No Web Audio (an old browser, a locked-down profile): stay silent.
    return null;
  }
}

void synthUnlock() => _ready();

void synthPlay(List<SfxNote> notes, double volume) {
  final c = _ready();
  if (c == null) return;
  try {
    final master = c.createGain()..gain.value = volume;
    master.connect(c.destination);
    final t0 = c.currentTime + 0.01;
    for (final n in notes) {
      final start = t0 + n.start;
      final end = start + n.duration;
      final osc = c.createOscillator()
        ..type = n.wave.name
        ..frequency.value = n.frequency;
      // A quick fade in and a longer fade out, so no note clicks.
      final env = c.createGain();
      env.gain
        ..setValueAtTime(0.0001, start)
        ..exponentialRampToValueAtTime(n.gain, start + 0.012)
        ..exponentialRampToValueAtTime(0.0001, end);
      osc.connect(env);
      env.connect(master);
      osc.start(start);
      osc.stop(end + 0.02);
    }
  } catch (_) {
    // A sound effect is never worth an error.
  }
}
