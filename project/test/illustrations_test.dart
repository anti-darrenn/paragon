import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/ui/illustration.dart';

/// The illustrations are files on disk that only the app reads, so these
/// checks are what keep them safe, small and themeable.
void main() {
  // Every colour a drawing may use: the five markers the app swaps for the
  // theme's own, and three brand colours that read on both themes.
  const allowed = {
    '#101010', '#FEFEFE', '#C8C8C8', '#808080', '#FF00FF', // markers
    '#FF7700', '#8B5CF6', '#E3B341', // orange, violet, gold
  };

  for (final asset in IllustrationAsset.values) {
    test('${asset.file} exists, is small, safe and in marker colours', () {
      final file = File(asset.path);
      expect(file.existsSync(), isTrue, reason: '${asset.path} is missing');
      final svg = file.readAsStringSync();
      expect(file.lengthSync(), lessThan(8 * 1024));
      expect(svg.toLowerCase(), isNot(contains('<script')));
      expect(svg.toLowerCase(), isNot(contains('href')));
      expect(svg, isNot(contains('<text')), reason: 'text needs a font');
      final colours = RegExp(
        r'#[0-9A-Fa-f]{6}',
      ).allMatches(svg).map((m) => m.group(0)!.toUpperCase()).toSet();
      expect(colours.difference(allowed), isEmpty);
    });
  }

  test('pubspec bundles the folder', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/illustrations/'),
    );
  });

  test('every subject the app colours has its own motif', () {
    for (final name in [
      'Mathematics',
      'Further Mathematics',
      'Physics',
      'Chemistry',
      'Government',
      'Biology',
      'Economics',
      'English Language',
      'Commerce',
      'Music',
    ]) {
      expect(
        IllustrationAsset.forSubject(name),
        isNot(IllustrationAsset.subjectGeneric),
        reason: name,
      );
    }
    expect(
      IllustrationAsset.forSubject('Literature'),
      IllustrationAsset.subjectGeneric,
    );
  });

  test('the colour mapper swaps markers and keeps everything else', () {
    const mapper = IllustrationColours(
      ink: Color(0xFF111111),
      paper: Color(0xFF222222),
      shade: Color(0xFF333333),
      line: Color(0xFF444444),
      accent: Color(0xFF555555),
    );
    expect(
      mapper.substitute(null, 'path', 'fill', const Color(0xFFFF00FF)),
      const Color(0xFF555555),
    );
    expect(
      mapper.substitute(null, 'path', 'fill', const Color(0xFFFF7700)),
      const Color(0xFFFF7700),
    );
  });
}
