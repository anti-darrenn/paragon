import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/exam/exam_formats.dart';
import '../core/exam/saved_exam.dart';
import '../core/models/subject.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/load_error.dart';
import 'exam_history.dart';
import 'waec_exam_screen.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/nav/back_navigation.dart';
import '../core/widgets/ui/ui.dart';
import '../core/providers/analytics_provider.dart';

/// Exam setup screen, spec §2.3.3 — year range, question count, timer,
/// shuffle, and the dynamic availability label, scoped to whatever a
/// subject's real WAEC data actually spans (queried live, never assumed).
class WaecExamSetupScreen extends ConsumerStatefulWidget {
  final String subjectId;
  const WaecExamSetupScreen({super.key, required this.subjectId});

  @override
  ConsumerState<WaecExamSetupScreen> createState() =>
      _WaecExamSetupScreenState();
}

class _WaecExamSetupScreenState extends ConsumerState<WaecExamSetupScreen> {
  // Spec 2.3.3 defaults and ranges.
  static const _minQuestionCount = 10;
  static const _maxQuestionCount = 60;
  static const _questionCountStep = 5;
  static const _defaultQuestionCount = 40;
  static const _minTimerMinutes = 10;
  static const _maxTimerMinutes = 180;
  static const _timerStep = 10;
  static const _defaultTimerMinutes = 60;
  // Spec's literal default is "2015-2024 (10 years)" — adapted here to
  // "the most recent 10 years of whatever a subject's real range is",
  // since a hardcoded absolute range doesn't hold across subjects (Further
  // Mathematics runs 2006-2025, not 1990-2024 — see learning_repository.dart).
  static const _defaultYearSpan = 10;
  static const _minutesPerQuestionEstimate = 1.5;

  int? _yearFrom;
  int? _yearTo;
  int _questionCount = _defaultQuestionCount;
  bool _timerEnabled = true;
  int _timerMinutes = _defaultTimerMinutes;
  bool _shuffle = true;
  bool _starting = false;

  /// "Full paper" (the subject's real objective-paper length and time,
  /// `exam_formats.dart`) is the default; "Custom" shows the sliders.
  bool _fullPaper = true;
  bool _formatApplied = false;

  void _applyFormat(ExamFormat format, {required bool isGuest}) {
    _questionCount = format.questions;
    _timerMinutes = format.minutes;
    _timerEnabled = !isGuest;
  }

  String? _startError;

  Subject? _findSubject(List<Subject> subjects, String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _startExam(bool isGuest) async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    final config = WaecExamConfig(
      subjectId: widget.subjectId,
      yearFrom: _yearFrom!,
      yearTo: _yearTo!,
      questionCount: _questionCount,
      // Shuffle is hidden (not just locked) for guests — always on.
      shuffle: isGuest ? true : _shuffle,
    );
    try {
      final questions = await ref.read(
        waecExamQuestionsProvider(config).future,
      );
      if (questions.isEmpty) {
        if (mounted) {
          setState(() {
            _starting = false;
            _startError = 'No questions found for this combination.';
          });
        }
        return;
      }
      if (!mounted) return;
      ref
          .read(analyticsProvider)
          .examStart(
            subjectId: widget.subjectId,
            preset: _fullPaper ? 'full_paper' : 'custom',
          );
      context.go(
        '/waec/${widget.subjectId}/exam',
        extra: WaecExamSessionData(
          questions: questions,
          timerEnabled: isGuest ? false : _timerEnabled,
          timerDurationMinutes: _timerMinutes,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = "Couldn't load questions. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final rangeAsync = ref.watch(waecYearRangeProvider(widget.subjectId));
    final subjectsAsync = ref.watch(subjectsProvider);
    final subjectName =
        _findSubject(
          subjectsAsync.asData?.value ?? [],
          widget.subjectId,
        )?.name ??
        'WAEC Exam';

    final format = examFormatFor(subjectName);
    if (!_formatApplied && subjectName != 'WAEC Exam') {
      _formatApplied = true;
      if (_fullPaper) _applyFormat(format, isGuest: isGuest);
    }

    // Guests never get a timer, regardless of what the (hidden-for-guest)
    // toggle was left at.
    if (isGuest && _timerEnabled) _timerEnabled = false;

    return Scaffold(
      appBar: ParagonAppBar(title: Text(subjectName)),
      body: rangeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () =>
              ref.invalidate(waecYearRangeProvider(widget.subjectId)),
        ),
        data: (range) {
          final (minYear, maxYear) = range;
          _yearFrom ??= (maxYear - _defaultYearSpan + 1).clamp(
            minYear,
            maxYear,
          );
          _yearTo ??= maxYear;

          final query = WaecYearRangeQuery(
            subjectId: widget.subjectId,
            yearFrom: _yearFrom!,
            yearTo: _yearTo!,
          );
          final availableAsync = ref.watch(waecAvailableCountProvider(query));

          // Auto-snap the count slider down when the selected range has
          // fewer questions than requested, per spec's explicit "slider
          // auto-snaps to X" instruction. A provider-change side effect,
          // not something safe to do inline during build.
          ref.listen(waecAvailableCountProvider(query), (previous, next) {
            final count = next.asData?.value;
            if (count != null && count > 0 && count < _questionCount) {
              setState(() => _questionCount = count);
            }
          });

          return PageBody(
            children: [
              PageIntro(
                title: 'Set up your exam',
                subtitle:
                    '$subjectName past questions, marked at the end like '
                    'the real paper.',
              ),
              _ResumeCard(subjectId: widget.subjectId),
              SurfaceCard(child: _paperSection(format, isGuest)),
              const SizedBox(height: 12),
              SurfaceCard(child: _yearRangeSection(minYear, maxYear)),
              const SizedBox(height: 12),
              SurfaceCard(
                child: _questionCountSection(subjectName, availableAsync),
              ),
              if (!_fullPaper) ...[
                const SizedBox(height: 12),
                SurfaceCard(child: _timerSection(isGuest)),
              ],
              if (!isGuest) ...[
                const SizedBox(height: 12),
                SurfaceCard(child: _shuffleSection()),
              ],
              const SizedBox(height: 20),
              if (isGuest) ...[_guestUpsellChip(), const SizedBox(height: 20)],
              _startButton(isGuest, availableAsync),
              const SizedBox(height: kSectionGap + 8),
              ExamHistory(subjectId: widget.subjectId),
            ],
          );
        },
      ),
    );
  }

  Widget _paperSection(ExamFormat format, bool isGuest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paper',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Full paper')),
            ButtonSegment(value: false, label: Text('Custom')),
          ],
          selected: {_fullPaper},
          onSelectionChanged: (v) => setState(() {
            _fullPaper = v.first;
            if (_fullPaper) _applyFormat(format, isGuest: isGuest);
          }),
        ),
        const SizedBox(height: 10),
        Text(
          _fullPaper
              ? isGuest
                    ? '${format.questions} questions, untimed (make an account '
                          'to sit it against the clock)'
                    : format.label
              : 'Choose the length and time yourself.',
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        if (_fullPaper && !format.verified)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The usual length of the WASSCE objective paper; not yet '
              'checked against this year\'s.',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _yearRangeSection(int minYear, int maxYear) {
    final years = _yearTo! - _yearFrom! + 1;
    final singleYear = minYear == maxYear;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Year range',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '$_yearFrom – $_yearTo ($years year${years == 1 ? '' : 's'})',
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        if (singleYear)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Only $minYear has WAEC questions for this subject.',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          )
        else
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: context.palette.track,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withAlpha((0.2 * 255).round()),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: RangeSlider(
              min: minYear.toDouble(),
              max: maxYear.toDouble(),
              divisions: maxYear - minYear,
              values: RangeValues(_yearFrom!.toDouble(), _yearTo!.toDouble()),
              labels: RangeLabels('$_yearFrom', '$_yearTo'),
              onChanged: (values) => setState(() {
                _yearFrom = values.start.round();
                _yearTo = values.end.round();
              }),
            ),
          ),
      ],
    );
  }

  Widget _questionCountSection(
    String subjectName,
    AsyncValue<int> availableAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questions',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '$_questionCount questions',
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        if (!_fullPaper)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: context.palette.track,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withAlpha((0.2 * 255).round()),
            ),
            child: Slider(
              min: _minQuestionCount.toDouble(),
              max: _maxQuestionCount.toDouble(),
              divisions:
                  (_maxQuestionCount - _minQuestionCount) ~/ _questionCountStep,
              value: _questionCount
                  .clamp(_minQuestionCount, _maxQuestionCount)
                  .toDouble(),
              label: '$_questionCount',
              onChanged: (v) => setState(
                () => _questionCount =
                    (v / _questionCountStep).round() * _questionCountStep,
              ),
            ),
          ),
        const SizedBox(height: 4),
        availableAsync.when(
          loading: () => Text(
            'Checking availability…',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          error: (e, _) => Text(
            'Could not check availability.',
            style: AppTheme.caption.copyWith(color: AppColors.wrong),
          ),
          data: (available) {
            if (available == 0) {
              return Text(
                'No questions found for this combination.',
                style: AppTheme.caption.copyWith(color: AppColors.wrong),
              );
            }
            final base = Text(
              '$available questions available for $subjectName, $_yearFrom–$_yearTo',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            );
            if (available >= _questionCount) return base;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                base,
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Only $available available — your exam will have $available questions.',
                    style: AppTheme.caption.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _timerSection(bool isGuest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Timer',
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            if (isGuest)
              Tooltip(
                message: 'Sign in to enable the timer.',
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
              )
            else
              Switch(
                value: _timerEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _timerEnabled = v),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (!_timerEnabled)
          Text(
            'Untimed',
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          )
        else ...[
          Text(
            '$_timerMinutes minutes',
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: context.palette.track,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withAlpha((0.2 * 255).round()),
            ),
            child: Slider(
              min: _minTimerMinutes.toDouble(),
              max: _maxTimerMinutes.toDouble(),
              divisions: (_maxTimerMinutes - _minTimerMinutes) ~/ _timerStep,
              value: _timerMinutes.toDouble(),
              label: '$_timerMinutes',
              onChanged: (v) => setState(
                () => _timerMinutes = (v / _timerStep).round() * _timerStep,
              ),
            ),
          ),
          Text(
            '~${(_questionCount * _minutesPerQuestionEstimate).round()} min at $_minutesPerQuestionEstimate min/question',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _shuffleSection() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Shuffle questions',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
        ),
        Switch(
          value: _shuffle,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _shuffle = v),
        ),
      ],
    );
  }

  Widget _guestUpsellChip() {
    return GestureDetector(
      onTap: () => context.go('/welcome'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary.withAlpha((0.12 * 255).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Sign in to unlock all subjects and timed exams',
                style: AppTheme.bodyMd.copyWith(color: AppColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _startButton(bool isGuest, AsyncValue<int> availableAsync) {
    final available = availableAsync.asData?.value;
    final disabled = _starting || available == 0 || available == null;
    return Column(
      children: [
        if (_startError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _startError!,
              style: AppTheme.caption.copyWith(color: AppColors.wrong),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: disabled ? null : () => _startExam(isGuest),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _starting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Start Exam',
                    style: AppTheme.btnLabel.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The signed-in student's exam in progress for [subjectId], kept on the
/// device (`SavedExam`), or null.
final savedExamProvider = FutureProvider.autoDispose.family<SavedExam?, String>(
  (ref, subjectId) async {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return null;
    return ref.read(savedExamStoreProvider).load(uid, subjectId);
  },
);

/// "You have an exam in progress": resume it where it was left, clock and
/// all, or throw it away. Shown above the setup when there is one.
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedExamProvider(subjectId)).asData?.value;
    if (saved == null) return const SizedBox.shrink();
    final minutesLeft = (saved.remainingSeconds / 60).ceil();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have an exam in progress',
              style: AppTheme.heading3.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${saved.answeredCount} of ${saved.questions.length} answered'
              '${saved.timerEnabled ? ' · $minutesLeft min left' : ''}'
              '${saved.flagged.isEmpty ? '' : ' · ${saved.flagged.length} flagged'}',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(analyticsProvider)
                        .examStart(subjectId: subjectId, preset: 'resume');
                    context.go(
                      '/waec/$subjectId/exam',
                      extra: WaecExamSessionData.resuming(saved),
                    );
                  },
                  child: const Text('Resume'),
                ),
                TextButton(
                  onPressed: () async {
                    final uid = ref.read(currentUserProvider)?.uid;
                    if (uid != null) {
                      await ref
                          .read(savedExamStoreProvider)
                          .clear(uid, subjectId);
                    }
                    ref.invalidate(savedExamProvider(subjectId));
                  },
                  child: const Text('Discard it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
