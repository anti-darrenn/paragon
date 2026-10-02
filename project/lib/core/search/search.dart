/// Search over courses, topics and lessons, as pure logic.
///
/// Everything searched is already on the device: the course catalog, and
/// the topic and lesson names in each subject's `subjectIndex` document —
/// one cached read per subject. A Firestore query per keystroke, or a scan
/// of the `topics` collection, would not survive the Spark read quota.
library;

enum SearchKind { course, topic, lesson }

/// One thing a student can find and open.
class SearchItem {
  SearchItem({
    required this.kind,
    required this.title,
    required this.path,
    this.subtitle = '',
    this.detail = '',
  });

  final SearchKind kind;
  final String title;

  /// Where it sits: the course for a topic, the topic for a lesson.
  final String subtitle;

  /// A lesson's type ("Video", "Article"), or "Coming soon" for a course
  /// with no content yet.
  final String detail;

  /// The route that opens it.
  final String path;

  /// Searched as one string, so "physics waves" finds the Waves topic in
  /// Physics. Normalised once, not per keystroke.
  late final String _haystack = normalizeForSearch('$title $subtitle');
  late final String _title = normalizeForSearch(title);
}

/// Results, grouped the way they are shown.
class SearchResults {
  const SearchResults({
    this.courses = const [],
    this.topics = const [],
    this.lessons = const [],
  });

  final List<SearchItem> courses;
  final List<SearchItem> topics;
  final List<SearchItem> lessons;

  static const empty = SearchResults();

  bool get isEmpty => courses.isEmpty && topics.isEmpty && lessons.isEmpty;
  int get total => courses.length + topics.length + lessons.length;

  /// Courses, then topics, then lessons: the order on screen, and the
  /// order arrow keys move through.
  List<SearchItem> get all => [...courses, ...topics, ...lessons];
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  'ẹ': 'e', 'ọ': 'o', 'ṣ': 's', // Yoruba, which Nigerian names carry
};

/// Lower case, accents off, LaTeX delimiters and punctuation to spaces,
/// whitespace collapsed. "Ohm’s Law \\(V=IR\\)" → "ohm s law v ir".
String normalizeForSearch(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final c = _accents[ch] ?? ch;
    final code = c.codeUnitAt(0);
    final isWordChar =
        (code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x7a);
    b.write(isWordChar ? c : ' ');
  }
  return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// How well [item] matches [query] (already normalised); lower is better,
/// null is no match.
///
/// 0 the title is the query; 1 the title starts with it; 2 a word in the
/// title starts with it; 3 it appears inside the title; 4 every word of
/// the query starts a word somewhere in the title or where it sits.
int? matchRank(String query, SearchItem item) {
  if (query.isEmpty) return null;
  final title = item._title;
  if (title == query) return 0;
  if (title.startsWith(query)) return 1;
  if (title.contains(' $query')) return 2;
  if (title.contains(query)) return 3;
  final hay = ' ${item._haystack}';
  final words = query.split(' ');
  if (words.every((w) => hay.contains(' $w'))) return 4;
  return null;
}

/// How students write a subject, mapped to a prefix of how the catalog
/// does: "maths" is not a prefix of "mathematics", but "math" is.
const _queryAliases = {'maths': 'math'};

/// The items matching [query], best first, at most [perGroup] of each
/// kind. Ties go to the shorter title — "Waves" before "Waves and sound"
/// — then alphabetical, so results never reshuffle between keystrokes
/// that do not change them.
SearchResults searchCatalog(
  String query,
  List<SearchItem> corpus, {
  int perGroup = 50,
}) {
  var q = normalizeForSearch(query);
  if (q.isEmpty) return SearchResults.empty;
  q = q.split(' ').map((w) => _queryAliases[w] ?? w).join(' ');

  final ranked =
      <(int, SearchItem)>[
        for (final item in corpus)
          if (matchRank(q, item) case final rank?) (rank, item),
      ]..sort((a, b) {
        final byRank = a.$1.compareTo(b.$1);
        if (byRank != 0) return byRank;
        final byLength = a.$2.title.length.compareTo(b.$2.title.length);
        if (byLength != 0) return byLength;
        return a.$2.title.compareTo(b.$2.title);
      });

  List<SearchItem> of(SearchKind kind) => [
    for (final (_, item) in ranked)
      if (item.kind == kind) item,
  ].take(perGroup).toList();

  return SearchResults(
    courses: of(SearchKind.course),
    topics: of(SearchKind.topic),
    lessons: of(SearchKind.lesson),
  );
}
