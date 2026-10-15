/// Mixing a session's questions so one generator template does not fill it.
///
/// Generated practice comes from a few templates per topic (Indices has 300
/// questions from nine), and a session window drawn from them could serve
/// "Evaluate 17 × 8⁰", "14 × 9⁰" and "2 × 5⁰" in eleven questions (audit A8,
/// 2026-10-15). Pure; the providers that build drill and topic-test
/// sessions call it on what they fetched, so it costs no reads.
library;

/// A question's template: its text with every number replaced, so
/// "Evaluate 17 × 8⁰" and "Evaluate 2 × 5⁰" share one.
String templateKey(String text) => text
    .replaceAll(RegExp(r'\d+(?:\.\d+)?'), '#')
    .replaceAll(RegExp(r'\s+'), ' ');

/// [pool] with each template kept at most max(2, ⌈n / templates⌉) times, so
/// a topic with few templates still gets a full session, and ordered so no
/// two neighbours share a template where that can be avoided. Past
/// questions, which almost never share a template, pass through as they
/// came.
List<T> mixSession<T>(List<T> pool, String Function(T) textOf) {
  if (pool.length < 3) return pool;
  final keys = [for (final q in pool) templateKey(textOf(q))];
  final distinct = keys.toSet().length;
  final cap = [
    2,
    (pool.length / distinct).ceil(),
  ].reduce((a, b) => a > b ? a : b);

  final counts = <String, int>{};
  final kept = <(T, String)>[];
  for (var i = 0; i < pool.length; i++) {
    final n = (counts[keys[i]] ?? 0) + 1;
    counts[keys[i]] = n;
    if (n <= cap) kept.add((pool[i], keys[i]));
  }

  // Each step serves the template with the most questions left, other than
  // the one just served (ties go to the one that came first), so no
  // template is left over to finish the session in a run.
  final queues = <String, List<T>>{};
  for (final (q, key) in kept) {
    (queues[key] ??= []).add(q);
  }
  final out = <T>[];
  String? last;
  while (queues.isNotEmpty) {
    String? pick;
    for (final entry in queues.entries) {
      if (entry.key == last && queues.length > 1) continue;
      if (pick == null || entry.value.length > queues[pick]!.length) {
        pick = entry.key;
      }
    }
    out.add(queues[pick]!.removeAt(0));
    if (queues[pick]!.isEmpty) queues.remove(pick);
    last = pick;
  }
  return out;
}
