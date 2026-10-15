import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';

/// Paper 2 (theory) practice, self-marked against the marking scheme
/// (PLAN.md P7.4): the student works on paper, then reveals the scheme a
/// step at a time and ticks what they got. No AI marking.
///
/// `theoryQuestions/{id}`: `{subjectId, examYear, number, parts: [{label,
/// prompt, marks, scheme: [{description, marks}]}], source, status}`.
/// Written by the Admin SDK (the import script) for now; students read
/// only `published`. **Hidden** until a subject has
/// [kTheoryMinQuestions] published (`subjects.theoryCount`, kept by
/// `jobs.js --job=counts`) — a theory section with three questions in it
/// would be a promise the content cannot keep yet.
const int kTheoryMinQuestions = 20;

class SchemeStep {
  const SchemeStep({required this.description, required this.marks});
  final String description;
  final int marks;
}

class TheoryPart {
  const TheoryPart({
    required this.label,
    required this.prompt,
    required this.marks,
    required this.scheme,
  });

  final String label;
  final String prompt;
  final int marks;
  final List<SchemeStep> scheme;
}

class TheoryQuestion {
  const TheoryQuestion({
    required this.id,
    required this.subjectId,
    required this.examYear,
    required this.number,
    required this.parts,
  });

  final String id;
  final String subjectId;
  final int examYear;
  final int number;
  final List<TheoryPart> parts;

  int get totalMarks => parts.fold(0, (n, p) => n + p.marks);

  factory TheoryQuestion.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    final rawParts = d['parts'];
    return TheoryQuestion(
      id: doc.id,
      subjectId: asString(d['subjectId']),
      examYear: asInt(d['examYear']),
      number: asInt(d['number']),
      parts: [
        if (rawParts is List)
          for (final p in rawParts)
            if (p is Map)
              TheoryPart(
                label: asString(p['label']),
                prompt: asString(p['prompt']),
                marks: asInt(p['marks']),
                scheme: [
                  if (p['scheme'] is List)
                    for (final s in p['scheme'] as List)
                      if (s is Map)
                        SchemeStep(
                          description: asString(s['description']),
                          marks: asInt(s['marks']),
                        ),
                ],
              ),
      ],
    );
  }
}

/// The marks a student gave themselves: the ticked steps of each part,
/// never more than the part is worth (a scheme can over-allocate).
int selfMarked(TheoryQuestion q, Set<(int, int)> ticked) {
  var total = 0;
  for (final (pi, part) in q.parts.indexed) {
    var got = 0;
    for (final (si, step) in part.scheme.indexed) {
      if (ticked.contains((pi, si))) got += step.marks;
    }
    total += got.clamp(0, part.marks);
  }
  return total;
}

/// A subject's published theory questions, newest paper first. Only ever
/// read once the subject has [kTheoryMinQuestions] of them.
final theoryQuestionsProvider = FutureProvider.autoDispose
    .family<List<TheoryQuestion>, String>((ref, subjectId) async {
      final snap = await FirebaseFirestore.instance
          .collection('theoryQuestions')
          .where('subjectId', isEqualTo: subjectId)
          .where('status', isEqualTo: 'published')
          .get()
          .metered();
      final list = [for (final d in snap.docs) TheoryQuestion.fromFirestore(d)]
        ..sort(
          (a, b) => b.examYear != a.examYear
              ? b.examYear.compareTo(a.examYear)
              : a.number.compareTo(b.number),
        );
      return list;
    });
