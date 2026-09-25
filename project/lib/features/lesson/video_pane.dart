import 'package:flutter/material.dart';

import '../../core/models/learn_resource.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'video_player.dart';

/// A video lesson: the player, then what the author wrote about it.
///
/// Completion is the player's to decide ([LessonVideoPlayer.onWatched]),
/// not a button's — skipping ahead to "Up next" deliberately earns no
/// checkmark.
class VideoPane extends StatelessWidget {
  const VideoPane({
    super.key,
    required this.resource,
    required this.isOffline,
    this.onWatched,
  });

  final LearnResource resource;
  final bool isOffline;
  final VoidCallback? onWatched;

  @override
  Widget build(BuildContext context) {
    final id = resource.youtubeId?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (id.isEmpty || isOffline)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border.all(color: AppColors.borderDark),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Text(
                isOffline
                    ? "You're offline. Videos need a connection."
                    : 'This video has not been recorded yet.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          )
        else
          LessonVideoPlayer(
            // One player per video — see LessonVideoPlayer.
            key: ValueKey('yt-$id'),
            videoId: id,
            durationSeconds: resource.durationSeconds,
            onWatched: onWatched,
          ),
        const SizedBox(height: 20),
        Text(
          resource.title,
          style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
        ),
        if (resource.durationSeconds case final s? when s > 0) ...[
          const SizedBox(height: 4),
          Text(
            formatDuration(s),
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
        if (resource.description case final d?) ...[
          const SizedBox(height: 16),
          Text(
            d,
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
        if (resource.transcript case final t?) ...[
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Transcript',
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                SelectableText(
                  t,
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// `m:ss`, or `h:mm:ss` past an hour.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
