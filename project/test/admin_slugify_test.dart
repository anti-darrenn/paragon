// Editor-created resource ids. They share a namespace with the seeder's
// filename-derived ids, and the seeder overwrites on collision, so the
// shape matters.

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/admin_resource_repository.dart';

void main() {
  test('lower-cases and hyphenates', () {
    expect(slugify('Completing the Square'), 'completing-the-square');
  });

  test('drops LaTeX and punctuation rather than leaking it into an id', () {
    expect(slugify(r'Roots of \(ax^2+bx+c\)'), 'roots-of-ax-2-bx-c');
    expect(slugify('  --What?!--  '), 'what');
  });

  test('a title with no letters or digits gives an empty slug', () {
    // The repository substitutes "article" for this case.
    expect(slugify(r'\(\)'), '');
  });

  test('caps at 60 characters without a trailing hyphen', () {
    final slug = slugify('word ' * 30);
    expect(slug.length, lessThanOrEqualTo(60));
    expect(slug.endsWith('-'), isFalse);
  });
}
