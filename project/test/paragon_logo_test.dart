import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/paragon_logo.dart';

void main() {
  Future<String> assetShown(WidgetTester tester, Brightness b) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: b),
        home: const ParagonLogo(height: 30),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image)).image;
    return (image as AssetImage).assetName;
  }

  testWidgets('the light theme gets the black-lettered logo', (tester) async {
    expect(await assetShown(tester, Brightness.light), ParagonLogo.lightAsset);
  });

  testWidgets('CONTROL: the dark theme keeps the white-lettered one', (
    tester,
  ) async {
    expect(await assetShown(tester, Brightness.dark), ParagonLogo.darkAsset);
  });
}
