import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/math_text.dart';

class WaecExamScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const WaecExamScreen({super.key, required this.subjectId});

  @override
  ConsumerState<WaecExamScreen> createState() => _WaecExamScreenState();
}

class _WaecExamScreenState extends ConsumerState<WaecExamScreen> {
  int _currentIndex = 0;
  // Stores selected answer index per question index
  final Map<int, int> _answers = {};
  bool _examSubmitted = false;
  int _score = 0;

  void _selectOption(int optionIndex) {
    if (_examSubmitted) return;
    setState(() => _answers[_currentIndex] = optionIndex);
  }

  void _goToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  void _submitExam(List questions) {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].correctIndex) correct++;
    }
    setState(() {
      _examSubmitted = true;
      _score = correct;
    });
  }

  void _confirmSubmit(List questions) {
    final unanswered =
        questions.length - _answers.length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Exam?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Are you sure?'
              : 'Submit your answers now?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitExam(questions);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ← MATCH TO YOUR PROVIDER NAME in learning_repository.dart
    final questionsAsync =
        ref.watch(waecQuestionsProvider(widget.subjectId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
          tooltip: 'Exit exam',
        ),
        title: questionsAsync.when(
          loading: () => const Text('WAEC Exam'),
          error: (e, st) => const Text('WAEC Exam'),
          data: (questions) => Text(
            '${_currentIndex + 1} / ${questions.length}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
        actions: [
          // Timer placeholder — wired in Session 7
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: const [
                Icon(Icons.timer_outlined, size: 16, color: Colors.white38),
                SizedBox(width: 4),
                Text('--:--',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e')),
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(
              child: Text('No WAEC questions available for this subject.',
                  style: TextStyle(color: Colors.white54)),
            );
          }

          if (_examSubmitted) {
            return _ResultsView(
              score: _score,
              total: questions.length,
              answers: _answers,
              questions: questions,
              onReview: () => setState(() => _examSubmitted = false),
              onExit: () => context.pop(),
            );
          }

          final q = questions[_currentIndex];
          final selectedOption = _answers[_currentIndex];

          return Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: (_currentIndex + 1) / questions.length,
                backgroundColor: const Color(0xFF21262D),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
                minHeight: 3,
              ),

              // Question navigator strip
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: questions.length,
                  itemBuilder: (_, i) {
                    final isActive = i == _currentIndex;
                    final isAnswered = _answers.containsKey(i);
                    return GestureDetector(
                      onTap: () => _goToQuestion(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppColors.primary
                              : isAnswered
                                  ? AppColors.primary.withAlpha((0.25 * 255).round())
                                  : const Color(0xFF21262D),
                          border: isActive
                              ? null
                              : Border.all(
                                    color: isAnswered
                                      ? AppColors.primary.withAlpha((0.5 * 255).round())
                                      : const Color(0xFF30363D)),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive || isAnswered
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Question + options
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF30363D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (q.year != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'WAEC ${q.year}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12),
                                ),
                              ),
                            FullLatexView(
                              latex: q.text,
                              textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(q.options.length, (i) {
                        final isSelected = selectedOption == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _selectOption(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: isSelected
                                  ? AppColors.primary.withAlpha((0.1 * 255).round())
                                    : const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF30363D),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFF21262D),
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: MathText(
                                      text: q.options[i],
                                      useLightRenderer: true,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Navigation + submit
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _goToQuestion(_currentIndex - 1),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFF30363D)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                            child: const Text('← Prev',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      if (_currentIndex > 0) const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _currentIndex < questions.length - 1
                              ? () => _goToQuestion(_currentIndex + 1)
                              : () => _confirmSubmit(questions),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _currentIndex < questions.length - 1
                                    ? AppColors.primary
                                    : const Color(0xFF238636),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                          child: Text(
                            _currentIndex < questions.length - 1
                                ? 'Next →'
                                : 'Submit Exam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results view
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final int score;
  final int total;
  final Map<int, int> answers;
  final List questions;
  final VoidCallback onReview;
  final VoidCallback onExit;

  const _ResultsView({
    required this.score,
    required this.total,
    required this.answers,
    required this.questions,
    required this.onReview,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? ((score / total) * 100).round() : 0;
    final Color scoreColor = pct >= 50 ? AppColors.correct : AppColors.wrong;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text('Exam Complete',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '$score / $total  ($pct%)',
            style: TextStyle(
                color: scoreColor,
                fontSize: 36,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            pct >= 50 ? 'Pass' : 'Below pass mark',
            style:
                TextStyle(color: scoreColor, fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onReview,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF30363D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Review Answers',
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onExit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Subjects',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}