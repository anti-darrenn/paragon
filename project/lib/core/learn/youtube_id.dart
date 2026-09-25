/// Extracts a YouTube video id from whatever an author pastes: a watch
/// link, a share link, an embed or shorts URL, or the bare id.
///
/// Returns null for anything else — including a link to a channel or a
/// playlist without a video — so the editor can refuse it at save time
/// instead of publishing a video row that plays nothing.
String? parseYouTubeId(String input) {
  final text = input.trim();
  if (_id.hasMatch(text)) return text;

  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www\.|m\.)'), '');

  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.first == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(segments.first)) {
      candidate = segments[1];
    }
  }
  return candidate != null && _id.hasMatch(candidate) ? candidate : null;
}

final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');
