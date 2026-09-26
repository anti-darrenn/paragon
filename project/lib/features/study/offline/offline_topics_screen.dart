import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'save_offline_button.dart' show kOfflineRemoveNote;
import 'saved_topics_store.dart';
import '../../../core/theme/app_palette.dart';

/// Saved for offline — `/settings/offline`.
///
/// The topics this device was asked to keep, with a link to each and a way
/// to take it off the list. Per device, so guests have it too.
class OfflineTopicsScreen extends ConsumerWidget {
  const OfflineTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(savedTopicsProvider);
    final caption = AppTheme.caption.copyWith(
      color: context.palette.textSecondary,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Saved for offline')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              children: [
                Text(
                  "Lessons you've saved can be read without a connection. "
                  'Videos always need internet. Removing a topic takes it '
                  'off this list; the copy already on this device is only '
                  'cleared when space is needed for newer content.',
                  style: caption,
                ),
                const SizedBox(height: 20),
                if (topics.isEmpty)
                  Text(
                    'Nothing saved yet. Open a topic and choose '
                    '"Save for offline".',
                    style: AppTheme.bodyMd.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  )
                else
                  for (final t in topics)
                    Card(
                      color: context.palette.surface,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        key: ValueKey('offline.row.${t.topicId}'),
                        onTap: t.courseKey.isEmpty
                            ? null
                            : () => context.push(t.path),
                        title: Text(
                          t.name.isEmpty ? 'Untitled topic' : t.name,
                          style: AppTheme.bodyMd.copyWith(
                            color: context.palette.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          [
                            'Saved ${formatSavedDate(t.savedAt)}',
                            'about ${t.itemCount} items',
                            if (t.videoCount > 0)
                              t.videoCount == 1
                                  ? 'video needs internet'
                                  : '${t.videoCount} videos need internet',
                          ].join(' · '),
                          style: caption,
                        ),
                        trailing: IconButton(
                          key: ValueKey('offline.remove.${t.topicId}'),
                          tooltip: 'Remove from list',
                          color: context.palette.textSecondary,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await ref
                                .read(savedTopicsProvider.notifier)
                                .remove(t.topicId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              const SnackBar(
                                content: Text(kOfflineRemoveNote),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
