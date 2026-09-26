import '../../../core/lessons/lesson_doc.dart';
import '../../../core/widgets/article_view.dart' show ArticleBlockKind;
import 'speech_text.dart';

/// One utterance: the text to speak, and the top-level block it belongs to
/// (so the article can mark that block while it is read).
class SpeechSegment {
  const SpeechSegment(this.blockKey, this.text);

  final String blockKey;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is SpeechSegment &&
      other.blockKey == blockKey &&
      other.text == text;

  @override
  int get hashCode => Object.hash(blockKey, text);

  @override
  String toString() => 'SpeechSegment($blockKey, "$text")';
}

/// A lesson as an ordered list of things to say.
///
/// Reads what a student sees on first opening the lesson, in order:
/// headings, paragraphs, list items one by one, callouts with their label
/// ("Definition: …", "Common mistake: …"), a worked example's problem,
/// steps and answer, tables row by row, figure captions.
///
/// **Deliberately silent** on author to-dos (never shown to students),
/// videos (nothing to read), and anything a student is meant to work out
/// first: the hidden answer and hint of a try-it, the marked answer and
/// explanation of a quick check, the back of a revision card. A read-aloud
/// that recites the answer after the question is a read-aloud that gives
/// the game away. Quick checks drawn from the bank are skipped too — their
/// text is loaded separately and is not in the lesson body.
List<SpeechSegment> lessonSpeechSegments(LessonDoc doc) {
  final out = <SpeechSegment>[];
  for (final block in doc.blocks) {
    _speakBlock(block, block.key, out);
  }
  return out;
}

void _add(List<SpeechSegment> out, String key, String text) {
  final spoken = speakText(text);
  if (spoken.isNotEmpty) out.add(SpeechSegment(key, spoken));
}

/// "Label: title." — with the full stop only when there is a title.
String _labelled(String label, String title) =>
    title.trim().isEmpty ? '$label.' : '$label: ${title.trim()}.';

void _speakBody(List<LessonBlock> body, String key, List<SpeechSegment> out) {
  for (final b in body) {
    _speakBlock(b, key, out);
  }
}

void _speakBlock(LessonBlock block, String key, List<SpeechSegment> out) {
  switch (block) {
    case BasicBlock(:final block):
      switch (block.kind) {
        case ArticleBlockKind.rule:
          return;
        case ArticleBlockKind.bullets:
        case ArticleBlockKind.numbers:
          for (final item in block.lines) {
            _add(out, key, item);
          }
        default:
          _add(out, key, block.lines.join(' '));
      }
    case CalloutBlock(:final kind, :final title, :final body):
      _add(out, key, _labelled(kind.label, title));
      _speakBody(body, key, out);
    case ExampleBlock(:final title, :final problem, :final steps, :final answer):
      _add(out, key, _labelled('Worked example', title));
      _speakBody(problem, key, out);
      for (var i = 0; i < steps.length; i++) {
        _add(out, key, _labelled('Step ${i + 1}', steps[i].title));
        _speakBody(steps[i].body, key, out);
      }
      if (answer != null) {
        _add(out, key, 'Answer.');
        _speakBody(answer, key, out);
      }
    case TryItBlock(:final title, :final problem):
      // The hint and the answer are hidden until asked for: not read.
      _add(out, key, _labelled('Try it', title));
      _speakBody(problem, key, out);
    case CheckBlock(:final question, :final options):
      // The options are read; which one is right, and why, are not.
      _add(out, key, 'Quick check.');
      _speakBody(question, key, out);
      for (var i = 0; i < options.length; i++) {
        final letter = String.fromCharCode(65 + i);
        _add(out, key, 'Option $letter: ${options[i].text}');
      }
    case CardBlock(:final front):
      // The back of a card is its answer.
      _add(out, key, _labelled('Revision card', front));
    case FigureBlock(:final caption):
      if (caption.trim().isNotEmpty) _add(out, key, 'Figure: $caption');
    case TableBlock(:final header, :final rows):
      final named = [
        for (var c = 0; c < header.length; c++)
          header[c].trim().isEmpty ? 'column ${c + 1}' : header[c].trim(),
      ];
      if (named.isNotEmpty) {
        _add(out, key, 'Table with columns: ${named.join(', ')}.');
      }
      for (var r = 0; r < rows.length; r++) {
        final cells = [
          for (var c = 0; c < rows[r].length; c++)
            if (rows[r][c].trim().isNotEmpty)
              c < named.length
                  ? '${named[c]}: ${rows[r][c].trim()}'
                  : rows[r][c].trim(),
        ];
        if (cells.isNotEmpty) {
          _add(out, key, 'Row ${r + 1}. ${cells.join('; ')}.');
        }
      }
    case MoreBlock(:final title, :final body):
      _add(out, key, _labelled('Go deeper', title));
      _speakBody(body, key, out);
    case UnknownBlock(:final body):
      _speakBody(body, key, out);
    case BankQuestionBlock():
    case VideoBlock():
    case TodoBlock():
      return;
  }
}
