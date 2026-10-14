/// The weekly goal: a number of questions a week the student chose, in
/// place of the daily streak that was removed (CLAUDE.md, "Streaks are
/// gone"). A week, not a day, so one missed evening costs nothing; no run
/// of weeks is kept, so there is nothing to lose. It never gates anything.
library;

/// The choices offered. Fifty is a light week; four hundred is a drill a
/// day.
const List<int> kWeeklyGoals = [50, 100, 200, 400];

const int kDefaultWeeklyGoal = 100;

/// Lagos is UTC+1 all year (no daylight saving).
const Duration _lagosOffset = Duration(hours: 1);

/// The start of the week containing [now] — Monday 00:00 in Lagos — as a
/// UTC instant, so it is the same week whatever the device's time zone.
DateTime weekStartLagos(DateTime now) {
  final lagos = now.toUtc().add(_lagosOffset);
  final monday = DateTime.utc(
    lagos.year,
    lagos.month,
    lagos.day,
  ).subtract(Duration(days: lagos.weekday - DateTime.monday));
  return monday.subtract(_lagosOffset);
}

/// This week's progress toward the goal.
class WeeklyGoalProgress {
  const WeeklyGoalProgress({required this.goal, required this.done});

  final int goal;
  final int done;

  double get fraction => goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0);
  bool get met => goal > 0 && done >= goal;
  int get left => met ? 0 : goal - done;
}
