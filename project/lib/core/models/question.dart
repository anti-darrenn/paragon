import 'package:cloud_firestore/cloud_firestore.dart';

import '../questions/difficulty.dart';
import 'firestore_parsing.dart';

class Question {
  final String id;
  final String topicId;
  final String subjectId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String source;
  final int? year;

  /// `ai_generated` on the procedurally generated corpus, empty on scraped
  /// past questions. What tells a student "Paragon practice" from a real
  /// past paper — see [provenanceLabel].
  final String origin;

  /// A published examiner insight exists for this question
  /// (`insights/{id}`), stamped by `jobs.js --job=insights` so the app only
  /// reads one when there is one.
  final bool hasInsight;

  /// A diagram the question depends on: a `lessonAssets` id, or null.
  /// Set on scraped past questions by `tools/scraper/10_fetch_question_images.js`.
  final String? imageId;

  /// A picture belonging to the worked answer, shown with the explanation.
  final String? explanationImageId;

  /// A reviewer's own difficulty level, 1–5, set in the studio; null on
  /// almost every question, whose [tier] is then estimated.
  final int? difficulty;

  /// Other topics this question also counts for (owner's decision,
  /// 2026-10-17). [topicId] stays the main one: counts, the static site's
  /// topic of record and mastery attribution follow it. Drill, topic tests
  /// and exercises for any of these topics can serve it too.
  final List<String> alsoTopicIds;

  /// Students' ratings so far, from `questions.crowdDifficulty` ({n, sum}),
  /// totted up nightly. Zero on a question nobody has rated.
  final int crowdVotes;
  final int crowdSum;

  /// The founder has checked this question (`questions.vetted`, 2026-10-17).
  /// Only vetted questions reach students; every student query filters on
  /// it, and anything loaded by id is dropped when it is false.
  final bool vetted;

  const Question({
    required this.id,
    required this.topicId,
    required this.subjectId,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.source,
    this.year,
    this.origin = '',
    this.hasInsight = false,
    this.imageId,
    this.explanationImageId,
    this.difficulty,
    this.alsoTopicIds = const [],
    this.crowdVotes = 0,
    this.crowdSum = 0,
    this.vetted = false,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Question(
      id: doc.id,
      topicId: asString(d['topicId']),
      subjectId: asString(d['subjectId']),
      text: asString(d['text']),
      options: asStringList(d['options']),
      // -1 means "no verified answer" and is what the app already treats as
      // unanswerable, so it is the right fallback for a missing or unusable
      // value rather than 0, which would silently mark option A correct.
      correctIndex: asIntOrNull(d['correctIndex']) ?? -1,
      explanation: asString(d['explanation']),
      source: asString(d['source'], fallback: 'drill'),
      year: asIntOrNull(d['year']),
      origin: asString(d['origin']),
      hasInsight: asBool(d['hasInsight']),
      imageId: asStringOrNull(d['imageId']),
      explanationImageId: asStringOrNull(d['explanationImageId']),
      difficulty: asIntOrNull(d['difficulty']),
      alsoTopicIds: asStringList(d['alsoTopicIds']),
      crowdVotes: _crowd(d, 'n'),
      crowdSum: _crowd(d, 'sum'),
    vetted: asBool(d['vetted']),
    );
  }

  /// How hard this question is: the reviewer's level when one is set,
  /// otherwise Paragon's estimate (`lib/core/questions/difficulty.dart`)
  /// moved by students' ratings, if enough of them agree (`blendTier`).
  DifficultyTier get tier =>
      DifficultyTier.fromLevel(difficulty) ??
      blendTier(
        estimateDifficulty(text, options, hasDiagram: imageId != null),
        votes: crowdVotes,
        sum: crowdSum,
      );

  /// Whether [tier] is a person's judgement rather than the estimate.
  bool get tierIsSet => DifficultyTier.fromLevel(difficulty) != null;

  /// Written by Paragon's generators, not taken from an exam paper.
  bool get isGenerated => origin == 'ai_generated';

  /// A question from a real exam paper. Generated questions are stamped
  /// `source: 'drill'`, but the origin is checked first so a generated
  /// question can never claim to be a past question.
  bool get isPastQuestion => !isGenerated && source == 'waec';

  /// What a student is told about where a question came from: "WAEC 2018",
  /// "WAEC past question" when the year is unknown, "Paragon practice" for
  /// generated ones, and null — no badge — for anything unclassified.
  /// Adding NECO or JAMB later is one case here.
  String? get provenanceLabel {
    if (isGenerated) return 'Paragon practice';
    if (isPastQuestion) {
      return year == null ? 'WAEC past question' : 'WAEC $year';
    }
    return null;
  }

  /// Everything needed to rebuild this question without Firestore — for an
  /// exam kept on the device so it can be resumed (`saved_exam.dart`).
  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'subjectId': subjectId,
    'text': text,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'source': source,
    'year': year,
    'origin': origin,
    'hasInsight': hasInsight,
    'imageId': imageId,
    'explanationImageId': explanationImageId,
    'difficulty': difficulty,
    'alsoTopicIds': alsoTopicIds,
    'crowdDifficulty': {'n': crowdVotes, 'sum': crowdSum},
    'vetted': vetted,
  };

  /// The inverse of [toJson], as forgiving as [Question.fromFirestore]:
  /// device storage can hold anything an older build wrote.
  factory Question.fromJson(Map<String, dynamic> d) => Question(
    id: asString(d['id']),
    topicId: asString(d['topicId']),
    subjectId: asString(d['subjectId']),
    text: asString(d['text']),
    options: asStringList(d['options']),
    correctIndex: asIntOrNull(d['correctIndex']) ?? -1,
    explanation: asString(d['explanation']),
    source: asString(d['source'], fallback: 'drill'),
    year: asIntOrNull(d['year']),
    origin: asString(d['origin']),
    hasInsight: asBool(d['hasInsight']),
    imageId: asStringOrNull(d['imageId']),
    explanationImageId: asStringOrNull(d['explanationImageId']),
    difficulty: asIntOrNull(d['difficulty']),
    alsoTopicIds: asStringList(d['alsoTopicIds']),
    crowdVotes: _crowd(d, 'n'),
    crowdSum: _crowd(d, 'sum'),
    vetted: asBool(d['vetted']),
  );
}

/// One field of `crowdDifficulty`, the students' ratings tally.
int _crowd(Map<String, dynamic> d, String key) {
  final c = d['crowdDifficulty'];
  return c is Map ? asInt(c[key]) : 0;
}
