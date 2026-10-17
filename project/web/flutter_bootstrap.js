{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's service worker is deprecated, and its
// stub unregisters whatever is registered at "/", which would remove
// Paragon's own (web/paragon_sw.js, registered from index.html).
_flutter.loader.load();
