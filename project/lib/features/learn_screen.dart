import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/topic.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/full_latex_view.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';

class LearnScreen extends ConsumerWidget {
  final String subjectId;
  final String unitId;
  final String topicId;

  const LearnScreen({
    super.key,
    required this.subjectId,
    required this.unitId,
    required this.topicId,
  });

  Topic? _findTopic(List<Topic> topics) {
    final matches = topics.where((t) => t.id == topicId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(unitId));
    final isOffline = ref.watch(isOnlineProvider).asData?.value == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(topicsProvider(unitId)),
        ),
        data: (topics) {
          final topic = _findTopic(topics);
          if (topic == null) {
            return Center(
              child: Text(
                'This topic could not be found.',
                style: TextStyle(color: context.palette.onMedium),
              ),
            );
          }

          return Column(
            children: [
              if (isOffline) const _OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.name,
                        style: AppTheme.heading1.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _VideoPlaceholder(),
                      const SizedBox(height: 24),
                      Text(
                        'Topic Notes',
                        style: AppTheme.heading2.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _NotesSection(topic: topic),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(
                        '/subject/$subjectId/unit/$unitId/topic/$topicId',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Practice this topic →',
                        style: AppTheme.btnLabel.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.wrong.withAlpha((0.15 * 255).round()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        "You're offline — showing the last loaded content.",
        style: AppTheme.caption.copyWith(color: AppColors.wrong),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// No topic has a video yet — hasNotes/notesMarkdown exist on the model,
// but there's no videoId field or player package to justify adding one
// until a topic actually has a video to play.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: context.palette.textSecondary,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'Video coming soon',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final Topic topic;
  const _NotesSection({required this.topic});

  @override
  Widget build(BuildContext context) {
    final notes = topic.notesMarkdown;
    if (!topic.hasNotes || notes == null || notes.isEmpty) {
      return Text(
        'Notes coming soon.',
        style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
      );
    }
    return FullLatexView(
      latex: notes,
      textStyle: AppTheme.bodyLg.copyWith(color: context.palette.textPrimary),
    );
  }
}
