import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/learn_resource.dart';

/// How many of a topic's own questions are saved for its exercises and
/// topic test. An exercise serves 5–10 and the test 10, drawn from the
/// bank by a rotating cursor; offline, those queries run against whatever
/// is cached, so 30 gives them room to vary without saving a whole bank.
const int kOfflineTopicQuestions = 30;

/// What saving a topic for offline has to fetch, worked out from its
/// published resources. Pure, so it is testable without Firestore.
class OfflinePlan {
  const OfflinePlan({
    required this.resourceCount,
    required this.assetIds,
    required this.questionIds,
    required this.videoCount,
    required this.externalImageCount,
  });

  final int resourceCount;

  /// `lessonAssets/{id}` referenced by figures, in first-seen order.
  final List<String> assetIds;

  /// Bank questions referenced by `::: check q:` / `::: waec q:` blocks
  /// and questions pinned to exercises, in first-seen order.
  final List<String> questionIds;

  /// Videos (resources and in-text): YouTube cannot be cached, so these
  /// need a connection whatever is saved.
  final int videoCount;

  /// Figures linked by `https://` URL rather than uploaded: the browser
  /// may cache them, but Paragon cannot promise it.
  final int externalImageCount;

  /// Roughly how many documents a save downloads — shown before saving in
  /// low-data mode.
  int get approximateItems =>
      resourceCount +
      assetIds.length +
      questionIds.length +
      kOfflineTopicQuestions;
}

/// Everything [resources] needs beyond themselves.
OfflinePlan planOfflinePrefetch(List<LearnResource> resources) {
  final assets = <String>{};
  final questions = <String>{};
  var videos = 0;
  var external = 0;

  for (final r in resources) {
    switch (r.type) {
      case LearnResourceType.video:
        videos++;
      case LearnResourceType.exercise:
        questions.addAll(r.questionIds.where((id) => id.trim().isNotEmpty));
      case LearnResourceType.article:
        for (final b in _walk(parseLessonDoc(r.body).blocks)) {
          switch (b) {
            case FigureBlock():
              final id = b.assetId;
              if (id != null && id.isNotEmpty) {
                assets.add(id);
              } else {
                external++;
              }
            case BankQuestionBlock(:final questionId):
              if (questionId.trim().isNotEmpty) questions.add(questionId.trim());
            case VideoBlock():
              videos++;
            default:
              break;
          }
        }
      case LearnResourceType.unknown:
        break;
    }
  }

  return OfflinePlan(
    resourceCount: resources.length,
    assetIds: assets.toList(),
    questionIds: questions.toList(),
    videoCount: videos,
    externalImageCount: external,
  );
}

/// Every block, nested ones included: a figure inside a callout or a bank
/// question inside a "go deeper" section still needs saving.
Iterable<LessonBlock> _walk(List<LessonBlock> blocks) sync* {
  for (final b in blocks) {
    yield b;
    switch (b) {
      case CalloutBlock(:final body):
      case MoreBlock(:final body):
      case UnknownBlock(:final body):
        yield* _walk(body);
      case ExampleBlock(:final problem, :final steps, :final answer):
        yield* _walk(problem);
        for (final s in steps) {
          yield* _walk(s.body);
        }
        if (answer != null) yield* _walk(answer);
      case TryItBlock(:final problem, :final hint, :final answer):
        yield* _walk(problem);
        if (hint != null) yield* _walk(hint);
        if (answer != null) yield* _walk(answer);
      case CheckBlock(:final question, :final why):
        yield* _walk(question);
        if (why != null) yield* _walk(why);
      default:
        break;
    }
  }
}
