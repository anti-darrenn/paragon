import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_engine.dart';
import 'speech_segments.dart';

enum ReadAloudStatus { idle, playing, paused }

@immutable
class ReadAloudState {
  const ReadAloudState({
    this.status = ReadAloudStatus.idle,
    this.segments = const [],
    this.index = 0,
  });

  final ReadAloudStatus status;
  final List<SpeechSegment> segments;

  /// The segment being read (or paused in).
  final int index;

  bool get isActive => status != ReadAloudStatus.idle;

  SpeechSegment? get current =>
      isActive && index >= 0 && index < segments.length
      ? segments[index]
      : null;

  /// The top-level block being read; null when nothing is.
  String? get currentKey => current?.blockKey;
}

/// The speeds offered. 1.0 is the engine's normal speed.
const List<double> kReadAloudRates = [0.75, 1.0, 1.25, 1.5];

/// Reading speed, for the rest of the app session. Not persisted: it is a
/// per-sitting choice, and one more stored preference is one more thing
/// the settings page would have to explain.
class ReadAloudRate extends Notifier<double> {
  @override
  double build() => 1.0;

  void set(double rate) => state = rate;
}

final readAloudRateProvider = NotifierProvider<ReadAloudRate, double>(
  ReadAloudRate.new,
);

/// Whether this device can read aloud at all. Checked once per app
/// session: a browser without speech synthesis, or one with no voices,
/// answers false and the Listen button is shown disabled.
final speechAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(speechEngineProvider).isAvailable();
  } catch (_) {
    return false;
  }
});

/// Read-aloud for one article, keyed by resource id.
///
/// Auto-disposed: the Listen button and the block marks are its only
/// listeners, so leaving the lesson disposes it — and disposing stops the
/// voice. Nothing keeps reading after the student has gone.
final readAloudProvider = NotifierProvider.autoDispose
    .family<ReadAloudController, ReadAloudState, String>(
      ReadAloudController.new,
    );

/// Reads segments one after another: speak one, wait for the engine to say
/// it finished, speak the next.
///
/// Every engine call is guarded. A platform exception mid-lesson stops
/// reading and returns to idle; it never reaches the widget tree.
class ReadAloudController extends Notifier<ReadAloudState> {
  ReadAloudController(this.resourceId);

  final String resourceId;

  late SpeechEngine _engine;
  var _disposed = false;

  /// Mirrors `state.isActive` for `onDispose`, which must not read state.
  var _active = false;

  void _set(ReadAloudState next) {
    state = next;
    _active = next.isActive;
  }

  @override
  ReadAloudState build() {
    _engine = ref.read(speechEngineProvider);
    ref.onDispose(() {
      _disposed = true;
      if (_active) _guard(_engine.stop);
    });
    return const ReadAloudState();
  }

  /// Starts reading [segments] from the beginning.
  Future<void> play(List<SpeechSegment> segments) async {
    if (segments.isEmpty) return;
    // The engine is shared; whichever article last pressed Listen owns its
    // callbacks.
    _engine.onComplete = _onComplete;
    _engine.onError = _onError;
    _set(ReadAloudState(status: ReadAloudStatus.playing, segments: segments));
    await _speakCurrent();
  }

  Future<void> pause() async {
    if (state.status != ReadAloudStatus.playing) return;
    _set(_with(ReadAloudStatus.paused));
    if (!await _guard(_engine.pause)) _toIdle();
  }

  Future<void> resume() async {
    final seg = state.current;
    if (state.status != ReadAloudStatus.paused || seg == null) return;
    _set(_with(ReadAloudStatus.playing));
    if (!await _guard(() => _engine.resume(seg.text))) _toIdle();
  }

  Future<void> stop() async {
    if (!state.isActive) return;
    _toIdle();
    await _guard(_engine.stop);
  }

  ReadAloudState _with(ReadAloudStatus status, {int? index}) => ReadAloudState(
    status: status,
    segments: state.segments,
    index: index ?? state.index,
  );

  void _toIdle() {
    if (_disposed) return;
    _set(const ReadAloudState());
  }

  Future<void> _speakCurrent() async {
    final seg = state.current;
    if (seg == null) return _toIdle();
    final rate = ref.read(readAloudRateProvider);
    final ok = await _guard(() async {
      await _engine.setRate(rate);
      await _engine.speak(seg.text);
    });
    if (!ok) _toIdle();
  }

  void _onComplete() {
    // A completion after Stop, Pause or dispose is the engine catching up,
    // not a cue to read on.
    if (_disposed || state.status != ReadAloudStatus.playing) return;
    final next = state.index + 1;
    if (next >= state.segments.length) return _toIdle();
    _set(_with(ReadAloudStatus.playing, index: next));
    _speakCurrent();
  }

  void _onError(Object error) {
    if (_disposed || !state.isActive) return;
    debugPrint('read aloud: $error');
    _toIdle();
  }

  /// Runs an engine call; false if it threw.
  Future<bool> _guard(Future<void> Function() call) async {
    try {
      await call();
      return true;
    } catch (e) {
      debugPrint('read aloud: $e');
      return false;
    }
  }
}
