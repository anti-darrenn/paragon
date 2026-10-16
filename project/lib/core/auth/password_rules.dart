/// How long a new password must be.
///
/// Firebase's own floor is 6, which a phone can guess its way through; 8 is
/// the common minimum (NIST SP 800-63B). Applied to every new password —
/// sign-up, a guest's upgrade, a password change — never to signing in, so
/// an older 6-character password keeps working until its owner changes it.
///
/// This is the app's check only. A script talking to Firebase directly
/// still meets the floor of 6 until the project's password policy is
/// raised in the console (docs/LAUNCH_CHECKLIST.md, "Security").
const int kMinPasswordLength = 8;

/// What to tell the student about [password] as a new password, or null.
String? newPasswordTooShort(String password) =>
    password.length < kMinPasswordLength
    ? 'Use at least $kMinPasswordLength characters.'
    : null;
