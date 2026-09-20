// Parses every LaTeX expression in tools/scraper/data/generated_*.json with the
// real flutter_math_fork parser - the same call Math.tex makes internally.
// Anything that throws here renders as the red monospace fallback in the app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/full_latex_view.dart';

/// Pulls out the \(...\) and \[...\] segments exactly the way FullLatexView does,
/// so we test precisely the strings that reach Math.tex.
List<String> extractMath(String s) {
  final out = <String>[];
  int pos = 0;
  while (pos < s.length) {
    if (s.codeUnitAt(pos) == 92 &&
        pos + 1 < s.length &&
        (s[pos + 1] == '(' || s[pos + 1] == '[')) {
      final open = s[pos + 1];
      final close = open == '(' ? r'\)' : r'\]';
      final start = pos + 2;
      final end = s.indexOf(close, start);
      if (end != -1) {
        out.add(s.substring(start, end));
        pos = end + 2;
        continue;
      }
    }
    pos++;
  }
  return out;
}

void main() {
  // Guards against a vacuous pass: if the parser never threw, the suite below
  // would be green no matter how broken the content was.
  test('control - the parser really does reject bad LaTeX', () {
    final bad = <String>[
      r'\frac{1}{',
      r'\begin{pmatrix} 1 & 2',
      r'\notarealcommand{x}',
      r'{\left(',
    ];
    for (final b in bad) {
      var threw = false;
      try {
        TexParser(b, const TexParserSettings()).parse();
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue, reason: 'expected "$b" to fail parsing');
    }
  });

  test('every generated LaTeX expression parses', () {
    final dir = Directory('tools/scraper/data');
    expect(dir.existsSync(), isTrue, reason: 'data dir not found');

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.split(RegExp(r'[/\\]')).last.startsWith('generated_') &&
            f.path.endsWith('.json'))
        .toList();
    expect(files, isNotEmpty, reason: 'no generated_*.json files found');

    // expression -> where it first appeared
    final exprs = <String, String>{};
    var questionCount = 0;

    for (final f in files) {
      final name = f.path.split(RegExp(r'[/\\]')).last;
      final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
      for (var i = 0; i < list.length; i++) {
        final q = list[i] as Map<String, dynamic>;
        questionCount++;
        final parts = <String>[
          q['text'] as String,
          q['explanation'] as String,
          ...(q['options'] as List<dynamic>).cast<String>(),
        ];
        for (final p in parts) {
          for (final e in extractMath(p)) {
            exprs.putIfAbsent(e, () => '$name[$i]');
          }
        }
      }
    }

    // failures grouped by the command that most likely caused them
    final failures = <String, List<String>>{};
    var failCount = 0;

    for (final entry in exprs.entries) {
      try {
        TexParser(entry.key, const TexParserSettings()).parse();
      } catch (e) {
        failCount++;
        final msg = e is ParseException ? e.message : e.toString();
        final key = msg.length > 90 ? msg.substring(0, 90) : msg;
        failures.putIfAbsent(key, () => []).add('${entry.value}  ::  ${entry.key}');
      }
    }

    stdout.writeln('Files scanned:        ${files.length}');
    stdout.writeln('Questions scanned:    $questionCount');
    stdout.writeln('Distinct expressions: ${exprs.length}');
    stdout.writeln('Failing expressions:  $failCount');

    if (failures.isNotEmpty) {
      stdout.writeln('\n--- FAILURES BY ERROR ---');
      final sorted = failures.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final f in sorted) {
        stdout.writeln('\n[${f.value.length} distinct] ${f.key}');
        for (final ex in f.value.take(3)) {
          stdout.writeln('    $ex');
        }
      }
    }

    expect(failCount, 0,
        reason: '$failCount distinct expressions fail to parse and would '
            'render as the red monospace fallback');
  });

  // Parsing is only half the path - Math.tex can also fail while building.
  // Render a real sample through FullLatexView and look for the red fallback.
  testWidgets('a sample of generated questions renders without the fallback',
      (tester) async {
    final dir = Directory('tools/scraper/data');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.split(RegExp(r'[/\\]')).last.startsWith('generated_') &&
            f.path.endsWith('.json'))
        .toList();

    // one question from near the start and middle of every topic file
    final samples = <String>[];
    for (final f in files) {
      final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
      for (final idx in [0, list.length ~/ 2]) {
        final q = list[idx] as Map<String, dynamic>;
        samples.add(q['text'] as String);
        samples.addAll((q['options'] as List<dynamic>).cast<String>());
      }
    }

    var rendered = 0;
    final bad = <String>[];

    for (final s in samples) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: FullLatexView(latex: s),
            ),
          ),
        ),
      );
      rendered++;

      final reds = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == Colors.redAccent)
          .toList();
      if (reds.isNotEmpty) bad.add(s);
    }

    stdout.writeln('Rendered strings:     $rendered');
    stdout.writeln('Fallback detected in: ${bad.length}');
    for (final b in bad.take(5)) {
      stdout.writeln('    $b');
    }

    expect(bad, isEmpty,
        reason: '${bad.length} sampled strings rendered the red error fallback');
  });
}
