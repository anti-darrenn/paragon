import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/lesson_asset.dart';
import 'package:paragon/core/providers/reading_settings_provider.dart';
import 'package:paragon/core/repositories/learn_repository.dart';
import 'package:paragon/core/widgets/lesson_blocks/figure_block.dart';
import 'package:paragon/core/widgets/question_image.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>';

Future<List<String>> _pump(
  WidgetTester tester,
  String? assetId, {
  bool lowData = false,
}) async {
  final fetched = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lowDataModeProvider.overrideWithValue(lowData),
        lessonAssetProvider.overrideWith((ref, id) async {
          fetched.add(id);
          return id == 'diag1'
              ? const LessonAsset(
                  id: 'diag1',
                  mime: 'image/svg+xml',
                  data: _svg,
                  width: 10,
                  height: 10,
                )
              : null;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(body: QuestionImage(assetId: assetId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fetched;
}

void main() {
  testWidgets('a question with a diagram shows it', (tester) async {
    final fetched = await _pump(tester, 'diag1');
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(fetched, ['diag1']);
  });

  testWidgets('CONTROL: a question without one shows and fetches nothing', (
    tester,
  ) async {
    final fetched = await _pump(tester, null);
    expect(find.byType(FigureView), findsNothing);
    expect(fetched, isEmpty);
  });

  testWidgets('low-data mode waits for a tap', (tester) async {
    final fetched = await _pump(tester, 'diag1', lowData: true);
    expect(find.text('Tap to load image'), findsOneWidget);
    expect(fetched, isEmpty);

    await tester.tap(find.text('Tap to load image'));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('a missing diagram says so instead of failing', (tester) async {
    await _pump(tester, 'gone');
    expect(find.text("This image couldn't be loaded."), findsOneWidget);
  });
}
