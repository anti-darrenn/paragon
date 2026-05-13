import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/question.dart';
import '../core/theme/app_colors.dart';

class WaecExamScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const WaecExamScreen({super.key, required this.subjectId});

  @override
  ConsumerState<WaecExamScreen> createState() => _WaecExamScreenState();
}

class _WaecExamScreenState extends ConsumerState<WaecExamScreen> {
  final Map<int, int> _answers = {};
  bool _submitted = false;

  void _submitExam() => setState(() => _submitted = true);

  int _score(List<Question> questions) => questions
      .asMap()
      .entries
      .where((e) => _answers[e.key] == e.value.correctIndex)
      .length;

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(waecQuestionsProvider(widget.subjectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('WAEC Exam Mode'),
        actions: [
          if (!_submitted)
            TextButton(
              onPressed: _submitExam,
              child: const Text('Submit Exam',
                  style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
                child: Text('No WAEC questions for this subject yet.'));
          }

          if (_submitted) {
            final score = _score(questions);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$score / ${questions.length}',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppColors.primary)),
                  const SizedBox(height: 8),
                  const Text('Questions correct'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (q.year != null)
                      Text('WAEC ${q.year}',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${i + 1}. ${q.text}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...List.generate(q.options.length, (j) {
                      final selected = _answers[i] == j;
                      return GestureDetector(
                        onTap: () => setState(() => _answers[i] = j),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white24,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(q.options[j]),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}