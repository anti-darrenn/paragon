import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/learn/watch_tracker.dart';
import '../../core/theme/app_palette.dart';

/// A YouTube lesson video, and the only file that imports the player
/// package — swapping players later means changing this file alone.
///
/// Web renders an iframe, Android a webview; both through
/// `youtube_player_iframe`, on YouTube's privacy-enhanced
/// `youtube-nocookie.com` host (the package default, pinned here anyway).
///
/// **One player per video.** Give this widget a key derived from
/// [videoId] at the call site; the controller lives in this State, so an
/// ordinary parent rebuild keeps the same player. That is not enough on
/// its own: if the player's *position in the tree* changes, Flutter moves
/// its iframe in the DOM and the browser reloads it, restarting playback.
/// `LessonScreen` keeps one tree shape for every layout for exactly that
/// reason — tested in the browser, where a Row-to-Column swap restarted
/// the video.
///
/// Calls [onWatched] once, when [WatchTracker] judges the video watched.
class LessonVideoPlayer extends StatefulWidget {
  const LessonVideoPlayer({
    super.key,
    required this.videoId,
    this.durationSeconds,
    this.onWatched,
  });

  final String videoId;

  /// The authored duration, used until the player reports its own.
  final int? durationSeconds;

  final VoidCallback? onWatched;

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  late final YoutubePlayerController _controller;
  late final WatchTracker _tracker;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _tracker = WatchTracker(
      durationSeconds: widget.durationSeconds?.toDouble(),
    );
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        privacyEnhancedMode: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    _subscriptions
      ..add(
        _controller.videoStateStream.listen((state) {
          _tracker.onPosition(state.position.inMilliseconds / 1000);
          _check();
        }),
      )
      ..add(
        _controller.stream.listen((value) {
          final seconds = value.metaData.duration.inMilliseconds / 1000;
          if (seconds > 0) _tracker.durationSeconds = seconds;
          if (value.playerState == PlayerState.ended) _tracker.onEnded();
          _check();
        }),
      );
  }

  void _check() {
    if (_reported || !_tracker.isComplete) return;
    _reported = true;
    widget.onWatched?.call();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(
        controller: _controller,
        backgroundColor: context.palette.background,
        keepAlive: true,
      ),
    );
  }
}
