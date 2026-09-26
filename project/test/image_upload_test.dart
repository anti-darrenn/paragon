import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paragon/features/admin/studio/image_upload.dart';

Uint8List _png(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Noise, so compression has something to chew on.
      image.setPixelRgba(
        x,
        y,
        (x * 7 + y * 13) % 256,
        (x * y) % 256,
        (x + y) % 256,
        alpha ? 128 : 255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('an SVG is stored as its markup', () {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';
    final p = prepareLessonImage(Uint8List.fromList(utf8.encode(svg)), 'd.svg');
    expect(p.mime, 'image/svg+xml');
    expect(p.data, svg);
  });

  test('a wide photo is scaled down and fits the cap', () {
    final p = prepareLessonImage(_png(3000, 2000), 'photo.png');
    // Noise is the worst case for JPEG, so this one also steps the size
    // down; the aspect ratio is kept.
    expect(p.width, lessThanOrEqualTo(kMaxImageWidth));
    expect(p.width! / p.height!, closeTo(1.5, 0.01));
    expect(p.data.length, lessThanOrEqualTo(kMaxAssetChars));
    expect(p.mime, 'image/jpeg');
  });

  test('a small transparent diagram stays PNG', () {
    final p = prepareLessonImage(_png(200, 100, alpha: true), 'diagram.png');
    expect(p.mime, 'image/png');
    expect((p.width, p.height), (200, 100));
  });

  test('control: a file that is not an image is refused', () {
    expect(
      () =>
          prepareLessonImage(Uint8List.fromList(utf8.encode('hello')), 'x.png'),
      throwsFormatException,
    );
    expect(
      () =>
          prepareLessonImage(Uint8List.fromList(utf8.encode('hello')), 'x.svg'),
      throwsFormatException,
    );
  });
}
