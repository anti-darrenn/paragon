/// Web implementations for `browser.dart`.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

JSFunction? _beforeUnload;

/// While enabled, closing or reloading the tab asks "Leave site?" — the
/// browser's own wording; no page may customise it any more.
void setLeaveGuard(bool enabled) {
  if (enabled && _beforeUnload == null) {
    _beforeUnload = ((web.Event e) {
      e.preventDefault();
      // Older Chromium needs returnValue set as well.
      (e as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    web.window.addEventListener('beforeunload', _beforeUnload);
  } else if (!enabled && _beforeUnload != null) {
    web.window.removeEventListener('beforeunload', _beforeUnload);
    _beforeUnload = null;
  }
}

/// The Web Share API where the browser has one — most phones do, which is
/// where a student is sending a link to WhatsApp.
Future<bool> shareLink({required String title, required String url}) async {
  final nav = web.window.navigator;
  if (!nav.has('share')) return false;
  try {
    await nav.share(web.ShareData(title: title, url: url)).toDart;
    return true;
  } catch (_) {
    // Cancelled by the student, or refused: copying is still useful.
    return false;
  }
}

String get appOrigin => web.window.location.origin;

/// A text file from this site (the past-question search index), or null if
/// it cannot be fetched.
Future<String?> fetchText(String path) async {
  try {
    final res = await web.window.fetch(path.toJS).toDart;
    if (!res.ok) return null;
    return (await res.text().toDart).toDart;
  } catch (_) {
    return null;
  }
}
