import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/theme/app_theme.dart';
import 'package:paragon/core/widgets/ui/ui.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('loading keeps its width, disables, and says so', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(AppButton(label: 'Save changes', onPressed: () => taps++)),
      );
      final idle = tester.getSize(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);

      await tester.pumpWidget(
        _app(
          AppButton(label: 'Save changes', loading: true, onPressed: () => taps++),
        ),
      );
      expect(tester.getSize(find.byType(AppButton)), idle);
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(taps, 1, reason: 'a loading button cannot be pressed');
      expect(find.bySemanticsLabel('Save changes, loading'), findsOneWidget);
    });

    testWidgets('each tone builds the matching Material button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AppButton(label: 'a', onPressed: () {}),
              AppButton(label: 'b', tone: ButtonTone.secondary, onPressed: () {}),
              AppButton(label: 'c', tone: ButtonTone.ghost, onPressed: () {}),
              AppButton(label: 'd', tone: ButtonTone.destructive, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNWidgets(2));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('sizes are 36, 48 and 56 tall', (tester) async {
      for (final (size, height) in [
        (ButtonSize.sm, 36.0),
        (ButtonSize.md, 48.0),
        (ButtonSize.lg, 56.0),
      ]) {
        await tester.pumpWidget(
          _app(AppButton(label: 'Go', size: size, onPressed: () {})),
        );
        // The drawn button, not its tap area: on a phone Material pads
        // anything shorter than 48 to a 48 target.
        final drawn = find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        );
        expect(tester.getSize(drawn.first).height, height);
      }
    });
  });

  testWidgets('confirmDialog answers true, false, and false when dismissed', (
    tester,
  ) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
              await confirmDialog(
                context,
                title: 'Delete this deck?',
                confirmLabel: 'Delete deck',
                destructive: true,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.text('Delete deck'));
    await tester.pumpAndSettle();
    await open();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await open();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(answers, [true, false, false]);
  });

  testWidgets('breadcrumb links are focusable and the last is current', (
    tester,
  ) async {
    var went = '';
    await tester.pumpWidget(
      _app(
        Breadcrumbs([
          Crumb('Courses', onTap: () => went = 'courses'),
          const Crumb('Mathematics'),
        ]),
      ),
    );
    expect(
      find.descendant(of: find.byType(Breadcrumbs), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    await tester.tap(find.text('Courses'));
    expect(went, 'courses');
    expect(find.bySemanticsLabel('Mathematics, current page'), findsOneWidget);
  });

  group('EmptyState', () {
    testWidgets('the old icon-and-one-action form still builds', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here yet',
            message: 'Saved questions appear here.',
            action: TextButton(onPressed: () {}, child: const Text('Browse')),
          ),
        ),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
    });

    testWidgets('an illustration replaces the icon, with a second action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          EmptyState(
            illustration: IllustrationAsset.empty,
            title: 'No decks yet',
            action: AppButton(label: 'New deck', onPressed: () {}),
            secondaryAction: AppButton(
              label: 'How decks work',
              tone: ButtonTone.ghost,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byType(Illustration), findsOneWidget);
      expect(find.text('New deck'), findsOneWidget);
      expect(find.text('How decks work'), findsOneWidget);
    });
  });

  testWidgets('LoadingView waits before showing a spinner', (tester) async {
    await tester.pumpWidget(_app(const LoadingView()));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SegmentedProgress becomes a bar past 30 questions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 300,
          child: SegmentedProgress(
            states: [SegmentState.right, SegmentState.wrong, SegmentState.pending],
            current: 2,
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('2 of 3 done'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: SegmentedProgress(
            states: List.filled(40, SegmentState.answered),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('toasts replace one another', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    showToast(ctx, 'First');
    showToast(ctx, 'Saved', tone: Tone.success);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Tone.success.icon), findsOneWidget);
  });

  testWidgets('InlineAlert and Tag build in both themes', (tester) async {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              InlineAlert(
                tone: Tone.warning,
                title: 'Marked at the end',
                message: 'You see your score after the last question.',
              ),
              Tag('Unlocked', tone: Tone.success, icon: Icons.lock_open),
            ],
          ),
          theme: theme,
        ),
      );
      expect(find.text('Marked at the end'), findsOneWidget);
      expect(find.text('Unlocked'), findsOneWidget);
    }
  });
}
