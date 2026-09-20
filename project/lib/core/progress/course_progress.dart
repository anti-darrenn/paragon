import '../repositories/course_repository.dart';
import '../repositories/progress_repository.dart';
import 'mastery.dart';

/// Joins a [Course] outline to a student's [UserProgress].
///
/// Extensions rather than fields on `Course`, because the outline is
/// shared, cached and identical for every student, and progress is not.
/// Keeping them apart means `courseProvider` stays a pure content read
/// that two students can share, and nothing has to be invalidated when one
/// of them finishes a drill.
///
/// **Placeholder topics count as nothing, not as zero.** A planned subject
/// has an outline but no Firestore documents and nothing to practise;
/// including its topics would paint a 0% ring on a course the student
/// could not have started even if they wanted to, which reads as failure
/// rather than as "not written yet". So they are excluded from the
/// denominator, and a course with no practisable topics reports no
/// progress at all — see [CourseMastery.hasProgressToShow].
extension TopicMastery on CourseTopic {
  MasteryLevel levelIn(UserProgress progress) =>
      isPlaceholder ? MasteryLevel.notStarted : progress.levelFor(id);
}

extension ModuleMastery on CourseModule {
  Iterable<MasteryLevel> levelsIn(UserProgress progress) => topics
      .where((topic) => !topic.isPlaceholder)
      .map((topic) => progress.levelFor(topic.id));

  /// One level for the whole module — the weakest of its topics, so the
  /// module's circle closes only when all of it has.
  MasteryLevel levelIn(UserProgress progress) =>
      aggregateLevel(levelsIn(progress));

  double masteryIn(UserProgress progress) =>
      masteryFraction(levelsIn(progress));

  int startedCountIn(UserProgress progress) =>
      levelsIn(progress).where((level) => level.isStarted).length;

  int get practisableTopicCount =>
      topics.where((topic) => !topic.isPlaceholder).length;
}

extension CourseMastery on Course {
  Iterable<MasteryLevel> levelsIn(UserProgress progress) =>
      modules.expand((module) => module.levelsIn(progress));

  double masteryIn(UserProgress progress) =>
      masteryFraction(levelsIn(progress));

  /// Topics the student has answered at least one question in.
  int startedCountIn(UserProgress progress) =>
      levelsIn(progress).where((level) => level.isStarted).length;

  /// Topics taken to proficient or above — the number worth celebrating,
  /// and the one the course heading reports.
  int completedCountIn(UserProgress progress) =>
      levelsIn(progress).where((level) => level.isComplete).length;

  int get practisableTopicCount =>
      modules.fold(0, (sum, module) => sum + module.practisableTopicCount);

  /// Whether to draw rings at all. False for a planned subject, where
  /// every ring would be an empty circle reporting a fact about content
  /// that does not exist rather than about the student.
  bool get hasProgressToShow => isLive && practisableTopicCount > 0;
}
