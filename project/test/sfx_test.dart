import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/providers/reading_settings_provider.dart';
import 'package:paragon/core/sound/sfx.dart';
import 'package:paragon/core/sound/sfx_score.dart';
import 'package:paragon/core/sound/sound_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Sounds are off by default; these tests switch them on.
  setUp(() => Sfx.enabled = true);
  tearDown(() {
    Sfx.enabled = false;
    Sfx.debugSink = null;
  });

  group('Sfx', () {
    test('plays a cue when on, nothing when off', () {
      final heard = <SfxCue>[];
      Sfx.debugSink = heard.add;
      Sfx.unlock();
      Sfx.play(SfxCue.correct);
      Sfx.enabled = false;
      Sfx.play(SfxCue.wrong);
      expect(heard, [SfxCue.correct]);
    });

    test('every cue has notes, and none outlasts a second', () {
      for (final cue in SfxCue.values) {
        expect(kSfxScore[cue], isNotEmpty, reason: '$cue');
        expect(cueLength(cue), lessThan(1.0), reason: '$cue');
      }
    });
  });

  group('the sound setting', () {
    Future<ProviderContainer> container(Map<String, Object> stored) async {
      SharedPreferences.setMockInitialValues(stored);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(readingPrefsProvider.future);
      return c;
    }

    test('is off when nothing is stored', () async {
      final c = await container({});
      expect(c.read(soundEffectsProvider), isFalse);
    });

    test('remembers being turned on, on this device', () async {
      final c = await container({});
      await c.read(soundEffectsProvider.notifier).setEnabled(true);
      expect(c.read(soundEffectsProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SoundEffectsNotifier.key), isTrue);
    });

    test('reads a stored choice', () async {
      final c = await container({SoundEffectsNotifier.key: true});
      expect(c.read(soundEffectsProvider), isTrue);
    });
  });

  // The WAEC exam is silent by decision; this keeps it so.
  test('the WAEC exam never plays a sound or throws confetti', () {
    final exam = File('lib/features/waec_exam_screen.dart').readAsStringSync();
    expect(exam, isNot(contains('Sfx')));
    expect(exam, isNot(contains('Confetti')));
  });
}
