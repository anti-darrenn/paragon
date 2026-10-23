/// Plays [SfxNote]s. On the web, through the browser's Web Audio (tones
/// made on the spot: no audio files, nothing downloaded); elsewhere —
/// the Android build, tests — silently.
library;

export 'synth_other.dart' if (dart.library.js_interop) 'synth_web.dart';
