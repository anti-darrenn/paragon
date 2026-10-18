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

/// Largest file the editor will read at all. A phone photo is a few MB.
const kMaxUploadBytes = 20 * 1024 * 1024;

/// Most pixels a source image may claim before it is decoded. A small file
/// can declare an enormous canvas (a "decompression bomb") and take the
/// tab down while decoding; the header is read first, so it never gets
/// that far. 50 megapixels is a large camera's photo.
const kMaxSourcePixels = 50 * 1000 * 1000;

/// What an SVG may not contain. Mirrors `tools/admin/svg_safety.js`;
/// change both together.
///
/// The app draws SVG with flutter_svg, which runs nothing, but the static
/// site publishes question images as files on the app's own origin, where
/// an SVG opened directly is a page. A diagram never needs a script, an
/// event handler, embedded HTML or anything fetched from elsewhere.
final List<(RegExp, String)> _svgRules = [
  (RegExp(r'<\s*script', caseSensitive: false), 'a script'),
  (RegExp(r'<\s*foreignObject', caseSensitive: false), 'embedded HTML'),
  (
    RegExp(r'<\s*(iframe|embed|object|audio|video)\b', caseSensitive: false),
    'an embedded document or media',
  ),
  (RegExp(r'\son[a-z]+\s*=', caseSensitive: false), 'an event handler'),
  (RegExp(r'javascript\s*:', caseSensitive: false), 'a javascript: link'),
  (RegExp(r'<!ENTITY', caseSensitive: false), 'an XML entity'),
  (
    RegExp(
      r'''(?:href|src)\s*=\s*["']?\s*(?!#|data:image/)[a-z][a-z0-9+.-]*:''',
      caseSensitive: false,
    ),
    'a link to another site',
  ),
  (
    RegExp(r'''(?:href|src)\s*=\s*["']?\s*//''', caseSensitive: false),
    'a link to another site',
  ),
  (
    RegExp(
      r'''@import|url\(\s*["']?\s*(?:[a-z][a-z0-9+.-]*:|//)(?!image/)''',
      caseSensitive: false,
    ),
    'a stylesheet from another site',
  ),
];

/// Why [svg] is refused, or null when it is a plain drawing.
String? svgProblem(String svg) {
  if (!RegExp(r'<svg[\s>]', caseSensitive: false).hasMatch(svg)) {
    return 'not an SVG image';
  }
  for (final (pattern, why) in _svgRules) {
    if (pattern.hasMatch(svg)) return why;
  }
  return null;
}

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
  if (bytes.length > kMaxUploadBytes) {
    throw const ImageTooLarge(
      'That file is over 20 MB. Export a smaller copy and try again.',
    );
  }
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.svg')) {
    final svg = utf8.decode(bytes, allowMalformed: true);
    final problem = svgProblem(svg);
    if (problem == 'not an SVG image') {
      throw const FormatException('That file is not an SVG image.');
    }
    if (problem != null) {
      throw FormatException(
        'That SVG contains $problem, which lessons do not allow. '
        'Export it again as a plain drawing, or as PNG.',
      );
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
    // The header first: its size is checked before a single pixel is
    // decoded, and only the first frame of an animation is decoded.
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder != null && info != null) {
      if (info.width <= 0 ||
          info.height <= 0 ||
          info.width * info.height > kMaxSourcePixels) {
        throw ImageTooLarge(
          'That image is ${info.width}×${info.height} pixels, too large to '
          'open here. Resize it below 50 megapixels first.',
        );
      }
      image = decoder.decode(bytes, frame: 0);
    }
  } on ImageTooLarge {
    rethrow;
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
  // Before reading it into memory, not after.
  final size = await file.length();
  if (size != null && size > kMaxUploadBytes) {
    throw const ImageTooLarge(
      'That file is over 20 MB. Export a smaller copy and try again.',
    );
  }
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

/// The same, for a diagram in a host's own quiz (2026-10-17): stored in
/// `quizAssets`, which any account may write, so a teacher's pictures never
/// mix with the lesson library. Returns the id the quiz stores
/// (`quiz:<id>`), or null if nothing was picked.
Future<String?> pickAndUploadQuizImage({
  required FirebaseFirestore db,
  required String uid,
}) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  final size = await file.length();
  if (size != null && size > kMaxUploadBytes) {
    throw const ImageTooLarge(
      'That file is over 20 MB. Export a smaller copy and try again.',
    );
  }
  final prepared = prepareLessonImage(await file.readAsBytes(), file.name);
  final doc = db.collection('quizAssets').doc();
  await doc.set({
    'mime': prepared.mime,
    'data': prepared.data,
    'width': ?prepared.width,
    'height': ?prepared.height,
    'createdBy': uid,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return 'quiz:${doc.id}';
}
