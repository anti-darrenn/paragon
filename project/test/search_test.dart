import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/search/search.dart';

SearchItem _topic(String title, [String course = 'Physics']) => SearchItem(
  kind: SearchKind.topic,
  title: title,
  subtitle: course,
  path: '/t/$title',
);

SearchItem _course(String title) =>
    SearchItem(kind: SearchKind.course, title: title, path: '/c/$title');

SearchItem _lesson(String title, String topic) => SearchItem(
  kind: SearchKind.lesson,
  title: title,
  subtitle: '$topic · Physics',
  detail: 'Video',
  path: '/l/$title',
);

void main() {
  group('normalizeForSearch', () {
    test('lower-cases, drops accents, punctuation and LaTeX delimiters', () {
      expect(normalizeForSearch('Ohm’s Law \\(V = IR\\)'), 'ohm s law v ir');
      expect(normalizeForSearch('  Énergie   cinétique '), 'energie cinetique');
    });
  });

  group('searchCatalog', () {
    final corpus = [
      _course('Physics'),
      _course('Mathematics'),
      _topic('Waves and sound'),
      _topic('Waves'),
      _topic('Electromagnetic waves'),
      _topic('Microwaves in cooking'),
      _topic('Indices', 'Mathematics'),
      _lesson('What is a wave?', 'Waves'),
    ];

    List<String> titles(List<SearchItem> items) => [
      for (final i in items) i.title,
    ];

    test('exact, then prefix, then word start, then inside a word', () {
      final r = searchCatalog('waves', corpus);
      expect(titles(r.topics), [
        'Waves', // exact
        'Waves and sound', // prefix
        'Electromagnetic waves', // a word starts with it
        'Microwaves in cooking', // inside a word
      ]);
    });

    test('groups courses, topics and lessons separately', () {
      final r = searchCatalog('wave', corpus);
      expect(r.courses, isEmpty);
      expect(titles(r.lessons), ['What is a wave?']);
      expect(r.all.first.kind, SearchKind.topic);
    });

    test('is case- and accent-insensitive', () {
      expect(titles(searchCatalog('PHYSICS', corpus).courses), ['Physics']);
      expect(titles(searchCatalog('índices', corpus).topics), ['Indices']);
    });

    test('every word must match, across title and where it sits', () {
      expect(titles(searchCatalog('indices mathematics', corpus).topics), [
        'Indices',
      ]);
      // CONTROL: "Indices" is in Mathematics, not Physics.
      expect(titles(searchCatalog('indices physics', corpus).topics), []);
    });

    test('"maths" finds Mathematics', () {
      expect(titles(searchCatalog('maths', corpus).courses), ['Mathematics']);
      expect(titles(searchCatalog('indices maths', corpus).topics), [
        'Indices',
      ]);
    });

    test('perGroup caps each group', () {
      expect(searchCatalog('waves', corpus, perGroup: 2).topics, hasLength(2));
    });

    test('CONTROL: no match and a blank query both give nothing', () {
      expect(searchCatalog('photosynthesis', corpus).isEmpty, isTrue);
      expect(searchCatalog('   ', corpus).isEmpty, isTrue);
      // ...while the corpus itself is searchable at all.
      expect(searchCatalog('a', corpus).isEmpty, isFalse);
    });
  });
}
