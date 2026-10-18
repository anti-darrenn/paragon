import 'package:cloud_firestore/cloud_firestore.dart';

import '../content/question_counts.dart';
import 'firestore_parsing.dart';

class Topic {
  final String id;
  final String unitId;
  final String subjectId;
  final String name;
  final int questionCount;

  /// Past questions from real papers and Paragon's practice questions,
  /// answered and vetted (what students are served), from `jobs.js --job=counts`. Both
  /// zero means "not split yet" — see [QuestionCounts].
  final int pastQuestionCount;
  final int practiceQuestionCount;

  /// Answered questions waiting for the founder to vet them (2026-10-17),
  /// for the studio's question bank. Students never see them.
  final int pendingCount;
  final int order;

  /// Published, openable Learn items. Zero means "not known", never "no
  /// lessons" — the same convention as `subjects.topicCount` — so callers
  /// hide a count rather than draw "0 of 0".
  final int lessonCount;

  /// A published "Where students lose marks" exists (`insights/topic_<id>`),
  /// stamped by `jobs.js --job=insights`.
  final bool hasExaminerThemes;
  // Learn mode content. No seeded topic has these yet — always null/false
  // today, but null-safe so Learn mode doesn't need a schema migration
  // once notes get authored.
  final bool hasNotes;
  final String? notesMarkdown;

  const Topic({
    required this.id,
    required this.unitId,
    required this.subjectId,
    required this.name,
    required this.questionCount,
    required this.order,
    this.pastQuestionCount = 0,
    this.practiceQuestionCount = 0,
    this.pendingCount = 0,
    this.lessonCount = 0,
    this.hasExaminerThemes = false,
    this.hasNotes = false,
    this.notesMarkdown,
  });

  QuestionCounts get counts => QuestionCounts(
    past: pastQuestionCount,
    practice: practiceQuestionCount,
    total: questionCount,
  );

  factory Topic.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Topic(
      id: doc.id,
      unitId: asString(d['unitId']),
      subjectId: asString(d['subjectId']),
      name: asString(d['name']),
      questionCount: asInt(d['questionCount']),
      pastQuestionCount: asInt(d['pastQuestionCount']),
      practiceQuestionCount: asInt(d['practiceQuestionCount']),
      pendingCount: asInt(d['pendingCount']),
      order: asInt(d['order']),
      lessonCount: asInt(d['lessonCount']),
      hasExaminerThemes: asBool(d['hasExaminerThemes']),
      hasNotes: asBool(d['hasNotes']),
      notesMarkdown: d['notesMarkdown'] == null ? null : asString(d['notesMarkdown']),
    );
  }
}
