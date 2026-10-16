/// Firebase App Check: proof that a request to Firestore comes from this
/// app in a real browser, not a script holding the public API key.
///
/// Why it matters here: anyone can start a guest session in one click, and
/// Spark allows 20k writes and 50k reads a day for the whole project. A
/// script signed in as a guest could spend both and take Paragon offline
/// for everyone until midnight Pacific. The rules cannot tell a script
/// from a student; App Check can. (docs/audit/SECURITY_2026-10-16.md)
library;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// The reCAPTCHA Enterprise site key registered for the web app in
/// Firebase console → App Check (docs/LAUNCH_CHECKLIST.md, "Security").
/// A site key is public; it ships in every page that uses it.
///
/// **Empty means App Check is off**, which is how this ships until the key
/// exists. Registering it and filling this in turns on *monitoring*: every
/// request carries a token and the console shows how many would pass.
/// Nothing is refused until enforcement is switched on in the console,
/// which is a separate decision taken once the metrics look right.
const String kRecaptchaEnterpriseSiteKey = '';

/// Starts App Check, web only. Called once, after Firebase starts and
/// before Firestore is first used, so the first request carries a token.
///
/// Android is not wired: it needs Play Integrity, which needs a build
/// signed for and distributed through Play, and the Android app is not
/// shipped. Debug builds use the debug provider, which prints a token to
/// the console to register under App Check → Manage debug tokens.
Future<void> activateAppCheck() async {
  if (!kIsWeb || kRecaptchaEnterpriseSiteKey.isEmpty) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kDebugMode
          ? WebDebugProvider()
          : ReCaptchaEnterpriseProvider(kRecaptchaEnterpriseSiteKey),
    );
  } catch (_) {
    // Never a reason not to start: while App Check is only monitoring, a
    // request without a token is still served, and the console counts it.
  }
}
