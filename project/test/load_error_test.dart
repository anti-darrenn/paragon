import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/load_error.dart';

void main() {
  const firestoreError =
      '[cloud_firestore/unavailable] The service is currently unavailable.';

  testWidgets('shows a plain message, never the exception text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadError(error: Exception(firestoreError), onRetry: () {}),
        ),
      ),
    );

    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('Try again calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadError(error: 'x', onRetry: () => retries++),
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('a screen-specific message replaces the default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadError(
            error: 'x',
            onRetry: () {},
            message: "This test couldn't be loaded.",
          ),
        ),
      ),
    );

    expect(find.text("This test couldn't be loaded."), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsNothing);
  });
}
