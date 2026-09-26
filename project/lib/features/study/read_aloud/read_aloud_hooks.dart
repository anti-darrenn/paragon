import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/learn_resource.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lesson_blocks/lesson_block_view.dart';
import 'read_aloud_controller.dart';
import 'speech_segments.dart';
import '../../../core/theme/app_palette.dart';

/// Where read-aloud plugs into a lesson article.
///
/// `ArticlePane` calls these and nothing else, so read-aloud can grow
/// without editing the renderer or the pane.

/// Wraps each top-level block, to mark the block being read with a thin
/// accent bar in the margin.
BlockDecorator readAloudDecorator(WidgetRef ref, LearnResource resource) =>
    (block, child) => block.key.isEmpty
    ? child
    : ReadAloudMark(resourceId: resource.id, blockKey: block.key, child: child);

/// The bar beside the block being read.
///
/// **Always the same tree** — a passthrough [Stack] with the bar faded in
/// or out — so starting and stopping never remounts the block beneath it
/// (which would reset a worked example's revealed steps, or a quick
/// check's chosen answer). The bar sits in the left margin, outside the
/// block's own width, so the article does not reflow while it moves.
class ReadAloudMark extends ConsumerWidget {
  const ReadAloudMark({
    super.key,
    required this.resourceId,
    required this.blockKey,
    required this.child,
  });

  final String resourceId;
  final String blockKey;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      readAloudProvider(resourceId).select((s) => s.currentKey == blockKey),
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -10,
          top: 2,
          bottom: 2,
          width: 3,
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: ValueKey('readAloud.mark.$blockKey'),
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "Listen" control for the article's header row: Listen, then Pause
/// or Resume and Stop, with a speed choice.
///
/// Shown disabled, with a tooltip saying why, on a device that cannot
/// speak (no speech synthesis, no voices). Hidden for an empty article.
class ReadAloudButton extends ConsumerWidget {
  const ReadAloudButton({super.key, required this.resource});

  final LearnResource resource;

  static const unavailableMessage =
      "Read aloud isn't available on this device or browser.";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (resource.body.trim().isEmpty) return const SizedBox.shrink();

    // Unknown while the check runs: Listen stays usable, and a failure
    // then simply returns to idle.
    final available = ref.watch(speechAvailableProvider).asData?.value;
    if (available == false) {
      return Tooltip(
        message: unavailableMessage,
        child: TextButton.icon(
          key: const ValueKey('readAloud.unavailable'),
          onPressed: null,
          icon: const Icon(Icons.headphones_rounded, size: 18),
          label: const Text('Listen'),
        ),
      );
    }

    final provider = readAloudProvider(resource.id);
    final status = ref.watch(provider.select((s) => s.status));
    final controller = ref.read(provider.notifier);
    final colour = AppColors.primary;

    final Widget main = switch (status) {
      ReadAloudStatus.idle => TextButton.icon(
        key: const ValueKey('readAloud.listen'),
        onPressed: () => controller.play(
          lessonSpeechSegments(parseLessonDoc(resource.body)),
        ),
        style: TextButton.styleFrom(foregroundColor: colour),
        icon: const Icon(Icons.headphones_rounded, size: 18),
        label: const Text('Listen'),
      ),
      ReadAloudStatus.playing => IconButton(
        key: const ValueKey('readAloud.pause'),
        tooltip: 'Pause',
        color: colour,
        onPressed: controller.pause,
        icon: const Icon(Icons.pause_rounded),
      ),
      ReadAloudStatus.paused => IconButton(
        key: const ValueKey('readAloud.resume'),
        tooltip: 'Resume',
        color: colour,
        onPressed: controller.resume,
        icon: const Icon(Icons.play_arrow_rounded),
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        if (status != ReadAloudStatus.idle)
          IconButton(
            key: const ValueKey('readAloud.stop'),
            tooltip: 'Stop',
            color: context.palette.textSecondary,
            onPressed: controller.stop,
            icon: const Icon(Icons.stop_rounded),
          ),
        const _SpeedChoice(),
      ],
    );
  }
}

class _SpeedChoice extends ConsumerWidget {
  const _SpeedChoice();

  static String label(double rate) {
    final text = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toString();
    return '$text×';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(readAloudRateProvider);
    return PopupMenuButton<double>(
      key: const ValueKey('readAloud.speed'),
      tooltip: 'Reading speed (applies from the next sentence)',
      initialValue: rate,
      onSelected: ref.read(readAloudRateProvider.notifier).set,
      color: context.palette.surface,
      itemBuilder: (context) => [
        for (final r in kReadAloudRates)
          PopupMenuItem(
            value: r,
            child: Text(
              label(r),
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          label(rate),
          style: AppTheme.label.copyWith(color: context.palette.textSecondary),
        ),
      ),
    );
  }
}
