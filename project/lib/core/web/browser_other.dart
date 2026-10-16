/// Non-web stand-ins for `browser_web.dart`. See `browser.dart`.
library;

import '../config/site_config.dart';

/// Asks the browser to confirm before the tab is closed or reloaded.
/// Nothing to guard off the web: the app's own back handling covers it.
void setLeaveGuard(bool enabled) {}

/// Opens the system share sheet. False when there is none, so the caller
/// copies the link instead.
Future<bool> shareLink({required String title, required String url}) async =>
    false;

/// Where the app is served from, for absolute links.
String get appOrigin => kSiteOrigin;

/// No site to fetch from off the web; search goes without past questions.
Future<String?> fetchText(String path) async => null;
