/// Picking and preparing a profile photo. **Deferred-imported** by the
/// profile editor, so `file_picker` and `image` are downloaded only by a
/// student who actually uploads one (as with the studio's image upload).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// The stored photo's side, in pixels: twice the largest avatar drawn.
const kAvatarSide = 256;

/// The largest file accepted, and the largest image opened.
const _maxBytes = 15 * 1024 * 1024;
const _maxPixels = 40 * 1000 * 1000;

class PhotoProblem implements Exception {
  const PhotoProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// [bytes] as a square [kAvatarSide] JPEG, centred, in base64: what
/// `avatarImages/{uid}` stores. Metadata (location, camera) is not carried
/// over: the image is re-encoded from its pixels. Throws [PhotoProblem].
String prepareAvatarJpeg(Uint8List bytes) {
  if (bytes.length > _maxBytes) {
    throw const PhotoProblem('That photo is over 15 MB. Try a smaller one.');
  }
  img.Image? image;
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder != null && info != null) {
      if (info.width <= 0 ||
          info.height <= 0 ||
          info.width * info.height > _maxPixels) {
        throw const PhotoProblem('That image is too large to open.');
      }
      image = decoder.decode(bytes, frame: 0);
    }
  } on PhotoProblem {
    rethrow;
  } catch (_) {
    image = null;
  }
  if (image == null) {
    throw const PhotoProblem("That file isn't a photo Paragon can read.");
  }
  // Phones store photos sideways with an orientation tag; apply it.
  image = img.bakeOrientation(image);
  final side = min(image.width, image.height);
  final square = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = img.copyResize(
    square,
    width: kAvatarSide,
    height: kAvatarSide,
    interpolation: img.Interpolation.average,
  );
  for (final quality in [82, 70, 60]) {
    final out = base64Encode(img.encodeJpg(small, quality: quality));
    if (out.length <= 120000) return out;
  }
  throw const PhotoProblem('That photo could not be made small enough.');
}

/// Opens the file picker; the prepared photo, or null if nothing was picked.
Future<String?> pickAvatarPhoto() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  final size = await file.length();
  if (size != null && size > _maxBytes) {
    throw const PhotoProblem('That photo is over 15 MB. Try a smaller one.');
  }
  return prepareAvatarJpeg(await file.readAsBytes());
}
