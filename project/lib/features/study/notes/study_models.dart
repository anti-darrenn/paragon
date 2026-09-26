import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/firestore_parsing.dart';
import '../../../core/theme/app_colors.dart';

/// Highlights, notes and bookmarks — the data, with no Flutter widgets and
/// no storage, so the rules that matter (what counts as detached, what a
/// snapshot holds) are testable on their own.

/// The longest note a student can write. `firestore.rules` should enforce
/// the same number, so the two never disagree about what saves.
const kMaxNoteLength = 2000;

/// The most of a block's source kept with a note. Enough to recognise the
/// paragraph a note was written against once that paragraph is edited
/// away; not a copy of the lesson.
const kMaxSnapshotLength = 1000;

/// A highlight colour. Stored by [name], so the palette can be retuned in
/// `AppColors` without rewriting anyone's notes. A name this build does
/// not know parses as null — the note keeps its text and simply shows no
/// highlight, rather than failing to load.
enum HighlightColour {
  yellow(AppColors.warning),
  green(AppColors.correct),
  blue(AppColors.accentBlue),
  purple(AppColors.secondary);

  const HighlightColour(this.colour);

  /// The bar and swatch colour.
  final Color colour;

  /// The soft background drawn behind a highlighted block.
  Color get fill => colour.withAlpha(0x26);

  String get label => switch (this) {
    HighlightColour.yellow => 'Yellow',
    HighlightColour.green => 'Green',
    HighlightColour.blue => 'Blue',
    HighlightColour.purple => 'Purple',
  };

  static HighlightColour? tryParse(dynamic value) {
    for (final c in values) {
      if (c.name == value) return c;
    }
    return null;
  }
}

/// The source text kept with a note: trimmed, and capped at
/// [kMaxSnapshotLength].
String blockSnapshot(LessonBlock block) {
  final s = block.source.trim();
  return s.length <= kMaxSnapshotLength ? s : s.substring(0, kMaxSnapshotLength);
}

DateTime? _asDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

/// A highlight, a note, or both, on one top-level block of one lesson.
///
/// One per block: highlighting a block that already has a note updates the
/// same record. A record with neither a colour nor text is deleted rather
/// than kept empty.
class LessonNote {
  const LessonNote({
    required this.id,
    required this.topicId,
    required this.resourceId,
    required this.subjectId,
    required this.blockKey,
    required this.colour,
    required this.text,
    required this.snapshot,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String topicId;
  final String resourceId;
  final String subjectId;

  /// [LessonBlock.key] of the block this was written against. Changes when
  /// the block's wording changes — see [partitionNotes].
  final String blockKey;

  final HighlightColour? colour;

  /// Empty for a highlight with no note.
  final String text;

  /// The block's source when the note was last saved.
  final String snapshot;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasText => text.trim().isNotEmpty;
  bool get isEmpty => colour == null && !hasText;

  LessonNote copyWith({
    String? id,
    HighlightColour? colour,
    bool clearColour = false,
    String? text,
    String? snapshot,
    DateTime? updatedAt,
  }) => LessonNote(
    id: id ?? this.id,
    topicId: topicId,
    resourceId: resourceId,
    subjectId: subjectId,
    blockKey: blockKey,
    colour: clearColour ? null : (colour ?? this.colour),
    text: text ?? this.text,
    snapshot: snapshot ?? this.snapshot,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory LessonNote.fromFirestore(DocumentSnapshot doc) =>
      LessonNote.fromMap(doc.id, docData(doc));

  /// Null-safe over both Firestore data and the guest's local JSON.
  factory LessonNote.fromMap(String id, Map<String, dynamic> d) => LessonNote(
    id: id,
    topicId: asString(d['topicId']),
    resourceId: asString(d['resourceId']),
    subjectId: asString(d['subjectId']),
    blockKey: asString(d['blockKey']),
    colour: HighlightColour.tryParse(d['colour']),
    text: asString(d['text']),
    snapshot: asString(d['snapshot']),
    createdAt: _asDate(d['createdAt']),
    updatedAt: _asDate(d['updatedAt']),
  );

  /// The guest's local form. Dates as epoch milliseconds.
  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'resourceId': resourceId,
    'subjectId': subjectId,
    'blockKey': blockKey,
    'colour': colour?.name,
    'text': text,
    'snapshot': snapshot,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };
}

/// A lesson's notes split by whether their block still exists.
class PartitionedNotes {
  const PartitionedNotes(this.attached, this.detached);

  /// On a block in the current article.
  final List<LessonNote> attached;

  /// Written against wording the lesson no longer has. Shown under "From
  /// an earlier version of this lesson" with their snapshot — never
  /// dropped, and never guessed back onto a similar block.
  final List<LessonNote> detached;
}

/// Splits [notes] into those whose block is in [doc] and those whose block
/// is not. Order within each list follows [notes].
PartitionedNotes partitionNotes(List<LessonNote> notes, LessonDoc doc) {
  final keys = {for (final b in doc.blocks) b.key};
  return PartitionedNotes(
    [for (final n in notes) if (keys.contains(n.blockKey)) n],
    [for (final n in notes) if (!keys.contains(n.blockKey)) n],
  );
}

enum BookmarkKind {
  lesson,
  question;

  static BookmarkKind? tryParse(dynamic v) => switch (v) {
    'lesson' => BookmarkKind.lesson,
    'question' => BookmarkKind.question,
    _ => null,
  };
}

/// A saved lesson item or question. Lives in `study/{uid}.bookmarks`,
/// keyed by [key].
class Bookmark {
  const Bookmark({
    required this.kind,
    required this.topicId,
    required this.title,
    this.resourceId,
    this.questionId,
    this.subjectId,
    this.savedAt,
  });

  final BookmarkKind kind;
  final String topicId;
  final String? resourceId;
  final String? questionId;
  final String? subjectId;

  /// What the Saved page lists it as: the lesson title, or the start of
  /// the question.
  final String title;
  final DateTime? savedAt;

  /// Resource ids are slugs, unique only within a topic, so a lesson's key
  /// carries its topic. Question ids are global auto-ids.
  static String lessonKey(String topicId, String resourceId) =>
      'lesson:$topicId:$resourceId';
  static String questionKey(String questionId) => 'question:$questionId';

  String get key => kind == BookmarkKind.lesson
      ? lessonKey(topicId, resourceId ?? '')
      : questionKey(questionId ?? '');

  /// A question's stem as a one-line title: the inline-maths delimiters
  /// dropped (a truncated `\(` would render as a parse error) and cut to a
  /// length a list row can hold.
  static String questionTitle(String text) {
    final flat = text
        .replaceAll(RegExp(r'\\[()\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return flat.length <= 120 ? flat : '${flat.substring(0, 117)}...';
  }

  /// Null for an entry this build cannot use (unknown kind, or missing the
  /// id it would open) — skipped rather than shown as a dead row.
  static Bookmark? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final d = raw.map((k, v) => MapEntry('$k', v));
    final kind = BookmarkKind.tryParse(d['kind']);
    if (kind == null) return null;
    final b = Bookmark(
      kind: kind,
      topicId: asString(d['topicId']),
      resourceId: asStringOrNull(d['resourceId']),
      questionId: asStringOrNull(d['questionId']),
      subjectId: asStringOrNull(d['subjectId']),
      title: asString(d['title']),
      savedAt: _asDate(d['savedAt']),
    );
    final id = kind == BookmarkKind.lesson ? b.resourceId : b.questionId;
    if (id == null || id.isEmpty) return null;
    return b;
  }

  /// Parses the whole `bookmarks` map, dropping unusable entries.
  static Map<String, Bookmark> mapFrom(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, Bookmark>{};
    raw.forEach((k, v) {
      final b = fromMap(v);
      if (b != null) out['$k'] = b;
    });
    return out;
  }

  /// The stored fields, minus `savedAt`, which each store stamps itself.
  Map<String, dynamic> toFields() => {
    'kind': kind.name,
    'topicId': topicId,
    if (resourceId != null) 'resourceId': resourceId,
    if (questionId != null) 'questionId': questionId,
    if (subjectId != null) 'subjectId': subjectId,
    'title': title,
  };

  Map<String, dynamic> toJson() => {
    ...toFields(),
    'savedAt': savedAt?.millisecondsSinceEpoch,
  };

  Bookmark withSavedAt(DateTime at) => Bookmark(
    kind: kind,
    topicId: topicId,
    title: title,
    resourceId: resourceId,
    questionId: questionId,
    subjectId: subjectId,
    savedAt: at,
  );
}
