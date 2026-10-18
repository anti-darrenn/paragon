import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paragon/core/models/avatar.dart';
import 'package:paragon/features/profile/photo_upload.dart';

/// Profile photos (owner's decision, 2026-10-17): `photo:<version>` on the
/// user, a small JPEG in `avatarImages/{uid}`.
void main() {
  group('the avatar value', () {
    test('a photo parses and round-trips', () {
      final a = Avatar.parse('photo:1760700000000', seed: 'u1');
      expect(a.isPhoto, isTrue);
      expect(a.photoVersion, 1760700000000);
      expect(a.storageValue, 'photo:1760700000000');
    });

    test('CONTROL: anything else that looks like one is initials', () {
      for (final bad in ['photo:', 'photo:abc', 'photo:12345678901234', 'pic:1']) {
        final a = Avatar.parse(bad, seed: 'u1');
        expect(a.isPhoto, isFalse, reason: bad);
        expect(a.storageValue, startsWith('initials:'), reason: bad);
      }
    });

    test('presets and initials are unchanged', () {
      expect(Avatar.parse('initials:teal', seed: 'u').isPhoto, isFalse);
    });
  });

  group('preparing a photo', () {
    Uint8List png(int w, int h) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(200, 80, 40));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('a wide photo becomes a centred 256 px square JPEG', () {
      final out = prepareAvatarJpeg(png(1200, 600));
      final decoded = img.decodeJpg(base64Decode(out))!;
      expect(decoded.width, kAvatarSide);
      expect(decoded.height, kAvatarSide);
      expect(out.length, lessThanOrEqualTo(120000));
    });

    test('not an image is refused, with words a student can act on', () {
      expect(
        () => prepareAvatarJpeg(Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<PhotoProblem>()),
      );
    });
  });
}
