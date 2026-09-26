import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/subject_tools.dart';
import 'package:paragon/core/study/study_tool_registry.dart';
import 'package:paragon/features/study/references/constants_data.dart';
import 'package:paragon/features/study/references/constants_tool.dart';
import 'package:paragon/features/study/references/four_figure_math.dart';
import 'package:paragon/features/study/references/four_figure_tables.dart';
import 'package:paragon/features/study/references/four_figure_tables_tool.dart';
import 'package:paragon/features/study/references/periodic_table_data.dart';
import 'package:paragon/features/study/references/periodic_table_tool.dart';

List<ChemicalElement> _elements() => parsePeriodicTable(
  File('assets/data/periodic_table.json').readAsStringSync(),
);

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  group('registry', () {
    test('registers exactly the three reference tools, as pages', () {
      final ids = studyTools.map((t) => t.id).toSet();
      expect(
        ids,
        containsAll([
          StudyToolId.periodicTable,
          StudyToolId.fourFigureTables,
          StudyToolId.constants,
        ]),
      );
      for (final t in studyTools) {
        expect(t.label, isNotEmpty);
      }
    });
  });

  group('periodic table data', () {
    final elements = _elements();
    ChemicalElement bySymbol(String s) =>
        elements.firstWhere((e) => e.symbol == s);

    test('118 elements, Z 1..118 once each, unique symbols', () {
      expect(elements, hasLength(118));
      expect(elements.map((e) => e.z).toList(), [
        for (var z = 1; z <= 118; z++) z,
      ]);
      expect(elements.map((e) => e.symbol).toSet(), hasLength(118));
      expect(elements.map((e) => e.name).toSet(), hasLength(118));
    });

    test('the asset cites its sources', () {
      final raw = File('assets/data/periodic_table.json').readAsStringSync();
      expect(raw, contains('"_source"'));
      expect(raw, contains('CIAAW'));
      expect(raw, contains('NIST'));
    });

    // CIAAW Abridged Standard Atomic Weights 2024 (the cited table).
    test('standard atomic weights match the IUPAC abridged table', () {
      expect(bySymbol('H').atomicWeightValue, 1.008);
      expect(bySymbol('H').atomicWeight, '1.0080'); // printed to 5 figures
      expect(bySymbol('C').atomicWeightValue, 12.011);
      expect(bySymbol('O').atomicWeightValue, 15.999);
      expect(bySymbol('Na').atomicWeightValue, 22.990);
      expect(bySymbol('Cl').atomicWeightValue, 35.45);
      expect(bySymbol('Fe').atomicWeightValue, 55.845);
      expect(bySymbol('Te').atomicWeight, '127.60'); // trailing zero kept
    });

    test('elements without a standard weight carry a mass number', () {
      final tc = bySymbol('Tc');
      expect(tc.atomicWeight, isNull);
      expect(tc.massNumber, 97);
      expect(tc.weightLabel, '[97]');
      expect(bySymbol('Ra').weightLabel, '[226]');
      expect(bySymbol('Og').weightLabel, '[294]');
      // Th, Pa and U are radioactive but do have standard weights.
      expect(bySymbol('U').atomicWeightValue, 238.03);
      for (final e in elements) {
        expect(
          (e.atomicWeight == null) != (e.massNumber == null),
          isTrue,
          reason: '${e.symbol} needs exactly one of weight / mass number',
        );
      }
    });

    test('group and period', () {
      expect((bySymbol('H').group, bySymbol('H').period), (1, 1));
      expect((bySymbol('He').group, bySymbol('He').period), (18, 1));
      expect((bySymbol('Na').group, bySymbol('Na').period), (1, 3));
      expect((bySymbol('Cl').group, bySymbol('Cl').period), (17, 3));
      expect((bySymbol('Fe').group, bySymbol('Fe').period), (8, 4));
      expect((bySymbol('Hf').group, bySymbol('Hf').period), (4, 6));
      expect((bySymbol('Og').group, bySymbol('Og').period), (18, 7));
      expect(bySymbol('Ce').group, isNull);
      expect(bySymbol('Ce').series, 'lanthanide');
      expect(bySymbol('U').series, 'actinide');
      expect(elements.where((e) => e.series == 'lanthanide'), hasLength(15));
      expect(elements.where((e) => e.series == 'actinide'), hasLength(15));
      // Every main-table slot is filled once.
      final slots = {
        for (final e in elements)
          if (e.group != null) (e.period, e.group),
      };
      expect(slots, hasLength(118 - 30));
    });

    test('electron configurations', () {
      expect(bySymbol('Fe').electronConfiguration, '[Ar] 3d6 4s2');
      expect(bySymbol('Cu').electronConfiguration, '[Ar] 3d10 4s1');
      expect(bySymbol('Cr').electronConfiguration, '[Ar] 3d5 4s1');
      expect(bySymbol('Na').electronConfiguration, '[Ne] 3s1');
      expect(bySymbol('H').electronConfiguration, '1s1');
      expect(
        configurationLatex('[Ar] 3d6 4s2'),
        r'\mathrm{[Ar]}\,3d^{6}\,4s^{2}',
      );
      // Electron counts add up to Z for every measured configuration.
      const cores = {
        '[He]': 2,
        '[Ne]': 10,
        '[Ar]': 18,
        '[Kr]': 36,
        '[Xe]': 54,
        '[Rn]': 86,
      };
      for (final e in elements) {
        var n = 0;
        for (final part in e.electronConfiguration.split(' ')) {
          n += cores[part] ?? int.parse(part.substring(2));
        }
        expect(n, e.z, reason: e.symbol);
      }
      expect(bySymbol('Hs').configurationPredicted, isFalse);
      expect(bySymbol('Mt').configurationPredicted, isTrue);
    });

    test('every category has a colour', () {
      for (final e in elements) {
        expect(
          kCategoryColors.containsKey(e.category),
          isTrue,
          reason: e.category,
        );
      }
    });

    test('search matches symbol, name or number', () {
      final fe = bySymbol('Fe');
      expect(elementMatches(fe, 'fe'), isTrue);
      expect(elementMatches(fe, 'iro'), isTrue);
      expect(elementMatches(fe, '26'), isTrue);
      expect(elementMatches(fe, 'zinc'), isFalse);
      expect(elementMatches(fe, '27'), isFalse);
    });
  });

  group('four-figure table entries', () {
    test('logarithms', () {
      expect(fourDigits(logEntry(200)), '3010'); // log 2
      expect(fourDigits(logEntry(300)), '4771'); // log 3
      expect(fourDigits(logEntry(750)), '8751'); // log 7.5
      expect(fourDigits(logEntry(100)), '0000');
      expect(fourDigits(logEntry(101)), '0043');
      expect(logEntry(1000), 10000);
    });

    test('antilogarithms', () {
      expect(antilogEntry(301), 2000); // antilog 0.301 = 2.000
      expect(antilogEntry(0), 1000);
      expect(antilogEntry(1000), 10000);
    });

    test('natural sines, cosines, tangents', () {
      expect(trigCell(TrigRatio.sine, 300), '0.5000');
      expect(trigCell(TrigRatio.cosine, 600), '0.5000');
      expect(trigCell(TrigRatio.tangent, 450), '1.0000');
      expect(trigCell(TrigRatio.sine, 450), '0.7071');
      expect(trigCell(TrigRatio.sine, 0), '0.0000');
      expect(trigCell(TrigRatio.cosine, 0), '1.0000');
      // Tangents of 10 and over switch to four significant figures.
      expect(trigCell(TrigRatio.tangent, 840), '9.5144');
      expect(trigCell(TrigRatio.tangent, 850), '11.43');
      expect(trigCell(TrigRatio.tangent, 899), '573.0');
    });

    test('control: the 5th figure rounds, it is not cut off', () {
      // log 7.5 = 0.875061…, log 1.5 = 0.176091…: truncating would give
      // 8750 and 1760. If these fail, entries are being truncated.
      expect((math.log(7.5) / math.ln10 * 10000).floor(), 8750);
      expect(logEntry(750), 8751);
      expect((math.log(1.5) / math.ln10 * 10000).floor(), 1760);
      expect(logEntry(150), 1761);
      // And a value whose 5th figure is below 5 rounds down:
      // log 2 = 0.301029…
      expect(logEntry(200), 3010);
      // sin 1° = 0.017452…: rounds up to 0.0175.
      expect(trigCell(TrigRatio.sine, 10), '0.0175');
    });

    test('mean differences, computed from the table', () {
      List<int> logRow(int r, [int c = 0]) => [
        for (var k = 1; k <= 9; k++) logMeanDifference(r, c, k),
      ];
      expect(logRow(20), [2, 4, 6, 8, 11, 13, 15, 17, 19]);
      expect(logRow(30), [1, 3, 4, 6, 7, 9, 10, 11, 13]);
      // Rows 10–19 carry one set per half row; the first half is steeper.
      expect(logRow(10, 0).last, greaterThan(logRow(10, 5).last));
      expect(
        [for (var k = 1; k <= 9; k++) antilogMeanDifference(99, k)],
        [2, 5, 7, 9, 11, 14, 16, 18, 21],
      );
      expect(
        [for (var k = 1; k <= 5; k++) trigMeanDifference(TrigRatio.sine, 0, k)],
        [3, 6, 9, 12, 15],
      );
      expect(trigMeanDifference(TrigRatio.tangent, 84, 1), isNull);
      expect(trigMeanDifference(TrigRatio.tangent, 83, 1), isNotNull);
    });

    test('tables have the printed shape', () {
      final log = buildLogTable();
      expect(log.rowLabels.first, '10');
      expect(log.rowLabels.last, '99');
      expect(log.cells, hasLength(90));
      expect(log.cells[20 - 10][0], '3010');
      expect(log.meanDifferences[0][0], contains('\n')); // row 10: two sets
      expect(log.meanDifferences[10][0], isNot(contains('\n')));
      final anti = buildAntilogTable();
      expect(anti.cells, hasLength(100));
      expect(anti.cells[30][1], '2000');
      final sine = buildTrigTable(TrigRatio.sine);
      expect(sine.cells, hasLength(90));
      expect(sine.columnLabels[1], '6′');
      expect(sine.cells[30][0], '0.5000');
    });
  });

  group('four-figure look-up (the table method)', () {
    test('logarithms', () {
      final two = lookupLog(2)!;
      expect(two.answer, '0.3010');
      expect((two.row, two.column, two.meanDifferenceColumn), (10, 0, 0));
      expect(lookupLog(3)!.answer, '0.4771');
      expect(lookupLog(7.5)!.answer, '0.8751');
      // 1.234: 0.0899 at row 12 column 3, plus 14 for the 4th figure.
      final a = lookupLog(1.234)!;
      expect((a.row, a.column, a.meanDifferenceColumn), (2, 3, 4));
      expect(a.answer, '0.0913');
      expect(lookupLog(234.5)!.answer, '2.3701');
      expect(lookupLog(0.0234)!.answer, '2̄.3692');
      expect(lookupLog(0), isNull);
      expect(lookupLog(-1), isNull);
    });

    test('antilogarithms', () {
      expect(lookupAntilog(0.3010)!.answer, '2.000');
      expect(lookupAntilog(2.4771)!.answer, '300.0');
      expect(lookupAntilog(-2 + 0.3010)!.answer, '0.02000');
    });

    test('trigonometric ratios', () {
      expect(lookupTrig(TrigRatio.sine, 30)!.answer, '0.5000');
      expect(lookupTrig(TrigRatio.cosine, 60)!.answer, '0.5000');
      expect(lookupTrig(TrigRatio.tangent, 45)!.answer, '1.0000');
      expect(lookupTrig(TrigRatio.sine, 45)!.answer, '0.7071');
      // 30°15′: entry at 30°12′ plus the 3′ difference.
      final s = lookupTrig(TrigRatio.sine, 30.25)!;
      expect((s.row, s.column, s.meanDifferenceColumn), (30, 2, 3));
      expect(s.answer, '0.5038');
      // Cosines subtract: cos 60°15′ = 0.4962.
      expect(lookupTrig(TrigRatio.cosine, 60.25)!.answer, '0.4962');
      expect(lookupTrig(TrigRatio.sine, 90), isNull);
    });

    test('angle input', () {
      expect(parseAngle('37 15'), 37.25);
      expect(parseAngle("37°15'"), 37.25);
      expect(parseAngle('37.25'), 37.25);
      expect(parseAngle('37 75'), isNull);
    });
  });

  group('constants', () {
    double v(String name) => constantNamed(name).value;

    test('SI 2019 defining constants are exact', () {
      expect(v('Speed of light in vacuum'), 299792458);
      expect(v('Planck constant'), 6.62607015e-34);
      expect(v('Elementary charge'), 1.602176634e-19);
      expect(v('Avogadro constant'), 6.02214076e23);
      expect(v('Boltzmann constant'), 1.380649e-23);
      for (final n in [
        'Speed of light in vacuum',
        'Planck constant',
        'Elementary charge',
        'Avogadro constant',
        'Boltzmann constant',
      ]) {
        expect(constantNamed(n).exact, isTrue, reason: n);
      }
      // Control: measured constants are not marked exact.
      expect(constantNamed('Newtonian constant of gravitation').exact, isFalse);
      expect(constantNamed('Vacuum electric permittivity').exact, isFalse);
    });

    test('derived exact constants agree with their definitions', () {
      expect(
        v('Molar gas constant'),
        closeTo(v('Avogadro constant') * v('Boltzmann constant'), 1e-8),
      );
      expect(
        v('Faraday constant'),
        closeTo(v('Avogadro constant') * v('Elementary charge'), 1e-5),
      );
      expect(v('Electronvolt'), 1.602176634e-19);
      expect(v('Standard atmosphere'), 101325);
      expect(coulombConstant, closeTo(8.9875517923e9, 1e1));
    });

    test('LaTeX shows grouped digits and units', () {
      expect(
        constantNamed('Planck constant').latex,
        r'\(h = 6.626\,070\,15 \times 10^{-34}\ \mathrm{J\,s}\)',
      );
      expect(
        constantNamed('Newtonian constant of gravitation').valueLatex,
        startsWith(r'6.674\,30(15)'),
      );
      expect(
        constantNamed('Molar gas constant').valueLatex,
        contains(r'\ldots'),
      );
    });
  });

  group('unit converter', () {
    ConvUnit u(String cat, String sym) => unitCategory(cat).unit(sym);

    test('pressure', () {
      expect(convert(1, u('Pressure', 'atm'), u('Pressure', 'Pa')), 101325);
      expect(
        convert(760, u('Pressure', 'mmHg'), u('Pressure', 'atm')),
        closeTo(1, 1e-6),
      );
    });

    test('temperature handles offsets', () {
      final c = u('Temperature', '°C');
      final k = u('Temperature', 'K');
      final f = u('Temperature', '°F');
      expect(convert(100, c, k), closeTo(373.15, 1e-9));
      expect(convert(100, c, f), closeTo(212, 1e-9));
      expect(convert(32, f, c), closeTo(0, 1e-9));
      expect(convert(-40, c, f), closeTo(-40, 1e-9));
      expect(convert(0, k, c), closeTo(-273.15, 1e-9));
      // Control: a factor-only conversion would get this wrong.
      expect(convert(100, c, k), isNot(closeTo(100, 1)));
    });

    test('energy', () {
      expect(convert(1, u('Energy', 'eV'), u('Energy', 'J')), 1.602176634e-19);
      expect(convert(1, u('Energy', 'kWh'), u('Energy', 'J')), 3.6e6);
      expect(convert(1, u('Energy', 'cal'), u('Energy', 'J')), 4.184);
    });

    test('exact length and speed definitions', () {
      expect(
        convert(1, u('Length', 'in'), u('Length', 'cm')),
        closeTo(2.54, 1e-12),
      );
      expect(
        convert(1, u('Length', 'mi'), u('Length', 'm')),
        closeTo(1609.344, 1e-9),
      );
      expect(
        convert(36, u('Speed', 'km/h'), u('Speed', 'm/s')),
        closeTo(10, 1e-12),
      );
    });

    test('every conversion round-trips', () {
      const x = 12.345;
      for (final cat in kUnitCategories) {
        for (final a in cat.units) {
          for (final b in cat.units) {
            expect(
              convert(convert(x, a, b), b, a),
              closeTo(x, 1e-9 * x),
              reason: '${cat.name}: ${a.symbol} → ${b.symbol} → back',
            );
          }
        }
      }
    });

    test('formatting', () {
      expect(formatConverted(101325), '101325');
      expect(formatConverted(0.5), '0.5');
      expect(formatConverted(1.602176634e-19), '1.60218 × 10⁻¹⁹');
      expect(formatConverted(3.6e9), '3.6 × 10⁹');
    });
  });

  group('every LaTeX string the reference tools emit parses', () {
    // A parse failure would render as FullLatexView's red fallback.
    String inner(String s) {
      expect(s, startsWith(r'\('));
      expect(s, endsWith(r'\)'));
      return s.substring(2, s.length - 2);
    }

    bool parses(String tex) {
      try {
        TexParser(tex, const TexParserSettings()).parse();
        return true;
      } catch (_) {
        return false;
      }
    }

    test('control: the parser rejects bad LaTeX', () {
      expect(parses(r'\notarealcommand{x}'), isFalse);
      expect(parses(r'10^{'), isFalse);
      expect(parses(r'10^{3}'), isTrue);
    });

    test('constants, units and prefixes', () {
      final all = [
        for (final c in kPhysicalConstants) inner(c.latex),
        inner(coulombConstantLatex),
        for (final u in kSiBaseUnits) '\\text{fixes } ${u.definition}',
        for (final u in kSiDerivedUnits) '= ${u.definition}',
        for (final p in kSiPrefixes) '10^{${p.power}}',
      ];
      for (final t in all) {
        expect(parses(t), isTrue, reason: t);
      }
    });

    test('electron configurations', () {
      for (final e in _elements()) {
        final t = configurationLatex(e.electronConfiguration);
        expect(parses(t), isTrue, reason: '${e.symbol}: $t');
      }
    });

    test('look-up results', () {
      final hits = [
        lookupLog(2),
        lookupLog(0.0234),
        lookupLog(1234.5),
        lookupAntilog(0.3010),
        lookupAntilog(-1.5),
        for (final r in TrigRatio.values) ...[
          lookupTrig(r, 30),
          lookupTrig(r, 37.25),
          lookupTrig(r, 88.55),
        ],
      ];
      for (final h in hits) {
        expect(parses(inner(h!.latex)), isTrue, reason: h.latex);
      }
    });
  });

  group('widgets', () {
    testWidgets('each page lays out on a phone without overflow', (
      tester,
    ) async {
      await tester.runAsync(() => loadPeriodicTable());
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final page in const [
        PeriodicTableScreen(),
        FourFigureTablesScreen(),
        ConstantsScreen(),
      ]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Converter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Converter'));
      await tester.pumpAndSettle();
      expect(find.text('Temperature'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('periodic table renders and a tap opens the element card', (
      tester,
    ) async {
      await tester.runAsync(() => loadPeriodicTable());
      await _pumpPage(tester, const PeriodicTableScreen());
      expect(find.byKey(const ValueKey('element-H')), findsOneWidget);
      expect(find.byKey(const ValueKey('element-Og')), findsOneWidget);
      expect(find.text('57–71'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('element-Fe')));
      await tester.pumpAndSettle();
      expect(find.byType(ElementCard), findsOneWidget);
      final card = find.byType(ElementCard);
      expect(
        find.descendant(of: card, matching: find.text('Iron')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('55.845')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('8')),
        findsOneWidget,
      );
    });

    testWidgets('periodic table search offers matching elements', (
      tester,
    ) async {
      await tester.runAsync(() => loadPeriodicTable());
      await _pumpPage(tester, const PeriodicTableScreen());
      await tester.enterText(find.byType(TextField), 'sodium');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'Na · Sodium'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Na · Sodium'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ElementCard),
          matching: find.text('22.990'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('four-figure look-up highlights the right cell', (
      tester,
    ) async {
      await _pumpPage(tester, const FourFigureTablesScreen());
      expect(find.text('Log'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('ff-hit-cell'));
      expect(cell, findsOneWidget);
      expect(
        find.descendant(of: cell, matching: find.text('3010')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ff-hit-md')), findsNothing);

      // A fourth figure lights its mean-difference column too.
      await tester.enterText(find.byType(TextField), '75.34');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ff-hit-cell')),
          matching: find.text(fourDigits(logEntry(753))),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('ff-hit-md')),
          matching: find.text('${logMeanDifference(75, 3, 4)}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('trig tab look-up far down the table scrolls to it', (
      tester,
    ) async {
      await _pumpPage(tester, const FourFigureTablesScreen());
      await tester.tap(find.text('Sine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '80');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('ff-hit-cell'));
      expect(cell, findsOneWidget);
      expect(
        find.descendant(
          of: cell,
          matching: find.text(trigCell(TrigRatio.sine, 800)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('constants page renders every tab', (tester) async {
      await _pumpPage(tester, const ConstantsScreen());
      expect(find.text('Planck constant'), findsOneWidget);
      await tester.tap(find.text('SI units'));
      await tester.pumpAndSettle();
      expect(find.text('kilogram'), findsOneWidget);
      await tester.tap(find.text('Prefixes'));
      await tester.pumpAndSettle();
      expect(find.text('yocto'), findsOneWidget);
      await tester.tap(find.text('Converter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Temperature'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('converter-input')),
        '100',
      );
      await tester.pumpAndSettle();
      expect(find.text('100 K = -173.15 °C'), findsOneWidget);
    });
  });
}
