import '../../../core/lessons/lesson_doc.dart';

/// Finding a subject's glossary terms in a lesson. Pure, so every rule is
/// testable without a widget:
///
/// - whole words only, ignoring case ("base" is not found in "database");
/// - each term is marked once per article, at its first occurrence;
/// - never inside the term's own definition block — the student is
///   already reading the definition;
/// - where two terms overlap ("number base" and "base"), the longer wins
///   that stretch of text.
///
/// Only the words a student reads are searched: maths, LaTeX commands,
/// links and fence syntax are stripped first, so `\(x_{base}\)` or an
/// image URL never produces a term.

final _mathSpans = RegExp(
  r'\\\((.*?)\\\)|\\\[(.*?)\\\]|\$\$(.*?)\$\$',
  dotAll: true,
);
final _latexCommand = RegExp(r'\\[A-Za-z]+');
final _url = RegExp(r'\b(?:https?://|asset:)\S+');
final _fenceLine = RegExp(r'^\s*:::+\s*[A-Za-z]*', multiLine: true);
final _imageOrLink = RegExp(r'!?\[([^\]]*)\]\([^)]*\)');

/// The readable text of one block's source.
String glossarySearchText(LessonBlock block) {
  var s = block.source;
  s = s.replaceAllMapped(_imageOrLink, (m) => ' ${m[1]} ');
  s = s.replaceAll(_url, ' ');
  s = s.replaceAll(_mathSpans, ' ');
  s = s.replaceAll(_fenceLine, ' ');
  s = s.replaceAll(_latexCommand, ' ');
  return s;
}

/// A whole-word, case-insensitive pattern for [term]; runs of whitespace
/// in the term match any whitespace (a term may wrap across a line).
RegExp _patternFor(String term) {
  final words = term.trim().split(RegExp(r'\s+')).map(RegExp.escape);
  return RegExp(
    '(?<![A-Za-z0-9])${words.join(r'\s+')}(?![A-Za-z0-9])',
    caseSensitive: false,
  );
}

/// For each top-level block of [doc], the glossary terms first found in
/// it, in the order they appear. Blocks with none are absent.
///
/// [terms] are the subject's terms as written; the result uses the same
/// spelling, so a caller can look definitions up by it. Terms differing
/// only in case count as one.
Map<String, List<String>> glossaryTermsByBlock(
  LessonDoc doc,
  Iterable<String> terms,
) {
  // Longest first, so an overlapping shorter term loses the stretch.
  final unique = <String, String>{};
  for (final t in terms) {
    final k = t.trim().toLowerCase();
    if (k.isNotEmpty) unique.putIfAbsent(k, () => t.trim());
  }
  final ordered = unique.values.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final patterns = {for (final t in ordered) t: _patternFor(t)};

  final found = <String>{};
  final out = <String, List<String>>{};

  for (final block in doc.blocks) {
    if (block.key.isEmpty || block is VideoBlock || block is TodoBlock) {
      continue;
    }
    final text = glossarySearchText(block);
    if (text.trim().isEmpty) continue;
    final ownTerm =
        block is CalloutBlock && block.kind == CalloutKind.definition
        ? block.title.trim().toLowerCase()
        : null;

    final claimed = <(int, int)>[];
    final hits = <(int, String)>[];
    for (final term in ordered) {
      final lower = term.toLowerCase();
      if (found.contains(lower) || lower == ownTerm) continue;
      for (final m in patterns[term]!.allMatches(text)) {
        final overlaps = claimed.any((c) => m.start < c.$2 && c.$1 < m.end);
        if (overlaps) continue;
        claimed.add((m.start, m.end));
        hits.add((m.start, term));
        found.add(lower);
        break;
      }
    }
    if (hits.isEmpty) continue;
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    out[block.key] = [for (final h in hits) h.$2];
  }
  return out;
}
