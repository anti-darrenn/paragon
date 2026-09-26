/// Hands the student a text file.
///
/// On the web, a real download through a Blob URL. Elsewhere there is no
/// download folder to write to without a new plugin, so the text is put on
/// the clipboard instead and the caller says so. [SavedAs] tells the
/// caller which happened.
library;

export 'save_file_other.dart' if (dart.library.js_interop) 'save_file_web.dart';

enum SavedAs { download, clipboard }
