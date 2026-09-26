import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../lessons/lesson_doc.dart';
import '../../models/lesson_asset.dart';
import '../../providers/reading_settings_provider.dart';
import '../../repositories/learn_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../full_latex_view.dart';
import '../../theme/app_palette.dart';

/// An image in a lesson, with its caption. Tap to zoom.
///
/// `asset:<id>` images come from `lessonAssets` (see [LessonAsset]); plain
/// `https://` links load from the web. Either way a missing or broken image
/// says so in place — it never takes the article down with it.
///
/// In low-data mode nothing is fetched until the student taps "Tap to load
/// image", and a tap loads that one image only.
class FigureView extends ConsumerStatefulWidget {
  const FigureView({super.key, required this.block, required this.base});

  final FigureBlock block;
  final TextStyle base;

  @override
  ConsumerState<FigureView> createState() => _FigureViewState();
}

class _FigureViewState extends ConsumerState<FigureView> {
  /// Set by a tap in low-data mode. Once loaded, an image stays loaded.
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    if (ref.watch(lowDataModeProvider) && !_requested) {
      return _TapToLoad(
        caption: block.caption,
        onTap: () => setState(() => _requested = true),
      );
    }

    final Widget image;
    final assetId = block.assetId;
    if (assetId != null) {
      final async = ref.watch(lessonAssetProvider(assetId));
      image = async.when(
        loading: () => const _Placeholder(child: CircularProgressIndicator()),
        error: (_, _) => const _Broken(),
        data: (asset) =>
            asset == null ? const _Broken() : _AssetImage(asset: asset),
      );
    } else if (block.ref.startsWith('https://')) {
      image = Image.network(
        block.ref,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _Broken(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const _Placeholder(child: CircularProgressIndicator()),
      );
    } else {
      image = const _Broken();
    }

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth * block.widthFraction;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              image: true,
              label: block.caption.isEmpty ? 'Figure' : block.caption,
              child: GestureDetector(
                onTap: () => _zoom(context, image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: width, child: image),
                ),
              ),
            ),
            if (block.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: width,
                child: FullLatexView(
                  latex: block.caption,
                  textStyle: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _zoom(BuildContext context, Widget image) {
    showDialog<void>(
      context: context,
      barrierColor: context.palette.background.withAlpha(235),
      builder: (dialog) => GestureDetector(
        onTap: () => Navigator.of(dialog).pop(),
        child: InteractiveViewer(maxScale: 5, child: Center(child: image)),
      ),
    );
  }
}

class _TapToLoad extends StatelessWidget {
  const _TapToLoad({required this.caption, required this.onTap});
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.palette.border),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(Icons.image_outlined, color: context.palette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  caption.isEmpty ? 'Image' : caption,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Text(
                'Tap to load image',
                style: AppTheme.caption.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({required this.asset});
  final LessonAsset asset;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (asset.isSvg) {
      child = SvgPicture.string(asset.data, fit: BoxFit.contain);
    } else {
      final bytes = asset.bytes;
      if (bytes == null) return const _Broken();
      child = Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _Broken(),
      );
    }
    final ratio = asset.aspectRatio;
    return ratio == null
        ? child
        : AspectRatio(aspectRatio: ratio, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    alignment: Alignment.center,
    color: context.palette.surface,
    child: child,
  );
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => _Placeholder(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: context.palette.textSecondary),
        const SizedBox(height: 6),
        Text(
          "This image couldn't be loaded.",
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    ),
  );
}
