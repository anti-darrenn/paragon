import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/learn_resource.dart';
import '../../core/providers/reading_settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/report_lesson_button.dart';
import 'video_player.dart';

/// A video lesson: the player, then what the author wrote about it.
///
/// Completion is the player's to decide ([LessonVideoPlayer.onWatched]),
/// not a button's — skipping ahead to "Up next" deliberately earns no
/// checkmark.
///
/// In low-data mode ([lowDataModeProvider]) the YouTube iframe is not
/// created until the student taps "Tap to load video" — an embed starts
/// fetching the player and thumbnail the moment it exists.
class VideoPane extends ConsumerWidget {
  const VideoPane({
    super.key,
    required this.resource,
    required this.isOffline,
    this.onWatched,
    @visibleForTesting this.playerBuilder,
  });

  final LearnResource resource;
  final bool isOffline;
  final VoidCallback? onWatched;

  /// Replaces [LessonVideoPlayer] in tests, where the YouTube webview has
  /// no platform implementation. Receives the video id.
  final Widget Function(String videoId)? playerBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = resource.youtubeId?.trim() ?? '';
    final lowData = ref.watch(lowDataModeProvider);
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
          _TapToLoad(
            // Per video: a new video in low-data mode asks again.
            key: ValueKey('load-$id'),
            enabled: lowData,
            player: () =>
                playerBuilder?.call(id) ??
                LessonVideoPlayer(
                  // One player per video — see LessonVideoPlayer.
                  key: ValueKey('yt-$id'),
                  videoId: id,
                  durationSeconds: resource.durationSeconds,
                  onWatched: onWatched,
                ),
          ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                resource.title,
                style: AppTheme.heading2.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            ReportLessonButton(resource: resource),
          ],
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

/// Holds back [player] behind a "Tap to load video" card while [enabled].
///
/// With [enabled] false the player is built straight away, as before
/// low-data mode existed. Once a player has been shown — tapped, or built
/// with low-data off — it stays for this video: switching low-data mode on
/// mid-video must not tear down a video the student is watching. The card and the player occupy the same slot, so loading
/// does not change the pane's tree shape above the player.
class _TapToLoad extends StatefulWidget {
  const _TapToLoad({super.key, required this.enabled, required this.player});

  final bool enabled;
  final Widget Function() player;

  @override
  State<_TapToLoad> createState() => _TapToLoadState();
}

class _TapToLoadState extends State<_TapToLoad> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) _loaded = true;
    if (_loaded) return widget.player();
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.borderDark),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _loaded = true),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 48,
                    color: AppColors.textSecondaryDark,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to load video',
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Low-data mode is on. Nothing is downloaded until you tap.',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
