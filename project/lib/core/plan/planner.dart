/// The study planner (owner's request, 2026-10-19): what a student means
/// to study on each day of the week, ticked off as they go.
///
/// Pure — no storage, no widgets. It lives **on the device only**
/// (`planner_store.dart`, shared_preferences): no Firestore document, so
/// it costs no reads or writes on the Spark quota and needs no rule. The
/// price is that it does not follow a student to another device.
///
/// Days are the device's calendar days, as `yyyy-mm-dd`. A plan is the
/// student's own day, not a count that must agree with anyone else's (the
/// weekly goal's Lagos week is a count, which is why that one is fixed).
///
/// It never gates anything and nothing reads it but the planner and
/// Home's "Today" card. Done ticks are not attempts and never touch
/// `progress`.
library;

/// One thing to study on one day.
class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.day,
    required this.title,
    this.subject = '',
    this.path = '',
    this.minutes = 0,
    this.done = false,
  });

  final String id;

  /// `yyyy-mm-dd`, from [dayKey].
  final String day;
  final String title;

  /// The subject's name, for its colour; empty for anything else.
  final String subject;

  /// Where "Open" goes (a topic page); empty for a task with no page.
  final String path;

  /// How long the student means to spend; 0 is not said.
  final int minutes;
  final bool done;

  PlannerTask copyWith({String? day, bool? done}) => PlannerTask(
    id: id,
    day: day ?? this.day,
    title: title,
    subject: subject,
    path: path,
    minutes: minutes,
    done: done ?? this.done,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'day': day,
    'title': title,
    if (subject.isNotEmpty) 'subject': subject,
    if (path.isNotEmpty) 'path': path,
    if (minutes > 0) 'minutes': minutes,
    if (done) 'done': true,
  };

  /// Null for an entry that cannot be shown (no id, day or title); every
  /// other field falls back rather than throwing.
  static PlannerTask? fromJson(Object? json) {
    if (json is! Map) return null;
    String str(String k) => json[k] is String ? json[k] as String : '';
    final id = str('id'), day = str('day'), title = str('title').trim();
    if (id.isEmpty || parseDayKey(day) == null || title.isEmpty) return null;
    final minutes = json['minutes'];
    return PlannerTask(
      id: id,
      day: day,
      title: title,
      subject: str('subject'),
      path: str('path'),
      minutes: minutes is int && minutes > 0 ? minutes : 0,
      done: json['done'] == true,
    );
  }
}

/// Every task the student has planned, in the order they were added.
class Planner {
  const Planner(this.tasks);

  static const empty = Planner([]);

  /// Days kept behind today; older tasks are dropped on the next save.
  static const keepDays = 28;

  /// At most this many tasks a day, so a runaway "plan my week" or a
  /// stuck button cannot fill the device's storage.
  static const maxPerDay = 12;

  final List<PlannerTask> tasks;

  List<PlannerTask> on(String day) => [
    for (final t in tasks)
      if (t.day == day) t,
  ];

  bool canAddOn(String day) => on(day).length < maxPerDay;

  /// [task] added at the end of its day, unless that day is full.
  Planner add(PlannerTask task) =>
      canAddOn(task.day) ? Planner([...tasks, task]) : this;

  Planner remove(String id) => Planner([
    for (final t in tasks)
      if (t.id != id) t,
  ]);

  Planner toggle(String id) => Planner([
    for (final t in tasks) t.id == id ? t.copyWith(done: !t.done) : t,
  ]);

  /// [id] moved to [day], at the end of it, unless that day is full.
  Planner move(String id, String day) {
    final task = tasks.where((t) => t.id == id).firstOrNull;
    if (task == null || task.day == day || !canAddOn(day)) return this;
    return Planner([
      for (final t in tasks)
        if (t.id != id) t,
      task.copyWith(day: day),
    ]);
  }

  /// Unfinished tasks from days before [today] moved onto [today], in
  /// their order, as many as fit.
  Planner carryOver(String today) {
    var next = this;
    for (final t in tasks) {
      if (!t.done && t.day.compareTo(today) < 0) next = next.move(t.id, today);
    }
    return next;
  }

  /// How many unfinished tasks sit on days before [today].
  int leftBehind(String today) =>
      tasks.where((t) => !t.done && t.day.compareTo(today) < 0).length;

  /// Tasks on days more than [keepDays] before [today] dropped.
  Planner pruned(DateTime today) {
    final cutoff = dayKey(today.subtract(const Duration(days: keepDays)));
    return Planner([
      for (final t in tasks)
        if (t.day.compareTo(cutoff) >= 0) t,
    ]);
  }

  /// Done and planned across [days].
  ({int done, int total}) tally(Iterable<String> days) {
    final wanted = days.toSet();
    var done = 0, total = 0;
    for (final t in tasks) {
      if (!wanted.contains(t.day)) continue;
      total++;
      if (t.done) done++;
    }
    return (done: done, total: total);
  }

  List<Map<String, Object>> toJson() => [for (final t in tasks) t.toJson()];

  static Planner fromJson(Object? json) => json is List
      ? Planner([for (final e in json) ?PlannerTask.fromJson(e)])
      : empty;
}

/// [d]'s calendar day as `yyyy-mm-dd`.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The day a [dayKey] names, at midnight; null for anything else.
DateTime? parseDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return dayKey(d) == key ? d : null;
}

/// Monday to Sunday of the week holding [day]. Calendar arithmetic
/// (`DateTime(y, m, d + n)`), never adding 24 hours, which a daylight
/// saving change would turn into the wrong day.
List<DateTime> weekOf(DateTime day) {
  final monday = DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
  );
  return [
    for (var i = 0; i < 7; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}

/// Something "Plan my week" can put on a day.
typedef PlanIdea = ({String title, String subject, String path});

/// [ideas] spread over [days], one a day in turn, skipping a day that
/// already has [perDay] or more tasks, and leaving out an idea already
/// planned this week (same title and subject). [newId] names each task.
List<PlannerTask> spreadOverWeek({
  required Planner planner,
  required List<PlanIdea> ideas,
  required List<String> days,
  required String Function() newId,
  int perDay = 2,
  int minutes = 30,
}) {
  final load = {for (final d in days) d: planner.on(d).length};
  final planned = {
    for (final d in days)
      for (final t in planner.on(d)) '${t.subject}|${t.title}',
  };
  final out = <PlannerTask>[];
  var at = 0;
  for (final idea in ideas) {
    if (!planned.add('${idea.subject}|${idea.title}')) continue;
    String? day;
    for (var k = 0; k < days.length; k++) {
      final d = days[(at + k) % days.length];
      if (load[d]! < perDay) {
        day = d;
        at = (at + k + 1) % days.length;
        break;
      }
    }
    if (day == null) break;
    load[day] = load[day]! + 1;
    out.add(
      PlannerTask(
        id: newId(),
        day: day,
        title: idea.title,
        subject: idea.subject,
        path: idea.path,
        minutes: minutes,
      ),
    );
  }
  return out;
}
