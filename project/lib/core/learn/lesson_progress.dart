import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/learn_resource.dart';

/// Which Learn items a student has finished, read from `learn/{uid}`.
///
/// Lives in the same document as topic-test results, under each topic's
/// entry: `topics.<topicId>.completed.<resourceId>: true`, with
/// `lastCompletedId` / `lastCompletedAt` beside it for "continue learning".
/// Like a test pass it is not recomputable from `attempts` (reading an
/// article or watching a video writes no attempt), which is why it is here
/// and not in `progress/{uid}`.
///
/// Parsing never throws — see `firestore_parsing.dart` for why.
class TopicLessonProgress {
  const TopicLessonProgress({
    this.completed = const {},
    this.subjectId = '',
    this.lastCompletedId,
    this.lastCompletedAt,
  });

  final Set<String> completed;
  final String subjectId;
  final String? lastCompletedId;
  final DateTime? lastCompletedAt;

  static const none = TopicLessonProgress();

  static TopicLessonProgress fromMap(Object? raw) {
    if (raw is! Map) return none;
    final done = raw['completed'];
    return TopicLessonProgress(
      completed: done is Map
          ? {
              for (final e in done.entries)
                if (asBool(e.value)) e.key.toString(),
            }
          : const {},
      subjectId: asString(raw['subjectId']),
      lastCompletedId: asStringOrNull(raw['lastCompletedId']),
      lastCompletedAt: _asDate(raw['lastCompletedAt']),
    );
  }

  TopicLessonProgress withCompleted(String resourceId, {String? subjectId}) {
    return TopicLessonProgress(
      completed: {...completed, resourceId},
      subjectId: subjectId ?? this.subjectId,
      lastCompletedId: resourceId,
      lastCompletedAt: DateTime.now(),
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class LessonProgress {
  const LessonProgress(this._topics);

  final Map<String, TopicLessonProgress> _topics;

  static const empty = LessonProgress({});

  static LessonProgress fromDocument(Map<String, dynamic>? data) {
    final topics = data?['topics'];
    if (topics is! Map) return empty;
    return LessonProgress({
      for (final e in topics.entries)
        e.key.toString(): TopicLessonProgress.fromMap(e.value),
    });
  }

  TopicLessonProgress forTopic(String topicId) =>
      _topics[topicId] ?? TopicLessonProgress.none;

  bool isComplete(String topicId, String resourceId) =>
      forTopic(topicId).completed.contains(resourceId);

  LessonProgress withCompleted(
    String topicId,
    String resourceId, {
    String? subjectId,
  }) {
    return LessonProgress({
      ..._topics,
      topicId: forTopic(topicId).withCompleted(resourceId, subjectId: subjectId),
    });
  }

  /// The topic finished into most recently — the dashboard's "continue
  /// learning" card. Null when nothing has ever been completed.
  ({String topicId, TopicLessonProgress progress})? get mostRecent {
    ({String topicId, TopicLessonProgress progress})? best;
    for (final e in _topics.entries) {
      final at = e.value.lastCompletedAt;
      if (at == null) continue;
      final bestAt = best?.progress.lastCompletedAt;
      if (bestAt == null || at.isAfter(bestAt)) {
        best = (topicId: e.key, progress: e.value);
      }
    }
    return best;
  }
}

// ─── Walking a topic's sequence ──────────────────────────────────────────
//
// "Available" is `LearnResource.isAvailable`: a video with no id or an
// article with no body is listed but cannot be opened, so it is never a
// place to send a student and never counts toward "x of y".

/// The first available item not yet completed. Null when every available
/// item is done (or there are none).
LearnResource? continueTarget(
  List<LearnResource> resources,
  Set<String> completed,
) {
  for (final r in resources) {
    if (r.isAvailable && !completed.contains(r.id)) return r;
  }
  return null;
}

/// The next available item after [currentId], or null at the end.
LearnResource? nextAfter(List<LearnResource> resources, String currentId) {
  final index = resources.indexWhere((r) => r.id == currentId);
  if (index < 0) return null;
  for (final r in resources.skip(index + 1)) {
    if (r.isAvailable) return r;
  }
  return null;
}

/// How many available items are completed — never more than exist, so a
/// completion for an item since unpublished cannot read as "7 of 6".
int completedCount(List<LearnResource> resources, Set<String> completed) =>
    resources.where((r) => r.isAvailable && completed.contains(r.id)).length;

int availableCount(List<LearnResource> resources) =>
    resources.where((r) => r.isAvailable).length;
