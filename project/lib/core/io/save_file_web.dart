import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'save_file.dart';

Future<SavedAs> saveTextFile({
  required String fileName,
  required String text,
  String mimeType = 'application/json',
}) async {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Revoked on the next turn, not immediately: some browsers start the
  // download asynchronously and would find the URL already gone.
  Future<void>.delayed(
    const Duration(seconds: 1),
    () => web.URL.revokeObjectURL(url),
  );
  return SavedAs.download;
}
