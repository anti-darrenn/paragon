import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runtime font fetching is off (main.dart), so every `GoogleFonts.<family>`
/// the app asks for must be bundled in assets/google_fonts/, or the text
/// silently falls back to the default font. Atkinson Hyperlegible, the
/// reading font, shipped that way for a release: nothing caught it.
void main() {
  // `spaceGrotesk` → `SpaceGrotesk`, the prefix of the bundled file names.
  String fileFamily(String method) =>
      method[0].toUpperCase() + method.substring(1);

  Set<String> familiesUsed(Iterable<String> sources) => {
    for (final source in sources)
      for (final m in RegExp(
        r'GoogleFonts\.([a-z][A-Za-z0-9]*?)(?:TextTheme)?\(',
      ).allMatches(source))
        fileFamily(m.group(1)!),
  };

  final bundled = Directory('assets/google_fonts')
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.ttf'))
      .toList();

  bool isBundled(String family) =>
      bundled.any((n) => n.startsWith('$family-Regular.ttf')) ||
      bundled.any((n) => RegExp('^$family-[A-Za-z]+\.ttf\$').hasMatch(n));

  test('control: a family that is not bundled is caught', () {
    final used = familiesUsed(['GoogleFonts.lexend(textStyle: s)']);
    expect(used, {'Lexend'});
    expect(isBundled('Lexend'), isFalse);
  });

  test('every GoogleFonts family used in lib/ is bundled', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync());
    final used = familiesUsed(sources);
    expect(used, containsAll(['SpaceGrotesk', 'AtkinsonHyperlegible']));
    for (final family in used) {
      expect(isBundled(family), isTrue, reason: '$family is not bundled');
    }
  });

  test('the reading font has every variant google_fonts asks for', () {
    for (final v in ['Regular', 'Italic', 'Bold', 'BoldItalic']) {
      expect(bundled, contains('AtkinsonHyperlegible-$v.ttf'));
    }
  });
}
