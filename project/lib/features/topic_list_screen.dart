import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/topic.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';

class TopicListScreen extends ConsumerWidget {
  final String subjectId;
  final String unitId;
  const TopicListScreen({
    super.key,
    required this.subjectId,
    required this.unitId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(unitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Topics')),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(topicsProvider(unitId)),
        ),
        data: (topics) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: topics.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _TopicTile(
            topic: topics[i],
            subjectId: subjectId,
            unitId: unitId,
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final Topic topic;
  final String subjectId;
  final String unitId;
  const _TopicTile({
    required this.topic,
    required this.subjectId,
    required this.unitId,
  });

  String get _basePath => '/subject/$subjectId/unit/$unitId/topic/${topic.id}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('$_basePath/learn'),
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.palette.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic.name,
              style: AppTheme.heading3.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${topic.questionCount} questions',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('$_basePath/learn'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Learn',
                      style: AppTheme.btnLabel.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push(_basePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Practice',
                      style: AppTheme.btnLabel.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
