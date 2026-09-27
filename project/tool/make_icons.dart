// Generates the web icons, favicon and link-preview image from the logo.
//
//   dart run tool/make_icons.dart
//
// The source is assets/images/paragon_logo.png (1140x300): the globe mark
// on the left becomes the square icons, the full wordmark the share image.
// Re-run after changing the logo; the outputs are committed.

import 'dart:io';

import 'package:image/image.dart' as img;

/// The app's dark background (`AppColors` background, `#0D1117`).
final _background = img.ColorRgba8(0x0D, 0x11, 0x17, 0xFF);

/// Where the globe sits in the logo: a square around the circle, found by
/// eye and checked against the rendered preview.
const _globeX = 82;
const _globeY = 22;
const _globeSize = 272;

void main() {
  final logo = img.decodePng(
    File('assets/images/paragon_logo.png').readAsBytesSync(),
  )!;
  final globe = img.copyCrop(
    logo,
    x: _globeX,
    y: _globeY,
    width: _globeSize,
    height: _globeSize,
  );

  // A plain icon may fill most of its square. A maskable one may be
  // cropped to a circle of 80% diameter by the platform, so the mark
  // stays inside that safe zone.
  _write('web/icons/Icon-192.png', _square(globe, 192, 0.86));
  _write('web/icons/Icon-512.png', _square(globe, 512, 0.86));
  _write('web/icons/Icon-maskable-192.png', _square(globe, 192, 0.62));
  _write('web/icons/Icon-maskable-512.png', _square(globe, 512, 0.62));
  _write('web/favicon.png', _square(globe, 32, 0.94));

  // 1200x630 is the size link previews (WhatsApp, X, Facebook) expect.
  final share = img.Image(width: 1200, height: 630, numChannels: 4);
  img.fill(share, color: _background);
  final wordmark = img.copyResize(
    logo,
    width: 960,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    share,
    wordmark,
    dstX: (1200 - wordmark.width) ~/ 2,
    dstY: (630 - wordmark.height) ~/ 2,
  );
  _write('web/og-image.png', share);
}

/// [mark] centred on a [size] square of the app background, scaled to
/// [fill] of its width.
img.Image _square(img.Image mark, int size, double fill) {
  final out = img.Image(width: size, height: size, numChannels: 4);
  img.fill(out, color: _background);
  final side = (size * fill).round();
  final scaled = img.copyResize(
    mark,
    width: side,
    height: side,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    out,
    scaled,
    dstX: (size - side) ~/ 2,
    dstY: (size - side) ~/ 2,
  );
  return out;
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}
