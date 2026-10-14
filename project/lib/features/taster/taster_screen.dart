import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/guest_limits.dart';
import '../../core/models/question.dart';
import '../../core/plan/study_plan.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/repositories/progress_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_notice.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_runner.dart';
import '../../core/widgets/ui/ui.dart';
import '../plan/plan_widgets.dart';

/// `/try`: five questions in a minute, straight from the welcome screen —
/// the first thing a student who arrives from a WhatsApp link can do
/// (launch plan phase 2, "guest first session").
///
/// The questions come from the subject's most-examined topic (most past
/// questions), so the first taste is a topic that matters. Nothing is
/// recorded; the end offers the topic itself and an account.
class TasterScreen extends ConsumerStatefulWidget {
  const TasterScreen({super.key});

  @override
  ConsumerState<TasterScreen> createState() => _TasterScreenState();
}

class _TasterScreenState extends ConsumerState<TasterScreen> {
  static const _count = 5;

  String? _subjectId;
  Course? _course;
  PlanTopic? _topic;
  List<Question>? _questions;
  int? _score;
  bool _loading = false;
  String? _error;

  Future<void> _pick(String subjectId) async {
    setState(() {
      _subjectId = subjectId;
      _loading = true;
      _error = null;
      _questions = null;
      _score = null;
    });
    try {
      final course = await ref.read(courseProvider(subjectId).future);
      final topics = planTopicsFor(course, UserProgress.empty);
      if (topics.isEmpty) throw StateError('no topics');
      // The most-examined topic; course order breaks ties.
      final topic = topics.reduce(
        (a, b) => b.pastQuestions > a.pastQuestions ? b : a,
      );
      final pool = await ref.read(drillQuestionsProvider(topic.id).future);
      final qs = ([...pool]..shuffle()).take(_count).toList();
      if (qs.isEmpty) throw StateError('no questions');
      if (!mounted) return;
      setState(() {
        _course = course;
        _topic = topic;
        _questions = qs;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = "Couldn't load questions. Try another subject.",
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final course = _course;
    final topic = _topic;

    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Try five questions')),
      body: PageBody(
        children: [
          if (_questions == null) ...[
            const PageIntro(
              title: 'Five questions, one minute',
              subtitle:
                  'Pick a subject. You see the answer and how to get it '
                  'straight after each one.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  if (s.questionCount > 0 || s.counts.isSplit)
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _subjectId == s.id,
                      onSelected: _loading ? null : (_) => _pick(s.id),
                    ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const SkeletonPage(title: false, count: 3, cardHeight: 56),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: AppTheme.bodyMd),
            ],
          ] else if (_score == null)
            QuestionRunner(
              questions: _questions!,
              onFinished: (r) {
                setState(() => _score = r.where((x) => x.correct).length);
                ref
                    .read(analyticsProvider)
                    .tasterComplete(
                      subjectId: _subjectId ?? '',
                      correct: _score!,
                    );
              },
            )
          else ...[
            PageIntro(
              title: '$_score/${_questions!.length}',
              subtitle: _score! >= 4
                  ? 'Strong start. ${topic?.name ?? 'This topic'} comes up '
                        'often in WAEC; there is a lot more of it.'
                  : '${topic?.name ?? 'This topic'} comes up often in WAEC. '
                        'The lessons and practice will get you there.',
            ),
            if (ref.watch(isGuestProvider)) ...[
              GuestNotice(
                message: GuestLimits.saveResultMessage('what you do next'),
              ),
              const SizedBox(height: 16),
            ],
            if (course != null && topic != null)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go(
                    '/subject/${course.key}/course/topic/${topic.id}',
                  ),
                  child: Text('Learn ${topic.name}'),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => setState(() {
                _questions = null;
                _score = null;
              }),
              child: const Text('Try another subject'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                'Go to Home',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
