import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/deferred_screen.dart';

/// The WAEC exam went blank after the setup screen (2026-10-16): the two
/// shared one load by a group name, so the exam's own deferred library was
/// never loaded, and compiled JavaScript refuses to run it. The VM does not
/// enforce that, so this counts the loads instead.
// Top-level, like a deferred prefix's loadLibrary, so each has one identity.
var setupLoads = 0;
var examLoads = 0;
Future<void> loadSetup() async => setupLoads++;
Future<void> loadExam() async => examLoads++;

void main() {
  setUp(DeferredScreen.resetLoads);

  Future<void> show(
    WidgetTester tester,
    Future<void> Function() load,
    String text,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredScreen(load: load, builder: (_) => Text(text)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each deferred library is loaded by its own loadLibrary', (
    tester,
  ) async {
    await show(tester, loadSetup, 'setup');
    expect(find.text('setup'), findsOneWidget);
    await show(tester, loadExam, 'exam');
    expect(find.text('exam'), findsOneWidget);
    expect(examLoads, 1, reason: 'the exam must load its own library');
  });

  testWidgets('control: going back to a loaded screen does not reload it', (
    tester,
  ) async {
    await show(tester, loadSetup, 'setup');
    await show(tester, loadExam, 'exam');
    final before = setupLoads;
    await show(tester, loadSetup, 'setup again');
    expect(find.text('setup again'), findsOneWidget);
    expect(setupLoads, before);
  });
}
