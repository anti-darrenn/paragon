/// Where to send someone after they sign in, from the page they were on
/// when they were asked to — `/welcome?next=/waec/abc/setup`.
///
/// A link someone pastes into WhatsApp used to end on the dashboard after
/// signing in, the page they actually wanted forgotten.
library;

/// The query parameter that carries it.
const String kNextParam = 'next';

/// [raw] if it is safe to go to, else null. Safe means a path inside this
/// app: starts with one `/`, has no scheme or host (no open redirect to
/// another site), and is not one of the sign-in pages themselves, which
/// would loop.
String? safeNextPath(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//')) return null;
  if (raw.contains(r'\') || raw.contains('://')) return null;
  final path = Uri.tryParse(raw)?.path;
  if (path == null || path == '/') return null;
  const loops = {'/welcome', '/signin', '/account/upgrade'};
  if (loops.contains(path)) return null;
  return raw;
}

/// `/welcome`, carrying [from] when it is worth returning to.
String welcomeWith(Uri from) {
  final next = safeNextPath(from.toString());
  return next == null
      ? '/welcome'
      : Uri(path: '/welcome', queryParameters: {kNextParam: next}).toString();
}
