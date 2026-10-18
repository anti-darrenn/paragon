import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/math_field/math_field.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/ui/ui.dart';
import 'deck.dart';
import 'deck_store.dart';
import '../hub/study_paths.dart';

/// `/review/flashcards/:deckId` (`new` for a new deck): a deck's title,
/// its subject (optional, for the glossary-style grouping) and its cards,
/// each side typed in Normal or LaTeX mode.
///
/// **One write a visit.** The deck is saved when the student taps Save or
/// leaves with changes, never per keystroke.
class DeckEditorScreen extends ConsumerStatefulWidget {
  const DeckEditorScreen({super.key, required this.deckId});

  /// `new` makes a new deck.
  final String deckId;

  @override
  ConsumerState<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _CardBoxes {
  _CardBoxes(this.id, String front, String back)
    : front = TextEditingController(text: front),
      back = TextEditingController(text: back);
  final String id;
  final TextEditingController front;
  final TextEditingController back;

  void dispose() {
    front.dispose();
    back.dispose();
  }
}

class _DeckEditorScreenState extends ConsumerState<DeckEditorScreen> {
  final _math = MathEditing(prefsKey: 'flashcards');
  final _title = TextEditingController();
  final _cards = <_CardBoxes>[];
  String? _subjectId;
  late String _id;
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _id = widget.deckId == 'new' ? newFlashId() : widget.deckId;
    _title.addListener(_touch);
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _cards) {
      c.dispose();
    }
    _math.dispose();
    super.dispose();
  }

  void _touch() {
    if (_loaded && !_dirty) setState(() => _dirty = true);
  }

  void _load(Deck? deck) {
    _loaded = true;
    _title.text = deck?.title ?? '';
    _subjectId = deck?.subjectId;
    for (final c in deck?.cards ?? const <Flashcard>[]) {
      _addBoxes(c.id, c.front, c.back);
    }
    if (_cards.isEmpty) {
      for (var i = 0; i < 3; i++) {
        _addBoxes(newFlashId(), '', '');
      }
    }
    _dirty = false;
  }

  void _addBoxes(String id, String front, String back) {
    final b = _CardBoxes(id, front, back);
    b.front.addListener(_touch);
    b.back.addListener(_touch);
    _cards.add(b);
  }

  Deck get _deck => Deck(
    id: _id,
    title: _title.text,
    subjectId: _subjectId,
    cards: [
      for (final c in _cards)
        Flashcard(
          id: c.id,
          front: c.front.text.length > Deck.maxSide
              ? c.front.text.substring(0, Deck.maxSide)
              : c.front.text,
          back: c.back.text.length > Deck.maxSide
              ? c.back.text.substring(0, Deck.maxSide)
              : c.back.text,
        ),
    ],
  );

  Future<bool> _save() async {
    if (_deck.usable.isEmpty) return true;
    setState(() => _saving = true);
    try {
      await ref.read(decksProvider.notifier).save(_deck);
      if (mounted) setState(() => _dirty = false);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't save the deck: $e")));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this deck?'),
        content: const Text('Its cards and their schedule go too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.wrong),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(decksProvider.notifier).delete(_id);
    if (mounted) {
      _dirty = false;
      context.go(kDecksPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final decks = ref.watch(decksProvider);
    if (!_loaded) {
      if (decks.isLoading && widget.deckId != 'new') {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _load(ref.read(deckProvider(widget.deckId)));
    }
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final full = _cards.length >= Deck.maxCards;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _save() && context.mounted) context.popOrGo();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: ParagonAppBar(
          title: Text(widget.deckId == 'new' ? 'New deck' : 'Edit deck'),
          actions: [
            if (widget.deckId != 'new')
              IconButton(
                tooltip: 'Delete the deck',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            TextButton(
              onPressed: _saving || !_dirty ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageBody(
          children: [
            TextField(
              controller: _title,
              maxLength: Deck.maxTitle,
              decoration: const InputDecoration(
                labelText: 'Deck name',
                hintText: 'e.g. Indices laws',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() {
                _subjectId = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            MathToolbar(editing: _math),
            const SizedBox(height: 12),
            for (var i = 0; i < _cards.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Card ${i + 1}',
                            style: AppTheme.label.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Remove card ${i + 1}',
                            onPressed: () => setState(() {
                              _cards.removeAt(i).dispose();
                              _dirty = true;
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                      MathField(
                        controller: _cards[i].front,
                        editing: _math,
                        hint: 'Front: a question, word or formula name',
                      ),
                      const SizedBox(height: 8),
                      MathField(
                        controller: _cards[i].back,
                        editing: _math,
                        minLines: 2,
                        hint: 'Back: the answer',
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: full
                    ? null
                    : () => setState(() {
                        _addBoxes(newFlashId(), '', '');
                        _dirty = true;
                      }),
                icon: const Icon(Icons.add_rounded),
                label: Text(full ? 'A deck holds 300 cards' : 'Add a card'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
