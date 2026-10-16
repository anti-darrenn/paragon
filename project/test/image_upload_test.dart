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

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
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

  test('an SVG that could run or fetch anything is refused', () {
    String svg(String inner, [String attrs = '']) =>
        '<svg xmlns="http://www.w3.org/2000/svg"$attrs>$inner</svg>';
    for (final bad in [
      svg('<script>alert(1)</script>'),
      svg('<rect onclick="x()"/>'),
      svg('', ' onload="x()"'),
      svg('<foreignObject><div/></foreignObject>'),
      svg('<a href="javascript:alert(1)"><text>x</text></a>'),
      svg('<image href="https://evil.example/p.png"/>'),
      svg('<image href="//evil.example/p.png"/>'),
      svg("<style>@import 'https://evil.example/x.css';</style>"),
    ]) {
      expect(svgProblem(bad), isNotNull, reason: bad);
      expect(
        () => prepareLessonImage(Uint8List.fromList(utf8.encode(bad)), 'd.svg'),
        throwsFormatException,
        reason: bad,
      );
    }
    // Control: internal references and inline images are fine.
    expect(
      svgProblem(
        svg(
          '<defs><path id="a"/></defs><use href="#a"/>'
          '<rect fill="url(#g)"/><image href="data:image/png;base64,AA=="/>',
        ),
      ),
      isNull,
    );
  });

  test('a small file claiming an enormous canvas is refused unread', () {
    // A real PNG header for a 20000x20000 image (400 MP) with no pixels
    // behind it: the size is read from the header, never decoded.
    final header = img.encodePng(img.Image(width: 1, height: 1));
    final bomb = Uint8List.fromList(header);
    // IHDR width and height live at bytes 16-23.
    final view = ByteData.sublistView(bomb);
    view.setUint32(16, 20000);
    view.setUint32(20, 20000);
    // Re-sign the IHDR chunk (type + data, bytes 12-28) so it is a valid
    // header, not merely a corrupt file.
    view.setUint32(29, _crc32(bomb.sublist(12, 29)));
    expect(
      () => prepareLessonImage(bomb, 'bomb.png'),
      throwsA(isA<ImageTooLarge>()),
    );
  });

  test('a file over the upload cap is refused before decoding', () {
    expect(
      () => prepareLessonImage(Uint8List(kMaxUploadBytes + 1), 'big.png'),
      throwsA(isA<ImageTooLarge>()),
    );
  });
}
