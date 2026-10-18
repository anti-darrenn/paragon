import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../models/question.dart';
import '../providers/auth_provider.dart';

/// A host's own quiz (owner's request, 2026-10-17): questions they write
/// themselves, in LaTeX or Normal mode, with diagrams, for their live
/// rooms. One `quizzes/{id}` document holds them all.
///
/// **They never enter the bank.** Students meet them only in a room the
/// author hosts; they are not vetted, counted, or published. Anyone signed
/// in may *get* a quiz by id (the players' phones need its questions); only
/// the author lists, edits or deletes theirs.
class QuizQuestion {
  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.imageId,
  });

  /// 2 to 5 options: a room answer is an index up to 4.
  static const minOptions = 2;
  static const maxOptions = 5;

  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  /// A diagram: `quiz:<quizAssets id>` (see `lessonAssetProvider`).
  final String? imageId;

  Map<String, Object> toMap() => {
    'text': text.trim(),
    'options': [for (final o in options) o.trim()],
    'correctIndex': correctIndex,
    'explanation': explanation.trim(),
    'imageId': ?imageId,
  };

  static QuizQuestion? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final options = asStringList(raw['options']);
    return QuizQuestion(
      text: asString(raw['text']),
      options: options,
      correctIndex: asInt(raw['correctIndex'], fallback: -1),
      explanation: asString(raw['explanation']),
      imageId: asStringOrNull(raw['imageId']),
    );
  }

  bool get isComplete =>
      text.trim().isNotEmpty &&
      options.length >= minOptions &&
      options.length <= maxOptions &&
      options.every((o) => o.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length;
}

class TeacherQuiz {
  const TeacherQuiz({
    required this.id,
    required this.title,
    this.subjectId,
    this.questions = const [],
    this.updatedAt,
  });

  static const maxQuestions = 50;

  final String id;
  final String title;
  final String? subjectId;
  final List<QuizQuestion> questions;
  final DateTime? updatedAt;

  List<QuizQuestion> get playable => [
    for (final q in questions)
      if (q.isComplete) q,
  ];

  Map<String, Object> toMap() => {
    'title': title.trim().isEmpty ? 'My quiz' : title.trim(),
    'subjectId': ?subjectId,
    'questions': [
      for (final q in questions.take(maxQuestions)) q.toMap(),
    ],
  };

  static TeacherQuiz fromMap(String id, Map<String, dynamic> d) {
    final at = d['updatedAt'];
    return TeacherQuiz(
      id: id,
      title: asString(d['title'], fallback: 'My quiz'),
      subjectId: asStringOrNull(d['subjectId']),
      questions: [
        for (final raw
            in (d['questions'] is List ? d['questions'] as List : const []))
          ?QuizQuestion.fromMap(raw),
      ],
      updatedAt: at is Timestamp ? at.toDate() : null,
    );
  }

  /// Question [i] as the room screens show it. Its id is the room item
  /// (`q:<i>`), its provenance "From your quiz host".
  Question asQuestion(int i) {
    final q = questions[i];
    return Question(
      id: 'q:$i',
      topicId: '',
      subjectId: subjectId ?? '',
      text: q.text,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
      source: 'teacher',
      origin: 'teacher',
      imageId: q.imageId,
      vetted: true,
    );
  }
}

class TeacherQuizRepository {
  TeacherQuizRepository([this._override]);

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _quizzes =>
      _db.collection('quizzes');

  Future<List<TeacherQuiz>> mine(String uid) async {
    final snap = await _quizzes
        .where('userId', isEqualTo: uid)
        .limit(100)
        .get()
        .metered();
    return [for (final d in snap.docs) TeacherQuiz.fromMap(d.id, d.data())]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );
  }

  Future<TeacherQuiz?> get(String id) async {
    final snap = await _quizzes.doc(id).get().metered();
    final d = snap.data();
    return d == null ? null : TeacherQuiz.fromMap(snap.id, d);
  }

  /// Saves [quiz]; a new one ([TeacherQuiz.id] empty) gets an id. Returns
  /// the id.
  Future<String> save(String uid, TeacherQuiz quiz) async {
    final ref = quiz.id.isEmpty ? _quizzes.doc() : _quizzes.doc(quiz.id);
    await ref.set({
      'userId': uid,
      ...quiz.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> delete(String id) => _quizzes.doc(id).delete();
}

final teacherQuizRepositoryProvider = Provider<TeacherQuizRepository>(
  (ref) => TeacherQuizRepository(),
);

/// The signed-in host's quizzes, newest first.
final myQuizzesProvider = FutureProvider.autoDispose<List<TeacherQuiz>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isAnonymous) return const [];
  return ref.read(teacherQuizRepositoryProvider).mine(user.uid);
});

/// One quiz by id: the editor, and every phone in a room that uses it.
final teacherQuizProvider = FutureProvider.family<TeacherQuiz?, String>(
  (ref, id) => ref.read(teacherQuizRepositoryProvider).get(id),
);
