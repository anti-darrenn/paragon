import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

/// A spinner for content of unknown shape that is still on its way, shown
/// only after [delay] so a fast load never flashes one. Announced to a
/// screen reader as [label].
///
/// Prefer a skeleton (`SkeletonPage`, `SkeletonBox`) for a page whose shape
/// is known: it reads as "arriving" rather than "waiting". This is for the
/// rest — a panel, a sheet, a step whose layout depends on what loads.
class LoadingView extends StatefulWidget {
  const LoadingView({
    super.key,
    this.label = 'Loading',
    this.showLabel = false,
    this.delay = const Duration(milliseconds: 350),
    this.padding = const EdgeInsets.symmetric(vertical: 48),
  });

  final String label;

  /// Writes [label] under the spinner (for longer waits: "Preparing your
  /// paper…"). It is always announced either way.
  final bool showLabel;
  final Duration delay;
  final EdgeInsets padding;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _show = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: widget.padding,
          child: Center(
            child: !_show
                ? const SizedBox(height: 28)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      if (widget.showLabel) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMd.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
