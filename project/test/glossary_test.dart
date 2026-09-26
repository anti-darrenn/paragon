import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';
import 'package:paragon/core/lessons/subject_index.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/subject_index_repository.dart';
import 'package:paragon/core/widgets/article_view.dart';
import 'package:paragon/features/study/formulas/formula_sheet_tool.dart';
import 'package:paragon/features/study/glossary/glossary_hooks.dart';
import 'package:paragon/features/study/glossary/glossary_match.dart';
import 'package:paragon/features/study/glossary/glossary_tool.dart';

IndexedDefinition _def(String term, String body, {String topic = 't1'}) =>
    IndexedDefinition(
      term: term,
      body: body,
      topicId: topic,
      topicName: topic == 't1' ? 'Number bases' : 'Indices',
      resourceId: 'intro',
    );

final _index = SubjectIndex(
  subjectId: 's1',
  topics: {
    't1': TopicIndex(
      topicId: 't1',
      topicName: 'Number bases',
      definitions: [
        _def('Number base', 'The number of digits a place-value system uses.'),
        _def('Binary', 'Base two.'),
      ],
      formulas: const [
        IndexedFormula(
          title: 'Place value',
          body: r'\[ d \times b^n \]',
          topicId: 't1',
          topicName: 'Number bases',
          resourceId: 'intro',
        ),
      ],
    ),
    't2': TopicIndex(
      topicId: 't2',
      topicName: 'Indices',
      definitions: [
        _def('Index', 'The power a base is raised to.', topic: 't2'),
      ],
      formulas: const [
        IndexedFormula(
          title: 'Product rule',
          body: r'\[ a^m a^n = a^{m+n} \]',
          topicId: 't2',
          topicName: 'Indices',
          resourceId: 'laws',
        ),
      ],
    ),
  },
);

void main() {
  group('glossaryTermsByBlock', () {
    Map<String, List<String>> match(String body, List<String> terms) {
      final doc = parseLessonDoc(body);
      final byKey = glossaryTermsByBlock(doc, terms);
      // Re-key by block position, which is easier to read in a test.
      return {
        for (var i = 0; i < doc.blocks.length; i++)
          '$i': ?byKey[doc.blocks[i].key],
      };
    }

    test('whole words, ignoring case', () {
      expect(match('We count in BASE ten.', ['base']), {
        '0': ['base'],
      });
      expect(match('Bases are plural.', ['base']), isEmpty);
    });

    test('"base" is not found in "database" (control)', () {
      expect(match('A database stores rows.', ['base']), isEmpty);
      expect(match('A database has a base.', ['base']), {
        '0': ['base'],
      });
    });

    test('only the first occurrence in the article is marked', () {
      expect(match('First base.\n\nSecond base.\n\nThird base.', ['base']), {
        '0': ['base'],
      });
    });

    test('not inside its own definition block', () {
      const body =
          '::: definition Number base\n'
          'The number base is how many digits there are.\n'
          ':::\n\n'
          'Every number base has a zero.';
      // Skipped in the definition, marked at the next occurrence.
      expect(match(body, ['Number base']), {
        '1': ['Number base'],
      });
      // Control: another term in the same definition block is marked.
      expect(match(body, ['digits']), {
        '0': ['digits'],
      });
    });

    test('a multi-word term may wrap across a line', () {
      expect(match('Each number\nbase differs.', ['number base']), {
        '0': ['number base'],
      });
    });

    test('the longer of two overlapping terms wins, in text order', () {
      expect(
        match('Binary is a number base.', ['base', 'number base', 'binary']),
        {
          '0': ['binary', 'number base'],
        },
      );
    });

    test('maths and links are not searched', () {
      expect(match(r'Take \(base + 1\) here.', ['base']), isEmpty);
      expect(match('See [notes](https://x.org/base) now.', ['base']), isEmpty);
      expect(match('See [the base](https://x.org) now.', ['base']), {
        '0': ['base'],
      });
    });
  });

  group('in the article', () {
    const resource = LearnResource(
      id: 'lesson2',
      type: LearnResourceType.article,
      order: 2,
      title: 'Converting',
      subjectId: 's1',
      topicId: 't1',
      body: 'Binary uses two digits.\n\nMore binary here.',
    );

    testWidgets('a term chip appears once and opens its definition', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectIndexProvider.overrideWith((ref, id) async => _index),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer(
                  builder: (context, ref, _) => ArticleView(
                    body: resource.body,
                    decorate: glossaryDecorator(ref, resource),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = find.byKey(const ValueKey('glossary.term.binary'));
      expect(chip, findsOneWidget);
      expect(find.text('Terms:'), findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Base two.'), findsOneWidget);
      expect(find.text('From Number bases'), findsOneWidget);
    });
  });

  group('tools', () {
    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectIndexProvider.overrideWith(
              (ref, id) async => id == 's1' ? _index : SubjectIndex.empty,
            ),
          ],
          child: MaterialApp(home: Scaffold(body: page)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the glossary lists terms A-Z and search filters them', (
      tester,
    ) async {
      await pumpPage(tester, const GlossaryScreen(subjectId: 's1'));
      expect(find.text('Binary'), findsOneWidget);
      expect(find.text('Index'), findsOneWidget);
      expect(find.text('Number base'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Binary')).dy,
        lessThan(tester.getTopLeft(find.text('Index')).dy),
      );

      await tester.enterText(find.byKey(const ValueKey('index.search')), 'NUM');
      await tester.pumpAndSettle();
      expect(find.text('Number base'), findsOneWidget);
      expect(find.text('Binary'), findsNothing);
      expect(find.text('Index'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('index.search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('an empty glossary says no terms are defined yet', (
      tester,
    ) async {
      await pumpPage(tester, const GlossaryScreen(subjectId: 'other'));
      expect(find.text(kGlossaryEmpty), findsOneWidget);
    });

    testWidgets('the formula sheet renders formulas grouped by topic', (
      tester,
    ) async {
      await pumpPage(tester, const FormulaSheetScreen(subjectId: 's1'));
      expect(find.text('Indices'), findsOneWidget);
      expect(find.text('Number bases'), findsOneWidget);
      expect(find.text('Place value'), findsOneWidget);
      expect(find.text('Product rule'), findsOneWidget);
      // Grouped: each formula under its own topic heading.
      expect(
        tester.getTopLeft(find.text('Indices')).dy,
        lessThan(tester.getTopLeft(find.text('Product rule')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Product rule')).dy,
        lessThan(tester.getTopLeft(find.text('Number bases')).dy),
      );

      // Searching a topic name keeps its formulas.
      await tester.enterText(
        find.byKey(const ValueKey('index.search')),
        'indices',
      );
      await tester.pumpAndSettle();
      expect(find.text('Product rule'), findsOneWidget);
      expect(find.text('Place value'), findsNothing);
    });

    testWidgets('an empty formula sheet says so', (tester) async {
      await pumpPage(tester, const FormulaSheetScreen(subjectId: 'other'));
      expect(find.text(kFormulaSheetEmpty), findsOneWidget);
    });
  });
}
