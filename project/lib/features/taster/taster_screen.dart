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
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_notice.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_runner.dart';
import '../../core/widgets/session/session_summary.dart';
import '../../core/widgets/ui/ui.dart';
import '../plan/plan_widgets.dart';

/// `/try`: five questions in a minute, straight from the welcome screen —
/// the first thing a student who arrives from a WhatsApp link can do
/// (launch plan phase 2, "guest first session").
///
/// The questions come from the subject's most-examined topic (most past
/// questions), so the first taste is a topic that matters. Nothing is
/// recorded; the end offers the topic itself and an account.
/// [count] questions from [pool], real past questions first, each group
/// shuffled. The first question a new visitor sees should prove "real WAEC
/// questions", with its year on it; it was as often "Paragon practice"
/// (audit C14). Practice questions only fill up a topic short of past ones.
List<Question> tasterQuestions(List<Question> pool, int count) {
  final past = [...pool.where((q) => q.isPastQuestion)]..shuffle();
  final rest = [...pool.where((q) => !q.isPastQuestion)]..shuffle();
  return [...past, ...rest].take(count).toList();
}

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
      final qs = tasterQuestions(pool, _count);
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

  void _finished(List<({Question question, int selected, bool correct})> r) {
    setState(() => _score = r.where((x) => x.correct).length);
    ref
        .read(analyticsProvider)
        .tasterComplete(subjectId: _subjectId ?? '', correct: _score!);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final course = _course;
    final topic = _topic;
    final questions = _questions;
    final score = _score;

    final Widget body;
    if (questions != null && score == null) {
      // The session fills the page, so its Check bar pins to the bottom.
      body = QuestionRunner(questions: questions, onFinished: _finished);
    } else if (questions != null && score != null) {
      final name = topic?.name ?? 'This topic';
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: SessionSummary(
          title: score >= 4 ? 'Strong start' : 'A good first try',
          correct: score,
          total: questions.length,
          subtitle: score >= 4
              ? '$name comes up often in WAEC; there is a lot more of it.'
              : '$name comes up often in WAEC. The lessons and practice '
                    'will get you there.',
          celebrate: SessionSummary.isWorthCelebrating(
            correct: score,
            total: questions.length,
          ),
          details: [
            if (ref.watch(isGuestProvider))
              GuestNotice(
                message: GuestLimits.saveResultMessage('what you do next'),
              ),
          ],
          primary: course != null && topic != null
              ? AppButton(
                  label: 'Learn ${topic.name}',
                  expand: true,
                  onPressed: () => context.go(course.pathForTopicId(topic.id)),
                )
              : AppButton(
                  label: 'Go to Home',
                  expand: true,
                  onPressed: () => context.go('/'),
                ),
          secondary: AppButton(
            label: 'Try another subject',
            tone: ButtonTone.secondary,
            expand: true,
            onPressed: () => setState(() {
              _questions = null;
              _score = null;
            }),
          ),
          tertiary: course != null && topic != null
              ? AppButton(
                  label: 'Go to Home',
                  tone: ButtonTone.ghost,
                  expand: true,
                  onPressed: () => context.go('/'),
                )
              : null,
        ),
      );
    } else {
      body = PageBody(
        children: [
          const PageIntro(
            title: 'Five questions, one minute',
            subtitle:
                'Pick a subject. You see the answer and how to get it '
                'straight after each one.',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final s in subjects)
                if (s.questionCount > 0 || s.counts.isSplit)
                  _SubjectChoice(
                    name: s.name,
                    selected: _subjectId == s.id,
                    onTap: _loading ? null : () => _pick(s.id),
                  ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 24),
            const SkeletonPage(title: false, count: 3, cardHeight: 56),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            InlineAlert(tone: Tone.danger, message: _error!, announce: true),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Try five questions')),
      body: body,
    );
  }
}

/// A subject to try, as a small card with its motif.
class _SubjectChoice extends StatelessWidget {
  const _SubjectChoice({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = AppColors.forSubject(name);
    return SizedBox(
      width: 156,
      child: Semantics(
        selected: selected,
        button: true,
        child: SurfaceCard(
          onTap: onTap,
          borderColor: selected ? AppColors.primary : null,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Illustration(
                IllustrationAsset.forSubject(name),
                height: 44,
                accent: colour,
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: AppTheme.bodyMd.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
