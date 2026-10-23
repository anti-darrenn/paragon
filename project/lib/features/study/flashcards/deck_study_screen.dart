import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/session/session_summary.dart';
import '../../../core/widgets/question_runner.dart';
import '../../../core/widgets/ui/ui.dart';
import '../cards/card_deck.dart' show kCardsPerSession;
import '../cards/card_providers.dart';
import '../cards/leitner.dart';
import 'deck.dart';
import 'deck_store.dart';

/// `/review/flashcards/:deckId/study`: a deck's cards, due ones first, one
/// at a time. Tap to turn the card over, then say whether you knew it.
///
/// The schedule is the revision cards' Leitner boxes, in the same
/// `study/{uid}.cards` map, and is written **once**, when the session ends
/// or the student leaves. Nothing here touches `progress` or `attempts`.
class DeckStudyScreen extends ConsumerStatefulWidget {
  const DeckStudyScreen({super.key, required this.deckId});
  final String deckId;

  @override
  ConsumerState<DeckStudyScreen> createState() => _DeckStudyScreenState();
}

class _DeckStudyScreenState extends ConsumerState<DeckStudyScreen> {
  late final CardScheduleNotifier _schedule;
  List<Flashcard>? _queue;
  int _index = 0;
  bool _back = false;
  int _knew = 0;
  int _missed = 0;
  final Map<String, CardState> _pending = {};

  @override
  void initState() {
    super.initState();
    _schedule = ref.read(cardScheduleProvider.notifier);
  }

  @override
  void dispose() {
    // Left part-way: what was answered is still kept, in one write.
    if (_pending.isNotEmpty) _schedule.commit(Map.of(_pending));
    super.dispose();
  }

  List<Flashcard> _session(Deck deck, Map<String, CardState> schedule) {
    final leitner = ref.read(leitnerProvider);
    final cards = deck.usable;
    final due = [
      for (final c in cards)
        if (leitner.isDue(schedule[scheduleId(deck.id, c.id)])) c,
    ];
    // Nothing due: the whole deck, soonest first, so it can still be
    // studied the night before a test.
    final pool = due.isNotEmpty ? due : [...cards];
    if (due.isEmpty) {
      pool.sort(
        (a, b) => (schedule[scheduleId(deck.id, a.id)]?.due ?? DateTime(0))
            .compareTo(schedule[scheduleId(deck.id, b.id)]?.due ?? DateTime(0)),
      );
    }
    return pool.take(kCardsPerSession).toList();
  }

  void _answer(Deck deck, bool knew) {
    final card = _queue![_index];
    final id = scheduleId(deck.id, card.id);
    final schedule = ref.read(cardScheduleProvider).asData?.value ?? const {};
    _pending[id] = ref
        .read(leitnerProvider)
        .review(_pending[id] ?? schedule[id], knew: knew);
    setState(() {
      knew ? _knew++ : _missed++;
      _index++;
      _back = false;
    });
    if (_index == _queue!.length) {
      _schedule.commit(Map.of(_pending));
      _pending.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final deck = ref.watch(deckProvider(widget.deckId));
    final schedule = ref.watch(cardScheduleProvider);
    if (deck == null || !schedule.hasValue) {
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Study')),
        body: ref.watch(decksProvider).isLoading || schedule.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                icon: Icons.style_outlined,
                title: 'Deck not found',
                message: 'It may have been deleted.',
              ),
      );
    }
    _queue ??= _session(deck, schedule.value!);
    final queue = _queue!;
    final done = _index >= queue.length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: ParagonAppBar(title: Text(deck.title)),
      body: PageBody(
        children: [
          if (done)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SessionSummary(
                title: 'Session done',
                correct: _knew,
                total: _knew + _missed,
                subtitle:
                    'You knew $_knew of ${_knew + _missed}. The ones you '
                    'missed come back tomorrow.',
                celebrate: SessionSummary.isWorthCelebrating(
                  correct: _knew,
                  total: _knew + _missed,
                ),
                primary: AppButton(
                  label: 'Back to my decks',
                  expand: true,
                  onPressed: () => context.popOrGo(),
                ),
              ),
            )
          else ...[
            Text(
              'Card ${_index + 1} of ${queue.length}',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            AppProgressBar(value: _index / queue.length),
            const SizedBox(height: 20),
            FlipCard(
              key: ValueKey(queue[_index].id),
              front: queue[_index].front,
              back: queue[_index].back,
              showBack: _back,
              onFlip: () => setState(() => _back = !_back),
            ),
            const SizedBox(height: 20),
            if (_back)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _answer(deck, false),
                      child: const Text("Didn't know"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _answer(deck, true),
                      child: const Text('Knew it'),
                    ),
                  ),
                ],
              )
            else
              FilledButton.tonal(
                onPressed: () => setState(() => _back = true),
                child: const Text('Show the answer'),
              ),
          ],
        ],
      ),
    );
  }
}

/// A card that turns over: a quarter-turn away, swap the face, a
/// quarter-turn back. With "reduce motion" on it simply swaps.
class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    required this.onFlip,
  });

  final String front;
  final String back;
  final bool showBack;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget face(String text, bool isBack) => Container(
      key: ValueKey(isBack),
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isBack ? palette.surface : AppColors.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBack ? palette.border : AppColors.primary.withAlpha(120),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isBack ? 'Answer' : 'Front',
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 10),
          FullLatexView(
            latex: text,
            textAlign: TextAlign.center,
            textStyle: AppTheme.bodyLg.copyWith(
              color: palette.textPrimary,
              fontWeight: isBack ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: showBack
          ? 'Answer. Tap to see the front'
          : 'Tap to see the answer',
      child: GestureDetector(
        onTap: onFlip,
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 320),
          transitionBuilder: (child, animation) {
            final turn = Tween(begin: pi / 2, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: turn,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(turn.value),
                child: child,
              ),
            );
          },
          child: showBack ? face(back, true) : face(front, false),
        ),
      ),
    );
  }
}

/// `/review/flashcards/:deckId/quiz`: multiple choice made from the deck
/// (`quizFromDeck`). Instant feedback; nothing is recorded.
class DeckQuizScreen extends ConsumerStatefulWidget {
  const DeckQuizScreen({super.key, required this.deckId});
  final String deckId;

  @override
  ConsumerState<DeckQuizScreen> createState() => _DeckQuizScreenState();
}

class _DeckQuizScreenState extends ConsumerState<DeckQuizScreen> {
  int? _score;
  int _total = 0;
  int _round = 0;

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider(widget.deckId));
    final questions = deck == null
        ? const []
        : quizFromDeck(
            deck,
            random: Random(_round * 7919 + widget.deckId.hashCode),
          );
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: Text(deck?.title ?? 'Quiz')),
      body: deck == null || questions.isEmpty
          ? const PageBody(
              children: [
                EmptyState(
                  illustration: IllustrationAsset.empty,
                  title: 'Not enough cards for a quiz',
                  message: 'A quiz needs four cards with different answers.',
                ),
              ],
            )
          : _score != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: SessionSummary(
                title: 'Round done',
                correct: _score!,
                total: _total,
                subtitle:
                    'Quizzes from your flashcards are just for you: '
                    'nothing is recorded.',
                celebrate: SessionSummary.isWorthCelebrating(
                  correct: _score!,
                  total: _total,
                ),
                primary: AppButton(
                  label: 'Another round',
                  expand: true,
                  onPressed: () => setState(() {
                    _score = null;
                    _round++;
                  }),
                ),
                secondary: AppButton(
                  label: 'Back to my decks',
                  tone: ButtonTone.secondary,
                  expand: true,
                  onPressed: () => context.popOrGo(),
                ),
              ),
            )
          // The quiz fills the page, so its Check bar pins to the bottom.
          : QuestionRunner(
              key: ValueKey(_round),
              questions: [...questions],
              showDifficulty: false,
              onFinished: (results) => setState(() {
                _score = results.where((r) => r.correct).length;
                _total = results.length;
              }),
            ),
    );
  }
}
