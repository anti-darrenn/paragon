/// A question as the studio edits it, and the checks it must pass before
/// saving. No Firestore and no widgets, so it is tested on its own
/// (`question_draft_test.dart`); maths is checked with flutter_math_fork's
/// own parser, as `lesson_check.dart` does.
///
/// The fields are exactly the ones `firestore.rules` lets a reviewer
/// change (`editsQuestion`): stem, options, answer, explanation and
/// whether students see it. Subject, topic, source, year and origin stay
/// seeder-only.
library;

import 'package:flutter_math_fork/tex.dart';

import '../latex/tex_preprocess.dart';

/// The fields a studio edit can touch.
class QuestionDraft {
  const QuestionDraft({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.hasAnswer,
    this.difficulty,
    this.alsoTopicIds = const [],
  });

  final String text;
  final List<String> options;

  /// 0-based; -1 is "no verified answer", the corpus's own convention.
  final int correctIndex;
  final String explanation;

  /// False keeps the question out of drill, WAEC, tests and exercises.
  final bool hasAnswer;

  /// A reviewer's difficulty level, 1–5; null leaves it to the estimate
  /// (`difficulty.dart`).
  final int? difficulty;

  /// Other topics it also counts for (never its own, at most
  /// [maxAlsoTopics]); empty for almost every question.
  final List<String> alsoTopicIds;

  static const maxAlsoTopics = 5;

  /// The most options the rules accept (WAEC papers use four or five).
  static const maxOptions = 6;
  static const minOptions = 2;

  QuestionDraft copyWith({
    String? text,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    bool? hasAnswer,
    int? Function()? difficulty,
    List<String>? alsoTopicIds,
  }) => QuestionDraft(
    text: text ?? this.text,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    explanation: explanation ?? this.explanation,
    hasAnswer: hasAnswer ?? this.hasAnswer,
    difficulty: difficulty != null ? difficulty() : this.difficulty,
    alsoTopicIds: alsoTopicIds ?? this.alsoTopicIds,
  );

  /// Removes option [i], keeping the marked answer on the same option (or
  /// clearing it, if that was the one removed).
  QuestionDraft withoutOption(int i) {
    final next = [...options]..removeAt(i);
    final answer = correctIndex == i
        ? -1
        : correctIndex > i
        ? correctIndex - 1
        : correctIndex;
    return copyWith(options: next, correctIndex: answer);
  }

  /// What is stored: trimmed, as the rules check it.
  Map<String, Object> toMap() => {
    'text': text.trim(),
    'options': [for (final o in options) o.trim()],
    'correctIndex': correctIndex,
    'explanation': explanation.trim(),
    'hasAnswer': hasAnswer,
    'difficulty': ?difficulty,
    if (alsoTopicIds.isNotEmpty) 'alsoTopicIds': [...alsoTopicIds],
  };

  /// Field names whose stored value differs from [other]'s.
  Set<String> changedFrom(QuestionDraft other) {
    final a = toMap();
    final b = other.toMap();
    return {
      for (final k in a.keys)
        if ('${a[k]}' != '${b[k]}') k,
    };
  }

  static QuestionDraft fromMap(Map<String, dynamic> d) => QuestionDraft(
    text: '${d['text'] ?? ''}',
    options: [
      for (final o in (d['options'] is List ? d['options'] as List : const []))
        '$o',
    ],
    correctIndex: d['correctIndex'] is int ? d['correctIndex'] as int : -1,
    explanation: '${d['explanation'] ?? ''}',
    hasAnswer: d['hasAnswer'] == true,
    difficulty:
        d['difficulty'] is int &&
            (d['difficulty'] as int) >= 1 &&
            (d['difficulty'] as int) <= 5
        ? d['difficulty'] as int
        : null,
    alsoTopicIds: [
      for (final t
          in (d['alsoTopicIds'] is List ? d['alsoTopicIds'] as List : const []))
        '$t',
    ],
  );
}

/// How bad a problem is: [block] stops the save (the rules would refuse
/// it, or a student would be marked wrong for a right answer); [warn] is
/// worth a look but saves.
enum DraftLevel { block, warn }

class DraftIssue {
  const DraftIssue(this.level, this.message, {this.field, this.index});
  final DraftLevel level;
  final String message;

  /// `text`, `options` or `explanation`, and the option's index, so the
  /// editor can put the message beside the box it is about.
  final String? field;
  final int? index;

  bool get blocks => level == DraftLevel.block;
}

/// Maths the app's renderer reads: `\(…\)`, `\[…\]`, `$$…$$`. An opening
/// with no close shows as raw text to students.
int _unclosed(String s) {
  var open = 0;
  for (final pair in const [(r'\(', r'\)'), (r'\[', r'\]')]) {
    open += pair.$1.allMatches(s).length - pair.$2.allMatches(s).length;
  }
  return open;
}

String _normal(String s) => s.replaceAll(RegExp(r'\s+|\$'), '').toLowerCase();

final _mathSpan = RegExp(
  r'\\\((.*?)\\\)|\\\[(.*?)\\\]|\$\$(.*?)\$\$',
  dotAll: true,
);

/// The first maths in [value] that the renderer cannot draw, shortened for
/// a message, or null when all of it renders.
String? unrenderableMath(String value) {
  if (!value.contains(r'\') && !value.contains(r'$$')) return null;
  for (final m in _mathSpan.allMatches(normalizeTex(value))) {
    final tex = m.group(1) ?? m.group(2) ?? m.group(3)!;
    try {
      TexParser(tex, const TexParserSettings()).parse();
    } catch (_) {
      return tex.length > 40 ? '${tex.substring(0, 37)}...' : tex;
    }
  }
  return null;
}

/// Everything wrong with [d], most serious first. Mirrors the checks in
/// `tools/admin/question_rules.js` that can be made while typing.
List<DraftIssue> checkDraft(QuestionDraft d) {
  final out = <DraftIssue>[];
  void add(DraftLevel l, String m, {String? field, int? index}) =>
      out.add(DraftIssue(l, m, field: field, index: index));

  if (d.text.trim().isEmpty) {
    add(DraftLevel.block, 'The question is empty.', field: 'text');
  } else if (d.text.length > 5000) {
    add(
      DraftLevel.block,
      'The question is over 5,000 characters.',
      field: 'text',
    );
  }
  if (d.options.length < QuestionDraft.minOptions ||
      d.options.length > QuestionDraft.maxOptions) {
    add(
      DraftLevel.block,
      'A question needs ${QuestionDraft.minOptions} to '
      '${QuestionDraft.maxOptions} options.',
      field: 'options',
    );
  }
  for (var i = 0; i < d.options.length; i++) {
    if (d.options[i].trim().isEmpty) {
      add(
        DraftLevel.block,
        'Option ${_letter(i)} is empty.',
        field: 'options',
        index: i,
      );
    }
  }
  final seen = <String, int>{};
  for (var i = 0; i < d.options.length; i++) {
    final k = _normal(d.options[i]);
    if (k.isEmpty) continue;
    final first = seen[k];
    if (first != null) {
      add(
        DraftLevel.block,
        'Options ${_letter(first)} and ${_letter(i)} are the same.',
        field: 'options',
        index: i,
      );
    } else {
      seen[k] = i;
    }
  }
  if (d.hasAnswer && d.correctIndex < 0) {
    add(
      DraftLevel.block,
      'Mark the right answer, or hide the question from students.',
      field: 'options',
    );
  }
  if (d.correctIndex >= d.options.length) {
    add(
      DraftLevel.block,
      'The marked answer is not one of the options.',
      field: 'options',
    );
  }
  if (d.explanation.length > 20000) {
    add(
      DraftLevel.block,
      'The explanation is over 20,000 characters.',
      field: 'explanation',
    );
  }

  for (final (field, value) in [
    ('text', d.text),
    ('explanation', d.explanation),
  ]) {
    if (_unclosed(value) != 0) {
      add(
        DraftLevel.warn,
        r'Maths opened with \( or \[ is not closed (or closed twice).',
        field: field,
      );
    }
  }
  for (var i = 0; i < d.options.length; i++) {
    if (_unclosed(d.options[i]) != 0) {
      add(
        DraftLevel.warn,
        r'Option '
        '${_letter(i)}'
        r' has unbalanced \( \).',
        field: 'options',
        index: i,
      );
    }
  }
  // Maths that will not render shows students red source. Checked the way
  // the renderer reads it: through normalizeTex, then the real parser.
  for (final (field, index, value) in [
    ('text', null, d.text),
    ('explanation', null, d.explanation),
    for (var i = 0; i < d.options.length; i++) ('options', i, d.options[i]),
  ]) {
    final bad = unrenderableMath(value);
    if (bad != null) {
      final where = index == null ? '' : 'Option ${_letter(index)}: ';
      add(
        DraftLevel.block,
        '${where}this maths won\'t render: $bad',
        field: field,
        index: index,
      );
    }
  }
  if (RegExp(r'^\s*Expression(?=\s+(?:-?\d|\\\(|\.\d))').hasMatch(d.text)) {
    add(
      DraftLevel.warn,
      '"Expression" at the start probably means "Express".',
      field: 'text',
    );
  }
  // ASCII maths outside \( \): 2^(x+1), √(2x), 32_four.
  final outside = d.text.replaceAll(
    RegExp(r'\\\(.*?\\\)|\\\[.*?\\\]', dotAll: true),
    ' ',
  );
  if (RegExp(
    r'\S\^\s*[({\d-]|√\s*\(|\b\d+_[a-z0-9]+\b',
    caseSensitive: false,
  ).hasMatch(outside)) {
    add(
      DraftLevel.warn,
      r'Maths typed as plain text; wrap it in \( \).',
      field: 'text',
    );
  }
  if (d.explanation.trim().isEmpty) {
    add(
      DraftLevel.warn,
      'No explanation: students see only the answer.',
      field: 'explanation',
    );
  }
  out.sort((a, b) => a.level.index.compareTo(b.level.index));
  return out;
}

const _letters = 'ABCDEF';
String _letter(int i) => i >= 0 && i < _letters.length ? _letters[i] : '#$i';

/// Letter for option [i], as students see it.
String optionLetter(int i) => _letter(i);
