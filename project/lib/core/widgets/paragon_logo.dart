import 'package:flutter/material.dart';

/// The Project Paragon lockup, in the version that reads on the current
/// theme. The only thing that draws the logo.
///
/// There are two files because the wordmark's letters are a solid colour:
/// white in [darkAsset], for the dark theme, which would vanish on the
/// light theme's near-white background; black in [lightAsset]. The orange
/// brackets, triangles and purple hexagon are the same in both.
class ParagonLogo extends StatelessWidget {
  const ParagonLogo({
    super.key,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  /// White letters, for dark backgrounds. Also the source of the app icons
  /// (`tool/make_icons.dart`).
  static const darkAsset = 'assets/images/paragon_logo.png';

  /// Black letters, for light backgrounds.
  static const lightAsset = 'assets/images/paragon_logo_light.png';

  static String assetFor(Brightness brightness) =>
      brightness == Brightness.light ? lightAsset : darkAsset;

  final double? height;
  final BoxFit fit;

  /// Null when an ancestor already labels it (a "home" button).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetFor(Theme.of(context).brightness),
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
