/// The few browser APIs the app needs beyond what Flutter gives it: a
/// "leave this page?" prompt while an exam is running, the system share
/// sheet, and the page's own origin for building links.
///
/// On the web these are real (`browser_web.dart`); elsewhere they are
/// no-ops or report "not available" (`browser_other.dart`), so callers
/// never need a platform check.
library;

export 'browser_other.dart' if (dart.library.js_interop) 'browser_web.dart';
