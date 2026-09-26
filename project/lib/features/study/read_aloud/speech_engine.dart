import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The text-to-speech engine read-aloud drives, behind an interface so the
/// controls can be tested without a platform channel.
///
/// One utterance at a time: [speak] starts one, [onComplete] fires when it
/// ends of its own accord. Every method may throw a platform exception;
/// the controller catches them all.
abstract class SpeechEngine {
  /// Whether this device can speak at all. False, never a throw, when
  /// there is no speech synthesis or no voice.
  Future<bool> isAvailable();

  Future<void> speak(String text);
  Future<void> pause();

  /// Continues the utterance [pause] interrupted. [text] is that
  /// utterance, for engines that resume by re-speaking it.
  Future<void> resume(String text);

  Future<void> stop();

  /// 1.0 is the engine's normal speed; 0.75 to 1.5 are offered.
  Future<void> setRate(double multiplier);

  set onComplete(VoidCallback? callback);
  set onError(void Function(Object error)? callback);
}

/// [SpeechEngine] over `flutter_tts`: the browser's `speechSynthesis` on
/// web, the system voice on Android.
///
/// Created lazily, on first use, so a lesson that never reads aloud never
/// touches the plugin.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTts? _tts;
  VoidCallback? _onComplete;
  void Function(Object)? _onError;

  FlutterTts get _engine {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    tts.setCompletionHandler(() => _onComplete?.call());
    tts.setErrorHandler((message) {
      // Cancelling an utterance is reported as an error by browsers
      // ("interrupted", "canceled"). That is us stopping, not a failure.
      final text = '$message'.toLowerCase();
      if (text.contains('interrupt') || text.contains('cancel')) return;
      _onError?.call(message ?? 'speech error');
    });
    _tts = tts;
    return tts;
  }

  @override
  set onComplete(VoidCallback? callback) => _onComplete = callback;

  @override
  set onError(void Function(Object error)? callback) => _onError = callback;

  @override
  Future<bool> isAvailable() async {
    try {
      final tts = _engine;
      await tts.awaitSpeakCompletion(false);
      // Browsers load their voice list asynchronously — Chrome returns an
      // empty list on the first call — so an empty answer is asked again
      // briefly before it is believed.
      for (var attempt = 0; attempt < 4; attempt++) {
        final voices = await tts.getVoices;
        if (voices is List && voices.isNotEmpty) {
          // British English where the device has it; the engine keeps its
          // default voice otherwise. After the voice list, because on web
          // choosing a language means choosing one of those voices.
          try {
            await tts.setLanguage('en-GB');
          } catch (_) {}
          return true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text) async => _engine.speak(text);

  @override
  Future<void> pause() async => _engine.pause();

  // Both platforms resume a paused utterance when asked to speak it again:
  // the web plugin calls `speechSynthesis.resume()`, Android re-speaks from
  // the paused position.
  @override
  Future<void> resume(String text) async => _engine.speak(text);

  @override
  Future<void> stop() async => _engine.stop();

  // The platforms disagree about what "normal" is: the Web Speech API
  // speaks at 1.0, flutter_tts on Android and iOS at 0.5.
  @override
  Future<void> setRate(double multiplier) async =>
      _engine.setSpeechRate(kIsWeb ? multiplier : 0.5 * multiplier);
}

/// The engine read-aloud uses. Overridden in tests with a fake.
final speechEngineProvider = Provider<SpeechEngine>((ref) => FlutterTtsEngine());
