import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';

/// Paragon's illustrations, in `assets/illustrations/`. Flat drawings in
/// four marker colours that [Illustration] swaps for the theme's own
/// (see `tools/illustrations/make.py`, which writes them), so one file
/// reads in dark and in light.
enum IllustrationAsset {
  celebrate('celebrate'),
  empty('empty'),
  searchEmpty('search_empty'),
  offline('offline'),
  notFound('not_found'),
  error('error'),
  welcome('welcome'),
  subjectMathematics('subject_mathematics'),
  subjectFurtherMathematics('subject_further_mathematics'),
  subjectPhysics('subject_physics'),
  subjectChemistry('subject_chemistry'),
  subjectGovernment('subject_government'),
  subjectBiology('subject_biology'),
  subjectEconomics('subject_economics'),
  subjectEnglish('subject_english_language'),
  subjectCommerce('subject_commerce'),
  subjectMusic('subject_music'),
  subjectGeneric('subject_generic');

  const IllustrationAsset(this.file);
  final String file;

  String get path => 'assets/illustrations/$file.svg';

  /// A subject's motif, by its name ("Further Mathematics") — the same
  /// names [AppColors.forSubject] knows. Any other subject gets the
  /// generic stack of books.
  static IllustrationAsset forSubject(String name) =>
      switch (name.toLowerCase().trim()) {
        'mathematics' => subjectMathematics,
        'further mathematics' => subjectFurtherMathematics,
        'physics' => subjectPhysics,
        'chemistry' => subjectChemistry,
        'government' => subjectGovernment,
        'biology' => subjectBiology,
        'economics' => subjectEconomics,
        'english language' || 'english' => subjectEnglish,
        'commerce' => subjectCommerce,
        'music' => subjectMusic,
        _ => subjectGeneric,
      };
}

/// The marker colours the files are drawn in.
abstract final class IllustrationMarkers {
  static const ink = 0xFF101010;
  static const paper = 0xFFFEFEFE;
  static const shade = 0xFFC8C8C8;
  static const line = 0xFF808080;
  static const accent = 0xFFFF00FF;
}

/// A decorative drawing: hidden from screen readers (the words beside it
/// carry the meaning), a fixed-size space while it loads, and nothing at
/// all while [Illustration.hidden] is set (low-data mode).
class Illustration extends StatelessWidget {
  const Illustration(
    this.asset, {
    super.key,
    this.height = 140,
    this.accent,
  });

  final IllustrationAsset asset;
  final double height;

  /// The accent colour: a subject's colour, a tone. The brand orange when
  /// not given.
  final Color? accent;

  /// Set from low-data mode by the app, so decoration is never downloaded
  /// on a metered connection. A notifier rather than a provider, so the
  /// widget works anywhere — including tests without a ProviderScope.
  static final ValueNotifier<bool> hidden = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hidden,
      builder: (context, isHidden, _) {
        if (isHidden) return const SizedBox.shrink();
        final p = context.palette;
        return ExcludeSemantics(
          child: SvgPicture.asset(
            asset.path,
            height: height,
            excludeFromSemantics: true,
            colorMapper: IllustrationColours(
              ink: p.textPrimary,
              paper: p.surface,
              shade: p.track,
              line: p.border,
              accent: accent ?? AppColors.primary,
            ),
            placeholderBuilder: (_) => SizedBox(height: height),
          ),
        );
      },
    );
  }
}

/// Swaps the marker colours for real ones. Equal mappers share a cached
/// picture, hence the `==`.
@immutable
class IllustrationColours extends ColorMapper {
  const IllustrationColours({
    required this.ink,
    required this.paper,
    required this.shade,
    required this.line,
    required this.accent,
  });

  final Color ink, paper, shade, line, accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final swapped = switch (color.toARGB32() | 0xFF000000) {
      IllustrationMarkers.ink => ink,
      IllustrationMarkers.paper => paper,
      IllustrationMarkers.shade => shade,
      IllustrationMarkers.line => line,
      IllustrationMarkers.accent => accent,
      _ => null,
    };
    if (swapped == null) return color;
    // Keep any alpha the drawing gave the marker.
    return swapped.withAlpha((swapped.a * color.a * 255).round());
  }

  @override
  bool operator ==(Object other) =>
      other is IllustrationColours &&
      other.ink == ink &&
      other.paper == paper &&
      other.shade == shade &&
      other.line == line &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(ink, paper, shade, line, accent);
}
