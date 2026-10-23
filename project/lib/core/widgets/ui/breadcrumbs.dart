import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// One step of a [Breadcrumbs] trail. The last is the current page and
/// has no [onTap].
class Crumb {
  const Crumb(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;
}

/// Where this page sits: "Courses / Mathematics / Number and Numeration".
/// Each step up is a focusable link; the last names the current page.
/// Wraps onto a second line on a narrow screen rather than overflowing.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs(this.crumbs, {super.key});

  final List<Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      label: 'Breadcrumb',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: p.onLow,
                  ),
                ),
              ),
            if (crumbs[i].onTap == null)
              Semantics(
                // "Current page", in words a screen reader says.
                container: true,
                label: '${crumbs[i].label}, current page',
                excludeSemantics: true,
                child: Text(
                  crumbs[i].label,
                  style: AppTheme.label.copyWith(
                    color: p.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Semantics(
                link: true,
                child: InkWell(
                  onTap: crumbs[i].onTap,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: Text(
                      crumbs[i].label,
                      style: AppTheme.label.copyWith(
                        color: p.primaryFg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
