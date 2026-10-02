import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/learn/lesson_progress.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/topic.dart';
import '../../core/repositories/learn_progress_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/repositories/learning_repository.dart';
import 'lesson_screen.dart' show lessonPath;

/// Where "Continue learning" goes: the topic the student most recently
/// finished something in, and the next thing to open there — or, when the
/// lesson is finished, its topic test.
class ContinueLearning {
  const ContinueLearning({
    required this.topic,
    required this.next,
    required this.done,
    required this.total,
  });

  final Topic topic;

  /// Null when every item in the topic is done.
  final LearnResource? next;
  final int done;
  final int total;

  bool get lessonFinished => next == null;

  String get path => next != null
      ? lessonPath(topic.id, next!.id)
      : '/subject/${topic.subjectId}/unit/${topic.unitId}'
            '/topic/${topic.id}/test';
}

/// Null until a student has completed at least one lesson item, and while
/// its topic is loading. Costs the topic document and that topic's
/// resource list (two reads), both cached for the lesson page it links to,
/// and shared by the dashboard card and the top bar's button.
final continueLearningProvider = Provider<ContinueLearning?>((ref) {
  final recent = ref.watch(lessonProgressProvider).mostRecent;
  if (recent == null) return null;
  final topic = ref.watch(topicByIdProvider(recent.topicId)).asData?.value;
  final resources = ref
      .watch(topicResourcesProvider(recent.topicId))
      .asData
      ?.value;
  if (topic == null || resources == null) return null;
  return ContinueLearning(
    topic: topic,
    next: continueTarget(resources, recent.progress.completed),
    done: completedCount(resources, recent.progress.completed),
    total: availableCount(resources),
  );
});
