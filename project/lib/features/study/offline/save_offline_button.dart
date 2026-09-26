import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/learn_resource.dart';
import '../../../core/providers/reading_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'offline_fetcher.dart';
import 'offline_plan.dart';
import 'saved_topics_store.dart';

/// What the student is told when they remove a saved topic. Firestore has
/// no per-document eviction, so removing cannot delete anything — saying
/// otherwise would be a lie about their phone's storage.
const kOfflineRemoveNote =
    'Removed from your saved list. The copy already downloaded stays on '
    'this device until it is cleared to make room for newer content.';

/// "Save for offline" for one topic, on its overview page.
///
/// Nothing is ever saved automatically: a save starts only from this
/// button, and in low-data mode only after the student confirms the size.
class SaveTopicOfflineButton extends ConsumerStatefulWidget {
  const SaveTopicOfflineButton({
    super.key,
    required this.topicId,
    required this.topicName,
    required this.subjectId,
    required this.courseKey,
    required this.resources,
  });

  final String topicId;
  final String topicName;
  final String subjectId;
  final String courseKey;

  /// The resources the page already loaded — used only to estimate the
  /// size before saving. The save itself refetches them from the server.
  final List<LearnResource> resources;

  @override
  ConsumerState<SaveTopicOfflineButton> createState() =>
      _SaveTopicOfflineButtonState();
}

class _SaveTopicOfflineButtonState
    extends ConsumerState<SaveTopicOfflineButton> {
  /// Null when not saving; 0..[kOfflineSaveSteps] while a save runs.
  int? _step;
  bool _failed = false;

  Future<void> _save() async {
    if (ref.read(lowDataModeProvider)) {
      final items = planOfflinePrefetch(widget.resources).approximateItems;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Save for offline?'),
          content: Text(
            'Low-data mode is on. This will download about $items items.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('offline.confirm.cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('offline.confirm.ok'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _step = 0;
      _failed = false;
    });
    try {
      final result = await saveTopicForOffline(
        ref.read(offlineFetcherProvider),
        widget.topicId,
        onStep: (s) {
          if (mounted) setState(() => _step = s);
        },
      );
      await ref
          .read(savedTopicsProvider.notifier)
          .add(
            SavedTopic(
              topicId: widget.topicId,
              name: widget.topicName,
              subjectId: widget.subjectId,
              courseKey: widget.courseKey,
              savedAt: DateTime.now(),
              itemCount: result.itemCount,
              videoCount: result.videoCount,
            ),
          );
      if (mounted) setState(() => _step = null);
    } catch (e) {
      debugPrint('save for offline failed: $e');
      if (mounted) {
        setState(() {
          _step = null;
          _failed = true;
        });
      }
    }
  }

  Future<void> _remove() async {
    await ref.read(savedTopicsProvider.notifier).remove(widget.topicId);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text(kOfflineRemoveNote)));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(
      savedTopicsProvider.select(
        (list) => list.where((t) => t.topicId == widget.topicId).firstOrNull,
      ),
    );
    final caption = AppTheme.caption.copyWith(
      color: AppColors.textSecondaryDark,
    );

    final Widget body;
    if (_step != null) {
      body = Column(
        key: const ValueKey('offline.saving'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saving for offline…',
            style: AppTheme.bodyMd.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _step! / kOfflineSaveSteps,
            minHeight: 3,
            color: AppColors.primary,
            backgroundColor: AppColors.trackDark,
          ),
        ],
      );
    } else if (saved != null) {
      body = Column(
        key: const ValueKey('offline.saved'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.offline_pin_rounded,
                size: 18,
                color: AppColors.correct,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved for offline · ${formatSavedDate(saved.savedAt)}',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('offline.remove'),
                onPressed: _remove,
                child: const Text('Remove'),
              ),
            ],
          ),
          if (saved.videoCount > 0)
            Text(
              saved.videoCount == 1
                  ? 'The video needs internet.'
                  : '${saved.videoCount} videos need internet.',
              style: caption,
            ),
          TextButton(
            key: const ValueKey('offline.resave'),
            onPressed: _save,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Save again to update'),
          ),
        ],
      );
    } else {
      body = Column(
        key: const ValueKey('offline.idle'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('offline.save'),
            onPressed: _save,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.borderDark),
            ),
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            label: const Text('Save for offline'),
          ),
          const SizedBox(height: 6),
          Text(
            _failed
                ? "Couldn't save. Check your connection and try again."
                : 'Read these lessons without a connection. Videos still '
                      'need internet.',
            style: _failed ? caption.copyWith(color: AppColors.wrong) : caption,
          ),
        ],
      );
    }

    return Padding(padding: const EdgeInsets.only(top: 12), child: body);
  }
}
