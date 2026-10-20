import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/plan/planner.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/features/study/planner/planner_screen.dart';
import 'package:paragon/features/study/planner/planner_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlannerTask _task(String id, String day, {bool done = false}) =>
    PlannerTask(id: id, day: day, title: 'Topic $id', done: done);

/// The study planner: a week of days, kept on the device.
void main() {
  group('days', () {
    test('a week runs Monday to Sunday, by the calendar', () {
      // Sunday 25 October 2026, and the Monday it starts from.
      final week = weekOf(DateTime(2026, 10, 25));
      expect(dayKey(week.first), '2026-10-19');
      expect(dayKey(week.last), '2026-10-25');
      expect(dayKey(weekOf(DateTime(2026, 10, 19)).first), '2026-10-19');
      expect(week.map((d) => d.weekday), [1, 2, 3, 4, 5, 6, 7]);
      // Across a month end.
      expect(dayKey(weekOf(DateTime(2026, 11, 1)).first), '2026-10-26');
    });

    test('day keys round-trip; anything else is refused', () {
      expect(parseDayKey('2026-02-28'), DateTime(2026, 2, 28));
      expect(parseDayKey('2026-02-30'), isNull);
      expect(parseDayKey('19/10/2026'), isNull);
    });
  });

  group('Planner', () {
    test('add, toggle, move and remove', () {
      var p = Planner.empty
          .add(_task('a', '2026-10-19'))
          .add(_task('b', '2026-10-19'));
      expect(p.on('2026-10-19').map((t) => t.id), ['a', 'b']);
      p = p.toggle('a');
      expect(p.on('2026-10-19').first.done, isTrue);
      p = p.move('b', '2026-10-20');
      expect(p.on('2026-10-20').single.id, 'b');
      p = p.remove('a');
      expect(p.on('2026-10-19'), isEmpty);
    });

    test('a day holds at most maxPerDay', () {
      var p = Planner.empty;
      for (var i = 0; i < Planner.maxPerDay + 3; i++) {
        p = p.add(_task('$i', '2026-10-19'));
      }
      expect(p.on('2026-10-19'), hasLength(Planner.maxPerDay));
    });

    test('unfinished tasks from earlier days carry over to today', () {
      final p = Planner([
        _task('old', '2026-10-15'),
        _task('done', '2026-10-15', done: true),
        _task('today', '2026-10-19'),
      ]);
      expect(p.leftBehind('2026-10-19'), 1);
      final next = p.carryOver('2026-10-19');
      expect(next.leftBehind('2026-10-19'), 0);
      expect(next.on('2026-10-19').map((t) => t.id), ['today', 'old']);
      // CONTROL: what was done stays on its day.
      expect(next.on('2026-10-15').single.id, 'done');
    });

    test('old days are pruned', () {
      final p = Planner([
        _task('old', '2026-09-01'),
        _task('recent', '2026-10-01'),
      ]).pruned(DateTime(2026, 10, 19));
      expect(p.tasks.map((t) => t.id), ['recent']);
    });

    test('tally counts only the days asked for', () {
      final p = Planner([
        _task('a', '2026-10-13', done: true),
        _task('b', '2026-10-14'),
        _task('c', '2026-10-21', done: true),
      ]);
      expect(p.tally(['2026-10-13', '2026-10-14']), (done: 1, total: 2));
    });

    test('JSON round-trips, and bad entries are dropped, not thrown', () {
      final p = Planner([
        const PlannerTask(
          id: 'a',
          day: '2026-10-19',
          title: 'Indices',
          subject: 'Mathematics',
          path: '/subject/mathematics/course/topic/indices',
          minutes: 30,
          done: true,
        ),
      ]);
      final back = Planner.fromJson(p.toJson());
      expect(back.tasks.single.toJson(), p.tasks.single.toJson());
      final messy = Planner.fromJson([
        {'id': 'x', 'day': 'yesterday', 'title': 'Bad day'},
        {'id': '', 'day': '2026-10-19', 'title': 'No id'},
        {'id': 'y', 'day': '2026-10-19', 'title': '  '},
        'not a map',
        {'id': 'z', 'day': '2026-10-19', 'title': 'Fine', 'minutes': -5},
      ]);
      expect(messy.tasks.single.id, 'z');
      expect(messy.tasks.single.minutes, 0);
      expect(Planner.fromJson('nonsense').tasks, isEmpty);
    });
  });

  group('spreadOverWeek', () {
    PlanIdea idea(String t) => (title: t, subject: 'Maths', path: '/$t');
    var n = 0;
    String id() => 'n${n++}';

    test('one a day in turn, best first', () {
      final tasks = spreadOverWeek(
        planner: Planner.empty,
        ideas: [idea('A'), idea('B'), idea('C'), idea('D')],
        days: ['d1', 'd2', 'd3'],
        newId: id,
      );
      expect(tasks.map((t) => '${t.day}:${t.title}'), [
        'd1:A',
        'd2:B',
        'd3:C',
        'd1:D',
      ]);
    });

    test('skips full days and what is already planned', () {
      final planner = Planner([
        _task('1', 'd1'),
        _task('2', 'd1'),
        const PlannerTask(id: '3', day: 'd2', title: 'A', subject: 'Maths'),
      ]);
      final tasks = spreadOverWeek(
        planner: planner,
        ideas: [idea('A'), idea('B'), idea('C')],
        days: ['d1', 'd2'],
        newId: id,
      );
      expect(tasks.map((t) => '${t.day}:${t.title}'), ['d2:B']);
    });
  });

  group('PlannerScreen', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          selectedSubjectSlugsProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlannerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('shows the week, today marked, and an empty plan', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Your week'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('0 of 0 done'), findsOneWidget);
      final today = dayKey(DateTime.now());
      expect(find.byKey(ValueKey('planner.day.$today')), findsOneWidget);
    });

    testWidgets('a planned task can be ticked off', (tester) async {
      final container = await pump(tester);
      final today = dayKey(DateTime.now());
      // No account, so nothing is written; the state still holds.
      await container
          .read(plannerProvider.notifier)
          .add(PlannerTask(id: 't1', day: today, title: 'Indices'));
      await tester.pumpAndSettle();
      expect(find.text('Indices'), findsOneWidget);
      expect(find.text('0 of 1 done'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('planner.task.t1')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 done'), findsOneWidget);
      expect(find.textContaining('Look at you go'), findsOneWidget);
    });

    testWidgets('next week has its own days', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(find.text('Next week'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });
  });
}
