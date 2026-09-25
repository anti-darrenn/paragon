import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/subject_tools.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/study/study_dock.dart';
import 'package:paragon/core/study/study_tool.dart';
import 'package:paragon/core/study/study_tool_registry.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/features/study/scratchpad/scratchpad_model.dart';
import 'package:paragon/features/study/scratchpad/scratchpad_overlay.dart';
import 'package:paragon/features/study/scratchpad/scratchpad_provider.dart';
import 'package:paragon/features/study/scratchpad/scratchpad_tool.dart';

ScratchStroke _line(Offset a, Offset b, {double width = 2}) => ScratchStroke(
  points: [a, Offset.lerp(a, b, 0.5)!, b],
  color: AppColors.accentBlue,
  width: width,
);

void main() {
  group('ScratchpadModel', () {
    final s1 = _line(const Offset(0, 0), const Offset(100, 0));
    final s2 = _line(const Offset(0, 50), const Offset(100, 50));

    test('adds a stroke', () {
      final m = const ScratchpadModel().addStroke(s1);
      expect(m.strokes, [s1]);
      expect(m.canUndo, isTrue);
      expect(m.canRedo, isFalse);
    });

    test('an empty stroke is not recorded', () {
      const empty = ScratchStroke(
        points: [],
        color: AppColors.accentBlue,
        width: 2,
      );
      final m = const ScratchpadModel().addStroke(empty);
      expect(m.strokes, isEmpty);
      expect(m.canUndo, isFalse);
    });

    test('undo removes the last stroke, redo brings it back', () {
      final m = const ScratchpadModel().addStroke(s1).addStroke(s2);
      final undone = m.undo();
      expect(undone.strokes, [s1]);
      expect(undone.canRedo, isTrue);
      expect(undone.redo().strokes, [s1, s2]);
    });

    test('a new stroke clears redo', () {
      final m = const ScratchpadModel().addStroke(s1).undo().addStroke(s2);
      expect(m.canRedo, isFalse);
      expect(m.redo().strokes, [s2]);
    });

    test('clear then undo restores every stroke', () {
      final cleared = const ScratchpadModel()
          .addStroke(s1)
          .addStroke(s2)
          .clear();
      expect(cleared.strokes, isEmpty);
      expect(cleared.undo().strokes, [s1, s2]);
    });

    test('clearing an empty page records nothing', () {
      final m = const ScratchpadModel().clear();
      expect(m.canUndo, isFalse);
    });

    test('undo and redo on an empty model are no-ops', () {
      const m = ScratchpadModel();
      expect(identical(m.undo(), m), isTrue);
      expect(identical(m.redo(), m), isTrue);
      expect(m.undo().strokes, isEmpty);
    });

    test('eraser removes only the strokes it crosses', () {
      final far = _line(const Offset(0, 400), const Offset(100, 400));
      final m = const ScratchpadModel().addStroke(s1).addStroke(far);
      // A vertical swipe through s1 at x = 50, stopping well short of y=400.
      final erased = m.eraseAlong(const [Offset(50, -20), Offset(50, 20)], 8);
      expect(erased.strokes, [far]); // control: the far stroke survives
      expect(erased.undo().strokes, [s1, far]);
    });

    test('eraser reaches a stroke within its radius without crossing it', () {
      final m = const ScratchpadModel().addStroke(s1);
      expect(m.hits(const [Offset(50, 9)], 8), {0}); // 8 + width/2 = 9
      expect(m.hits(const [Offset(50, 12)], 8), isEmpty); // control
    });

    test('erasing empty space records no history', () {
      final m = const ScratchpadModel().addStroke(s1);
      final after = m.eraseAlong(const [Offset(500, 500)], 8);
      expect(identical(after, m), isTrue);
    });

    test('segment distance: crossing is zero, parallel is the gap', () {
      expect(
        ScratchpadModel.segmentDistance(
          const Offset(0, 0),
          const Offset(10, 10),
          const Offset(0, 10),
          const Offset(10, 0),
        ),
        0,
      );
      expect(
        ScratchpadModel.segmentDistance(
          const Offset(0, 0),
          const Offset(10, 0),
          const Offset(0, 5),
          const Offset(10, 5),
        ),
        5,
      );
    });
  });

  group('ScratchpadOverlay', () {
    late ProviderContainer container;
    late int taps;
    late int closes;

    setUp(() {
      container = ProviderContainer();
      taps = 0;
      closes = 0;
    });
    tearDown(() => container.dispose());

    Future<void> pump(WidgetTester tester, {bool open = true}) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const Center(child: Text('the question')),
                    ),
                  ),
                  if (open)
                    Positioned.fill(
                      child: ScratchpadOverlay(close: () => closes++),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Well below the toolbar, which sits at the top.
    const spot = Offset(300, 450);

    testWidgets('dragging draws a stroke', (tester) async {
      await pump(tester);
      await tester.dragFrom(spot, const Offset(120, 60));
      await tester.pump();
      final strokes = container.read(scratchpadProvider).strokes;
      expect(strokes, hasLength(1));
      expect(strokes.single.points.length, greaterThan(1));
      expect(taps, 0);
    });

    testWidgets('strokes survive closing and reopening', (tester) async {
      await pump(tester);
      await tester.dragFrom(spot, const Offset(120, 60));
      await pump(tester, open: false);
      await pump(tester);
      expect(container.read(scratchpadProvider).strokes, hasLength(1));
    });

    testWidgets('eraser drag removes the stroke', (tester) async {
      await pump(tester);
      await tester.dragFrom(spot, const Offset(120, 0));
      await tester.tap(find.byTooltip('Eraser'));
      await tester.pump();
      await tester.dragFrom(spot + const Offset(60, -30), const Offset(0, 60));
      await tester.pump();
      expect(container.read(scratchpadProvider).strokes, isEmpty);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(container.read(scratchpadProvider).strokes, hasLength(1));
    });

    testWidgets('clear asks first', (tester) async {
      await pump(tester);
      await tester.dragFrom(spot, const Offset(120, 60));
      await tester.pump();
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(scratchpadProvider).strokes, hasLength(1));

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(container.read(scratchpadProvider).strokes, isEmpty);
    });

    testWidgets('close button calls close', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Close scratchpad'));
      expect(closes, 1);
    });

    testWidgets('in draw mode a tap does not reach the screen', (tester) async {
      await pump(tester);
      await tester.tapAt(spot);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('see-through lets a tap reach the screen underneath', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('See through'));
      await tester.pump();
      await tester.tapAt(spot);
      await tester.pump();
      expect(taps, 1);
      expect(container.read(scratchpadProvider).strokes, isEmpty);

      // And back to drawing.
      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      await tester.tapAt(spot);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('in the study dock', () {
    test('is registered as an overlay', () {
      final tool = studyTools.whereType<ScratchpadTool>().single;
      expect(tool.id, StudyToolId.scratchpad);
      expect(tool.mode, StudyPanelMode.overlay);
    });

    testWidgets('opens over the screen and closes itself', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith(
              (ref) async => const [
                Subject(id: 'g1', name: 'Government', unitCount: 1),
              ],
            ),
          ],
          child: const MaterialApp(
            home: StudyDock(
              subjectId: 'g1',
              studyContext: StudyContext.waecExam,
              tools: [ScratchpadTool()],
              child: Scaffold(body: Text('the screen')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Study tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scratchpad'));
      await tester.pumpAndSettle();

      expect(find.byType(ScratchpadOverlay), findsOneWidget);
      expect(find.byTooltip('Study tools'), findsNothing);
      expect(find.text('the screen'), findsOneWidget);

      await tester.tap(find.byTooltip('Close scratchpad'));
      await tester.pumpAndSettle();
      expect(find.byType(ScratchpadOverlay), findsNothing);
      expect(find.byTooltip('Study tools'), findsOneWidget);
    });
  });
}
