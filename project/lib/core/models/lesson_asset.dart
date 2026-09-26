import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

/// An image used in a lesson: `lessonAssets/{id}`, referenced from a
/// lesson body as `![caption](asset:<id>)`.
///
/// **Why Firestore and not Cloud Storage.** The project is on the Spark
/// plan, which has no Storage bucket. A Firestore document holds up to
/// 1 MB, the editor compresses uploads well under that, and offline
/// persistence caches an asset like any other document — so a lesson saved
/// for offline keeps its diagrams.
///
/// [data] is base64 for raster images and the raw markup for SVG, which is
/// text and far smaller as-is.
class LessonAsset {
  const LessonAsset({
    required this.id,
    required this.mime,
    required this.data,
    this.width,
    this.height,
  });

  final String id;

  /// `image/webp`, `image/jpeg`, `image/png` or `image/svg+xml`.
  final String mime;
  final String data;
  final int? width;
  final int? height;

  bool get isSvg => mime == 'image/svg+xml';

  /// Decoded bytes for a raster image; null for SVG or undecodable data.
  Uint8List? get bytes {
    if (isSvg) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }

  /// Width over height, when both are known and positive.
  double? get aspectRatio {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  factory LessonAsset.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return LessonAsset(
      id: doc.id,
      mime: asString(d['mime']),
      data: asString(d['data']),
      width: asIntOrNull(d['width']),
      height: asIntOrNull(d['height']),
    );
  }
}
