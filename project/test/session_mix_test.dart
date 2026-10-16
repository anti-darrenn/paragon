import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/session_mix.dart';

/// Audit A8 (2026-10-15): one Indices topic test served "Evaluate n × m⁰"
/// three times in eleven questions; the topic's 300 practice questions
/// come from nine templates.
void main() {
  String id(String s) => s;

  test('numbers do not make a new template', () {
    expect(
      templateKey(r'Evaluate \(17 \times 8^{0}\).'),
      templateKey(r'Evaluate \(2 \times 5^{0}\).'),
    );
    expect(templateKey('Simplify x^2'), isNot(templateKey('Evaluate x^2')));
  });

  test('a template is capped and never served twice in a row', () {
    final pool = [
      for (var i = 0; i < 8; i++) 'Evaluate $i x 8^0',
      for (var i = 0; i < 6; i++) 'Simplify x^$i',
      for (var i = 0; i < 6; i++) 'Solve $i = x',
    ];
    final mixed = mixSession(pool, id);
    final keys = mixed.map(templateKey).toList();
    // 20 questions, 3 templates: the cap is ⌈20 / 3⌉ = 7.
    expect(keys.where((k) => k == templateKey('Evaluate 1 x 8^0')).length, 7);
    for (var i = 1; i < keys.length; i++) {
      expect(keys[i], isNot(keys[i - 1]), reason: 'position $i');
    }
  });

  test('a ten-question test from nine templates has at most two of each', () {
    final pool = [
      for (var t = 0; t < 9; t++)
        for (var i = 0; i < 2; i++) 'Template $t ${'x' * t} with $i',
    ];
    final mixed = mixSession(pool, id).take(10).toList();
    expect(mixed, hasLength(10));
    final counts = <String, int>{};
    for (final q in mixed) {
      counts.update(templateKey(q), (n) => n + 1, ifAbsent: () => 1);
    }
    expect(counts.values.every((n) => n <= 2), isTrue);
  });

  test('control: distinct past questions pass through unchanged', () {
    final pool = [
      'Find the area of a circle',
      'Solve for x',
      'Simplify the surd',
    ];
    expect(mixSession(pool, id), pool);
  });
}
