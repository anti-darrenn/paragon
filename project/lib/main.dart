import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/data/read_meter.dart';

void main() async {
  // Real paths (`/subject/abc/course`), not `#/…`: a link can be shared,
  // and the static past-question pages can link into the app. Old hash
  // links are rewritten by a script in web/index.html before this runs.
  // No-op off the web.
  usePathUrlStrategy();
  // `context.push` updates the address bar too (go_router's default only
  // does for `go`), so the URL always names the page on screen.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();

  // Space Grotesk ships in assets/google_fonts/, so nothing is fetched from
  // fonts.gstatic.com at startup (audit F2). A weight that is not bundled
  // fails loudly in debug instead of quietly reaching for the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], ofl);
  });

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence, set before anything touches Firestore — the
  // settings are read once, when the instance is first used, and a later
  // assignment is ignored.
  //
  // **This was not on.** Web is the primary target, and on web
  // `persistenceEnabled` defaults to *off*: `cloud_firestore_web` installs
  // a `memoryLocalCache` unless told otherwise, so the cache died with the
  // browser tab. Learn-mode articles are the first content worth reading
  // on a bad connection, and the old `LearnScreen`'s offline banner had
  // promised "the last loaded content" — which was only ever true within
  // one session.
  //
  // `WebPersistentMultipleTabManager` rather than the default: the default
  // web persistent cache is single-tab, and a student who opens a second
  // tab would find it silently unable to acquire the lock. Ignored on
  // mobile, where persistence is on by default anyway.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
    // ~100 MB, up from the 40 MB default, so topics saved for offline are
    // not evicted as soon as a few more are read. It is a ceiling, not an
    // allocation — the cache only grows as documents are fetched — and
    // Firestore evicts least-recently-used documents past it, which is
    // also the only way a saved topic ever leaves the device.
    cacheSizeBytes: 100 * 1024 * 1024,
  );

  // Debug builds print every billed read (see read_meter.dart).
  ReadMeter.instance.logging = kDebugMode;

  runApp(const ProviderScope(child: ParagonApp()));
}
