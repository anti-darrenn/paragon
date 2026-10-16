import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/legal/about_content.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/features/about_screen.dart';

/// The About text lives in `about_content.dart` so the app screen and the
/// static /about/ page (`tool/export_legal.dart`) print the same words.
void main() {
  testWidgets('the About screen shows every shared section', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(null)],
        child: const MaterialApp(home: AboutScreen()),
      ),
    );
    await tester.pump();
    final sections = [...kAboutSections, ?aboutThanks];
    // Control: the content is really there to compare against.
    expect(sections.length, greaterThanOrEqualTo(3));
    for (final s in sections) {
      expect(find.text(s.heading), findsOneWidget, reason: s.heading);
      for (final p in s.paragraphs) {
        expect(find.text(p), findsOneWidget, reason: p);
      }
    }
    expect(find.text(kAboutContactText), findsOneWidget);
  });
}
