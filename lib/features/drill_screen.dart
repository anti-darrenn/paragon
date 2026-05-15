import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/question.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/math_text.dart';

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


          final progressValue = ( _index + (_submitted ? 1 : 0) ) / questions.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Top progress bar
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: const Color(0xFF21262D),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3,
                ),
                const SizedBox(height: 12),
                Text(
                  'Question ${_index + 1} of ${questions.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                FullLatexView(
                  latex: q.text,
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
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
                  final optionColor = _submitted
                      ? (i == q.correctIndex
                          ? AppColors.correct
                          : (i == _selected ? AppColors.wrong : Colors.white70))
                      : (_selected == i ? Colors.white : Colors.white70);

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
                      child: MathText(
                        text: q.options[i],
                        useLightRenderer: true,
                        style: TextStyle(color: optionColor, fontSize: 15),
                      ),
                    ),
                  );
                }),
                if (_submitted) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.correct.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.correct.withAlpha((0.4 * 255).round())),
                    ),
                    child: FullLatexView(latex: q.explanation, textStyle: const TextStyle(color: Colors.white70, fontSize: 14)),
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