import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/repositories/course_repository.dart';
import '../core/widgets/load_error.dart';
import 'not_found_screen.dart';

/// Readable URLs (audit C9): `/waec/mathematics/setup` and
/// `/subject/mathematics/course/topic/indices/drill` name things by slug,
/// while the screens behind them work in Firestore ids. These resolve one
/// to the other from data already cached (the subject list, the course
/// outline), so a readable URL costs no extra reads. Ids are still
/// accepted everywhere, so links made before keep working.

/// Builds [builder] with the subject id that [subjectKey] (an id or a
/// slug) names.
class SubjectKeyRoute extends ConsumerWidget {
  const SubjectKeyRoute({
    super.key,
    required this.subjectKey,
    required this.builder,
  });

  final String subjectKey;
  final Widget Function(String subjectId) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(subjectIdForKeyProvider(subjectKey))
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: LoadError(
              error: e,
              onRetry: () =>
                  ref.invalidate(subjectIdForKeyProvider(subjectKey)),
            ),
          ),
          data: (id) => id == null ? const NotFoundScreen() : builder(id),
        );
  }
}

/// Builds [builder] with the course, module and topic that [subjectKey]
/// and [topicKey] name. A planned (placeholder) topic has nothing to
/// practise, so it reads as not found.
class CourseTopicRoute extends ConsumerWidget {
  const CourseTopicRoute({
    super.key,
    required this.subjectKey,
    required this.topicKey,
    required this.builder,
  });

  final String subjectKey;
  final String topicKey;
  final Widget Function(Course course, CourseModule module, CourseTopic topic)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(courseProvider(subjectKey))
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => e is CourseNotFoundException
              ? const NotFoundScreen()
              : Scaffold(
                  body: LoadError(
                    error: e,
                    onRetry: () => ref.invalidate(courseProvider(subjectKey)),
                  ),
                ),
          data: (course) {
            final found = course.findTopic(topicKey);
            if (found == null ||
                found.$2.isPlaceholder ||
                course.subjectId == null) {
              return const NotFoundScreen();
            }
            return builder(course, found.$1, found.$2);
          },
        );
  }
}
