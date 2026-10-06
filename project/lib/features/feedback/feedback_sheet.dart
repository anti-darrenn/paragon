import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/feedback_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// "Send feedback": anything a student wants to tell us that is not a
/// report against one question or lesson (those have their own buttons).
///
/// Stored in `feedback/{id}` with the screen's route pattern, read by
/// reviewers in the studio, and included in the team's email digest.
/// Guests can send it; a signed-out visitor never sees the entry point.
Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const FeedbackSheet(),
  );
}

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key});

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _text = TextEditingController();
  FeedbackKind _kind = FeedbackKind.idea;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .send(userId: user.uid, kind: _kind, message: _text.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thank you. The team reads every one.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send that. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send feedback',
                style: AppTheme.heading3.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us what to fix or build next. To report a wrong '
                'answer, use "Report a problem" on the question itself.',
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in FeedbackKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: _sending
                          ? null
                          : (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                enabled: !_sending,
                minLines: 4,
                maxLines: 8,
                maxLength: kFeedbackMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _kind.hint.isEmpty
                      ? 'What would you like to tell us?'
                      : _kind.hint,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please don't include your phone number, address or "
                'anything private.',
                style: AppTheme.caption.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _sending || _text.text.trim().isEmpty
                      ? null
                      : _send,
                  child: Text(_sending ? 'Sending…' : 'Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
