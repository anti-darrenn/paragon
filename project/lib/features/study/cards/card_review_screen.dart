import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/lessons/subject_index.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/subject_index_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_view.dart';
import '../../../core/widgets/full_latex_view.dart';
import 'card_deck.dart';
import 'card_providers.dart';
import 'leitner.dart';

/// Route for a subject's revision cards.
String cardsPath(String subjectId) => '/cards/$subjectId';

const kGuestCardsPrompt =
    'Sign up to keep your revision progress on every device. Right now it '
    'is kept on this device only.';

/// `/cards/:subjectId` — spaced-repetition review of a subject's cards.
///
/// Choose "Review all due" or a topic; see a card's front, tap to reveal
/// the back, say whether you knew it. At the end, a summary.
///
/// **One write per session.** Results are held here and committed when
/// the session ends — or when the student leaves part-way — as a single
/// merge. Nothing in this screen touches `progress`, `attempts` or
/// mastery: a revision card is self-assessed and must never open or
/// reward anything.
class CardReviewScreen extends ConsumerStatefulWidget {
  const CardReviewScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<CardReviewScreen> createState() => _CardReviewScreenState();
}

class _CardReviewScreenState extends ConsumerState<CardReviewScreen> {
  /// Held from the start: `ref` may not be used in [dispose], which is
  /// where a session abandoned part-way is saved.
  late final CardScheduleNotifier _schedule;

  List<IndexedCard>? _queue;
  Map<String, CardState> _startSchedule = const {};
  String _sessionLabel = '';
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;
  int _knew = 0;
  int _missed = 0;

  /// Results not yet written.
  final Map<String, CardState> _pending = {};

  @override
  void initState() {
    super.initState();
    _schedule = ref.read(cardScheduleProvider.notifier);
  }

  @override
  void dispose() {
    if (_pending.isNotEmpty) {
      final changes = Map.of(_pending);
      final schedule = _schedule;
      // After this frame: a provider must not change while the tree is
      // being torn down.
      Future.microtask(() async {
        try {
          await schedule.commit(changes);
        } catch (_) {
          // Leaving the screen is not the moment to report a failure.
        }
      });
    }
    super.dispose();
  }

  void _start(List<IndexedCard> cards, CardDeck deck, String label) {
    setState(() {
      _queue = cards;
      _startSchedule = deck.schedule;
      _sessionLabel = label;
      _index = 0;
      _revealed = false;
      _finished = false;
      _knew = 0;
      _missed = 0;
    });
  }

  void _answer(bool knew) {
    final queue = _queue!;
    final card = queue[_index];
    final leitner = ref.read(leitnerProvider);
    _pending[card.id] = leitner.review(
      _pending[card.id] ?? _startSchedule[card.id],
      knew: knew,
    );
    setState(() {
      knew ? _knew++ : _missed++;
      _index++;
      _revealed = false;
    });
    if (_index >= queue.length) _finish();
  }

  void _finish() {
    setState(() => _finished = true);
    _save();
  }

  Future<void> _save() async {
    if (_pending.isEmpty) return;
    final changes = Map.of(_pending);
    _pending.clear();
    try {
      await _schedule.commit(changes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save this session. Check your connection."),
        ),
      );
    }
  }

  /// Back where the student came from; home when the page was opened
  /// directly by its URL.
  void _leave() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      GoRouter.maybeOf(context)?.go('/');
    }
  }

  void _backToChooser() => setState(() {
    _queue = null;
    _finished = false;
  });

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final Widget body;
    if (queue == null) {
      body = _Chooser(subjectId: widget.subjectId, onStart: _start);
    } else if (_finished) {
      body = _Summary(
        knew: _knew,
        missed: _missed,
        onAgain: _backToChooser,
        onDone: _leave,
      );
    } else {
      final card = queue[_index];
      body = _CardFace(
        key: ValueKey('card-${card.id}'),
        card: card,
        position: _index + 1,
        total: queue.length,
        label: _sessionLabel,
        revealed: _revealed,
        onReveal: () => setState(() => _revealed = true),
        onAnswer: _answer,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Revision cards'),
        actions: [
          if (queue != null && !_finished && _index > 0)
            TextButton(
              key: const ValueKey('cards.finishNow'),
              onPressed: _finish,
              child: const Text('Finish now'),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      ),
    );
  }
}

TextStyle get _text =>
    AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark);
TextStyle get _muted =>
    AppTheme.caption.copyWith(color: AppColors.textSecondaryDark);

class _GuestCardsPrompt extends ConsumerWidget {
  const _GuestCardsPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isGuestProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.phone_android,
            size: 14,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(kGuestCardsPrompt, style: _muted)),
        ],
      ),
    );
  }
}

class _Chooser extends ConsumerWidget {
  const _Chooser({required this.subjectId, required this.onStart});

  final String subjectId;
  final void Function(List<IndexedCard>, CardDeck, String) onStart;

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center, style: _muted),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexAsync = ref.watch(subjectIndexProvider(subjectId));
    if (indexAsync.hasError && !indexAsync.hasValue) {
      return _message("Couldn't load the cards. Check your connection.");
    }
    final deck = ref.watch(cardDeckProvider(subjectId));
    if (deck == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (deck.cards.isEmpty) {
      return _message('No revision cards for this subject yet.');
    }

    final index = indexAsync.asData?.value ?? SubjectIndex.empty;
    final topics =
        [
          for (final t in index.topics.values)
            if (t.cards.isNotEmpty) t,
        ]..sort(
          (a, b) =>
              a.topicName.toLowerCase().compareTo(b.topicName.toLowerCase()),
        );
    final dueSession = deck.dueSession();
    final due = deck.dueCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _GuestCardsPrompt(),
        Text(
          '${deck.cards.length} ${deck.cards.length == 1 ? 'card' : 'cards'} · $due due',
          key: const ValueKey('cards.summaryLine'),
          style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('cards.reviewDue'),
          onPressed: dueSession.isEmpty
              ? null
              : () => onStart(dueSession, deck, 'Due cards'),
          icon: const Icon(Icons.style_outlined),
          label: Text(
            due > dueSession.length
                ? 'Review ${dueSession.length} of $due due'
                : 'Review all due ($due)',
          ),
        ),
        if (dueSession.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Nothing is due. Come back tomorrow, or pick a topic below.',
            style: _muted,
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Pick a topic',
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 8),
        for (final t in topics)
          Builder(
            builder: (context) {
              final dueHere = t.cards.where(deck.isDue).length;
              final name = t.topicName.isEmpty ? t.topicId : t.topicName;
              return ListTile(
                key: ValueKey('cards.topic.${t.topicId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(name, style: _text),
                subtitle: Text(
                  '${t.cards.length} ${t.cards.length == 1 ? 'card' : 'cards'} · $dueHere due',
                  style: _muted,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondaryDark,
                ),
                onTap: () => onStart(deck.topicSession(t.topicId), deck, name),
              );
            },
          ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    super.key,
    required this.card,
    required this.position,
    required this.total,
    required this.label,
    required this.revealed,
    required this.onReveal,
    required this.onAnswer,
  });

  final IndexedCard card;
  final int position;
  final int total;
  final String label;
  final bool revealed;
  final VoidCallback onReveal;
  final void Function(bool knew) onAnswer;

  String get _prompt => switch (card.kind) {
    'definition' => 'Define',
    'formula' => 'State the formula',
    'remember' => 'Remember',
    _ => 'Card',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          '$position of $total · $label',
          key: const ValueKey('cards.position'),
          style: _muted,
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surfaceDark,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.borderDark),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: InkWell(
            key: const ValueKey('cards.face'),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            onTap: revealed ? null : onReveal,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_prompt.toUpperCase(), style: _muted),
                  const SizedBox(height: 8),
                  FullLatexView(
                    latex: card.front,
                    textStyle: AppTheme.heading2.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (card.topicName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(card.topicName, style: _muted),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 12),
                  if (revealed)
                    KeyedSubtree(
                      key: const ValueKey('cards.back'),
                      child: ArticleView(body: card.back),
                    )
                  else
                    Text(
                      'Tap to show the answer',
                      textAlign: TextAlign.center,
                      style: _muted,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (revealed)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cards.missed'),
                  onPressed: () => onAnswer(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.wrong,
                    side: const BorderSide(color: AppColors.wrong),
                  ),
                  child: const Text("Didn't know"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('cards.knew'),
                  onPressed: () => onAnswer(true),
                  child: const Text('Knew it'),
                ),
              ),
            ],
          )
        else
          FilledButton(
            key: const ValueKey('cards.reveal'),
            onPressed: onReveal,
            child: const Text('Show answer'),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.knew,
    required this.missed,
    required this.onAgain,
    required this.onDone,
  });

  final int knew;
  final int missed;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final total = knew + missed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Text(
          'Session done',
          style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 8),
        Text(
          total == 0
              ? 'No cards reviewed.'
              : 'You knew $knew of $total. '
                    '${missed == 0 ? 'Those cards come back later.' : "The $missed you didn't know come back tomorrow."}',
          key: const ValueKey('cards.result'),
          style: _text,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('cards.again'),
          onPressed: onAgain,
          child: const Text('Review more'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
