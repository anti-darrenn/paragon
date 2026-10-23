/// The sound effects, as notes: what each cue plays, kept apart from the
/// code that plays it so it can be read and tested without a browser.
library;

/// The moments that make a sound.
enum SfxCue {
  /// A right answer: two rising notes.
  correct,

  /// A wrong answer: two soft falling notes, never a buzzer.
  wrong,

  /// A session finished: a short major chord, broken.
  finish,

  /// Something worth marking — a test passed, a level up, a top score.
  celebrate,
}

enum SfxWave { sine, triangle }

/// One note: [frequency] in hertz, [start] and [duration] in seconds from
/// the cue's start, [gain] 0 to 1 before the master volume.
class SfxNote {
  const SfxNote(
    this.frequency,
    this.start,
    this.duration, {
    this.wave = SfxWave.triangle,
    this.gain = 0.9,
  });

  final double frequency;
  final double start;
  final double duration;
  final SfxWave wave;
  final double gain;
}

const _c5 = 523.25, _e5 = 659.25, _g5 = 783.99, _b5 = 987.77, _c6 = 1046.5;

const Map<SfxCue, List<SfxNote>> kSfxScore = {
  SfxCue.correct: [SfxNote(_e5, 0, 0.09), SfxNote(_b5, 0.08, 0.18)],
  SfxCue.wrong: [
    SfxNote(233.08, 0, 0.14, wave: SfxWave.sine, gain: 0.7),
    SfxNote(196.0, 0.12, 0.22, wave: SfxWave.sine, gain: 0.6),
  ],
  SfxCue.finish: [
    SfxNote(_c5, 0, 0.16),
    SfxNote(_e5, 0.1, 0.16),
    SfxNote(_g5, 0.2, 0.3),
  ],
  SfxCue.celebrate: [
    SfxNote(_c5, 0, 0.14),
    SfxNote(_e5, 0.09, 0.14),
    SfxNote(_g5, 0.18, 0.14),
    SfxNote(_c6, 0.27, 0.45),
  ],
};

/// How long a cue lasts, in seconds.
double cueLength(SfxCue cue) => kSfxScore[cue]!
    .map((n) => n.start + n.duration)
    .reduce((a, b) => a > b ? a : b);
