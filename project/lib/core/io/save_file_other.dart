import 'package:flutter/services.dart';

import 'save_file.dart';

Future<SavedAs> saveTextFile({
  required String fileName,
  required String text,
  String mimeType = 'application/json',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  return SavedAs.clipboard;
}
