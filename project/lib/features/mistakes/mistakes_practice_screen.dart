import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/attempt_repository.dart';
import '../../core/repositories/difficulty_vote_repository.dart';
import '../../core/repositories/mistakes_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/difficulty_rating.dart';
import '../../core/widgets/report_problem_button.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/sound/sfx.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/session/session_frame.dart';
import '../../core/widgets/session/session_summary.dart';
import '../../core/widgets/ui/ui.dart';

/// `/mistakes/practice`: the notebook's questions again, one at a time,
/// with immediate feedback, as in drill.
///
/// Answers are recorded once, at the end, as `source: 'review'`. They
/// **never** reach `ProgressRepository`: mastery at proficient opens drill
/// by itself, so practising old mistakes must not count toward it, for
/// the same reason the topic test and exercises do not. A right answer
/// still clears the question from the notebook, because it is now the
/// latest attempt.
class MistakesPracticeScreen extends ConsumerStatefulWidget {
  const MistakesPracticeScreen({super.key, required this.questions});

  /// Null when the page was opened without the notebook (a reload or a
  /// typed URL): there is then nothing to practise.
  final List<Question>? questions;

  @override
  ConsumerState<MistakesPracticeScreen> createState() =>
      _MistakesPracticeScreenState();
}

class _MistakesPracticeScreenState
    extends ConsumerState<MistakesPracticeScreen> {
  int _index = 0;
  int? _selected;
  bool _checked = false;
  final _answers = <AttemptDraft>[];

  /// "How hard was this?" answers, sent with the session's attempts.
  final Map<String, int> _ratings = {};

  bool _saving = false;
  bool _saveFailed = false;

  final _scroll = ScrollController();
  final _feedbackKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(int i) {
    if (_checked) return;
    Sfx.unlock();
    setState(() => _selected = i);
  }

  List<Question> get _questions => widget.questions ?? const [];

  void _check() {
    final q = _questions[_index];
    Sfx.play(_selected == q.correctIndex ? SfxCue.correct : SfxCue.wrong);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _feedbackKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: Motion.of(context, Motion.medium),
        curve: Motion.curve,
      );
    });
    setState(() {
      _checked = true;
      _answers.add(
        AttemptDraft(
          questionId: q.id,
          topicId: q.topicId,
          subjectId: q.subjectId,
          selectedIndex: _selected!,
          isCorrect: _selected == q.correctIndex,
        ),
      );
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_index == _questions.length) _save();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _answers.isEmpty) return;
    if (_ratings.isNotEmpty) {
      ref
          .read(difficultyVoteRepositoryProvider)
          .submit(uid: user.uid, votes: Map.of(_ratings))
          .ignore();
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(attemptRepositoryProvider)
          .recordBatch(userId: user.uid, source: 'review', attempts: _answers);
      if (!mounted) return;
      // the notebook re-reads, so questions answered right here leave it
      ref.invalidate(mistakesProvider);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: const Text('Practise mistakes')),
      body: _questions.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  illustration: IllustrationAsset.empty,
                  title: 'Nothing chosen to practise',
                  message:
                      'Open your mistakes notebook to choose what to practise.',
                  action: AppButton(
                    label: 'Go to the notebook',
                    onPressed: () => context.go('/mistakes'),
                  ),
                ),
              ),
            )
          : _index >= _questions.length
          ? _summary(context)
          : _question(context),
    );
  }

  Widget _question(BuildContext context) {
    final q = _questions[_index];
    final right = _checked && _selected == q.correctIndex;
    final isLast = _index + 1 == _questions.length;
    final VoidCallback? primary = _checked
        ? _next
        : (_selected == null ? null : _check);
    return SessionKeys(
      optionCount: q.options.length,
      onSelect: _checked ? null : _pick,
      onEnter: primary,
      child: SessionLayout(
        controller: _scroll,
        header: SessionHeader(
          index: _index,
          total: _questions.length,
          states: [
            for (var i = 0; i < _questions.length; i++)
              i < _answers.length
                  ? (_answers[i].isCorrect
                        ? SegmentState.right
                        : SegmentState.wrong)
                  : SegmentState.pending,
          ],
        ),
        bar: SessionActionBar(
          verdict: !_checked
              ? SessionVerdict.none
              : (right ? SessionVerdict.right : SessionVerdict.wrong),
          label: !_checked ? 'Check' : (isLast ? 'See results' : 'Continue'),
          onPressed: primary,
          optionCount: q.options.length,
          message: _checked ? _Verdict(right: right) : null,
        ),
        children: [
          QuestionCard(question: q),
          for (var i = 0; i < q.options.length; i++)
            AnswerOption(
              index: i,
              text: q.options[i],
              state: !_checked
                  ? (_selected == i
                        ? AnswerOptionState.selected
                        : AnswerOptionState.idle)
                  : i == q.correctIndex
                  ? AnswerOptionState.correct
                  : i == _selected
                  ? AnswerOptionState.wrong
                  : AnswerOptionState.idle,
              onTap: _checked ? null : () => _pick(i),
            ),
          if (_checked) ...[
            FeedbackPanel(
              key: _feedbackKey,
              question: q,
              right: right,
              missingNote: null,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ReportProblemButton(
                questionId: q.id,
                isGenerated: q.isGenerated,
              ),
            ),
            // Optional, and in the page rather than the bar.
            Align(
              alignment: Alignment.centerLeft,
              child: DifficultyRating(
                selected: _ratings[q.id],
                onRate: (level) => setState(() => _ratings[q.id] = level),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final right = _answers.where((a) => a.isCorrect).length;
    final total = _answers.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: SessionSummary(
        title: '$right of $total right',
        correct: right,
        total: total,
        subtitle: right == 0
            ? 'These stay in your notebook for next time.'
            : right == total
            ? 'All $total have left your notebook.'
            : '$right ${right == 1 ? 'has' : 'have'} left your notebook. '
                  'The rest stay for next time.',
        celebrate: SessionSummary.isWorthCelebrating(
          correct: right,
          total: total,
        ),
        details: [
          if (_saveFailed)
            InlineAlert(
              tone: Tone.danger,
              announce: true,
              message:
                  "Your answers couldn't be saved, so the notebook hasn't "
                  'changed. Check your connection.',
              action: TextButton(
                onPressed: _save,
                child: const Text('Try again'),
              ),
            ),
        ],
        primary: AppButton(
          label: 'Back to the notebook',
          loading: _saving,
          expand: true,
          onPressed: () => context.popOrGo(),
        ),
      ),
    );
  }
}

/// "Right this time." or "Not yet.", in words and an icon, announced.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.right});

  final bool right;

  @override
  Widget build(BuildContext context) {
    final colour = right ? context.palette.successFg : context.palette.dangerFg;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            right ? Icons.check_circle : Icons.cancel,
            color: colour,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              right ? 'Right this time.' : 'Not yet.',
              style: AppTheme.bodyLg.copyWith(
                color: colour,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
