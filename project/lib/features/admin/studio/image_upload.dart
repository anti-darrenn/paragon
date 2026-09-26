import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// Picking, compressing and storing a lesson image.
///
/// **Editor-only, and deferred-imported by the editor** (`deferred as`),
/// so the image codecs and the file picker are never part of what a
/// student downloads.
///
/// Images go to `lessonAssets/{id}` in Firestore, not Cloud Storage — the
/// Spark plan has no bucket. The rules cap the stored string at 900,000
/// characters, well under Firestore's 1 MiB document limit, so an image is
/// shrunk until its base64 fits.

/// The rules' cap on `lessonAssets.data`.
const kMaxAssetChars = 900000;

/// Widest a stored raster image gets. Lesson columns are at most ~760px;
/// double that stays sharp on high-density screens.
const kMaxImageWidth = 1600;

class PreparedImage {
  const PreparedImage({
    required this.mime,
    required this.data,
    this.width,
    this.height,
  });

  final String mime;

  /// Base64 for raster images; the markup itself for SVG.
  final String data;
  final int? width;
  final int? height;
}

class ImageTooLarge implements Exception {
  const ImageTooLarge(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns an uploaded file into what `lessonAssets` stores.
///
/// SVG is kept as text (diagrams are small and stay sharp). Everything else
/// is decoded, scaled down to [kMaxImageWidth], and re-encoded: PNG when the
/// image has transparency and the PNG fits (diagrams on a transparent
/// background), otherwise JPEG, lowering the quality and then the size
/// until it fits the cap.
/// Throws [ImageTooLarge] when even that fails, and [FormatException] for a
/// file that is not an image.
PreparedImage prepareLessonImage(Uint8List bytes, String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.svg')) {
    final svg = utf8.decode(bytes, allowMalformed: true);
    if (!svg.contains('<svg')) {
      throw const FormatException('That file is not an SVG image.');
    }
    if (svg.length > kMaxAssetChars) {
      throw const ImageTooLarge(
        'That SVG is too large to store. Simplify it or export it as PNG.',
      );
    }
    return PreparedImage(mime: 'image/svg+xml', data: svg);
  }

  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    // The decoders throw on some malformed input instead of returning null.
    image = null;
  }
  if (image == null) {
    throw const FormatException(
      "That file isn't an image this editor can read.",
    );
  }
  if (image.width > kMaxImageWidth) {
    image = img.copyResize(image, width: kMaxImageWidth);
  }

  if (image.hasAlpha) {
    final png = base64Encode(img.encodePng(image, level: 9));
    if (png.length <= kMaxAssetChars) {
      return PreparedImage(
        mime: 'image/png',
        data: png,
        width: image.width,
        height: image.height,
      );
    }
  }

  // Lower the quality first; if even that doesn't fit, lower the
  // resolution and try again, down to a width still readable in a lesson.
  var current = image;
  while (true) {
    for (final quality in [85, 75, 65, 55]) {
      final jpg = base64Encode(img.encodeJpg(current, quality: quality));
      if (jpg.length <= kMaxAssetChars) {
        return PreparedImage(
          mime: 'image/jpeg',
          data: jpg,
          width: current.width,
          height: current.height,
        );
      }
    }
    if (current.width <= 480) break;
    current = img.copyResize(current, width: (current.width * 0.75).round());
  }
  throw const ImageTooLarge(
    'That image is too large even after compressing it.',
  );
}

/// Opens the file picker, prepares the chosen image and stores it. Returns
/// the new asset id, or null if nothing was picked.
Future<String?> pickAndUploadLessonImage({
  required FirebaseFirestore db,
  required String uid,
}) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  final prepared = prepareLessonImage(await file.readAsBytes(), file.name);

  final doc = db.collection('lessonAssets').doc();
  await doc.set({
    'mime': prepared.mime,
    'data': prepared.data,
    'width': ?prepared.width,
    'height': ?prepared.height,
    'createdBy': uid,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return doc.id;
}
