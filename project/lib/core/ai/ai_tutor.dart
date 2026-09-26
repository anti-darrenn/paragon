import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lessons/lesson_doc.dart';
import '../models/learn_resource.dart';

/// The hook for a future AI tutor ("I don't understand step 3").
///
/// **Not built, deliberately** (decided 2026-09-26). A tutor costs money on
/// every question and needs a server — the Spark plan has no Cloud
/// Functions, and an API key can never ship inside the app — plus
/// per-student limits and safety rules suitable for minors. Until then the
/// app shows "Ask about this" greyed out as *Coming soon*, and nothing is
/// sent anywhere.
///
/// What exists is the seam: [LessonContext] (what the student is looking
/// at) and [AiTutor]. A backend means implementing [AiTutor] and returning
/// it from [aiTutorProvider]; the lesson UI already asks it
/// [AiTutor.isAvailable] and needs no other change.
abstract class AiTutor {
  const AiTutor();

  bool get isAvailable;

  /// Answers [question] about [context]. Never called while
  /// [isAvailable] is false.
  Future<String> ask(LessonContext context, String question);
}

class UnavailableAiTutor extends AiTutor {
  const UnavailableAiTutor();

  @override
  bool get isAvailable => false;

  @override
  Future<String> ask(LessonContext context, String question) =>
      throw UnsupportedError('The AI tutor is not available yet.');
}

/// What the student is looking at when they ask.
class LessonContext {
  const LessonContext({
    required this.topicId,
    required this.resourceId,
    required this.title,
    required this.text,
    this.blockKey,
  });

  final String topicId;
  final String resourceId;
  final String title;

  /// The lesson-format source of the block asked about, or the whole
  /// article when no block was chosen.
  final String text;
  final String? blockKey;
}

/// Builds the context for [resource], narrowed to one block when
/// [blockKey] names one that still exists.
LessonContext lessonContextFor(LearnResource resource, {String? blockKey}) {
  var text = resource.body;
  if (blockKey != null) {
    for (final b in parseLessonDoc(resource.body).blocks) {
      if (b.key == blockKey) {
        text = b.source;
        break;
      }
    }
  }
  return LessonContext(
    topicId: resource.topicId,
    resourceId: resource.id,
    title: resource.title,
    text: text,
    blockKey: blockKey,
  );
}

final aiTutorProvider = Provider<AiTutor>((ref) => const UnavailableAiTutor());
