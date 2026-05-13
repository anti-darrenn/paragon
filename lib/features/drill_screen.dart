import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/question.dart';
import '../core/theme/app_colors.dart';

class DrillScreen extends ConsumerStatefulWidget {
  final String topicId;
  const DrillScreen({super.key, required this.topicId});

  @override
  ConsumerState<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends ConsumerState<DrillScreen> {
  int _index = 0;
  int? _selected;
  bool _submitted = false;

  void _submit() {
    if (_selected == null) return;
    setState(() => _submitted = true);
  }

  void _next(List<Question> questions) {
    if (_index < questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(drillQuestionsProvider(widget.topicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Drill')),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
                child: Text('No questions for this topic yet.'));
          }
          final q = questions[_index];
          final isLast = _index == questions.length - 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  'Question ${_index + 1} of ${questions.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                Text(q.text,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                ...List.generate(q.options.length, (i) {
                  Color borderColor = Colors.white24;
                  if (_submitted) {
                    if (i == q.correctIndex) {
                      borderColor = AppColors.correct;
                    } else if (i == _selected) {
                      borderColor = AppColors.wrong;
                    }
                  } else if (_selected == i) {
                    borderColor = AppColors.primary;
                  }
                  return GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() => _selected = i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: borderColor, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(q.options[i]),
                    ),
                  );
                }),
                if (_submitted) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.correct.withOpacity(0.4)),
                    ),
                    child: Text(q.explanation),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitted
                        ? (isLast ? null : () => _next(questions))
                        : (_selected != null ? _submit : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _submitted
                          ? (isLast ? 'Done' : 'Next Question')
                          : 'Submit Answer',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}