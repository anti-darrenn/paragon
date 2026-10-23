import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// "Continue with Google", as Google's branding asks: the multi-colour G,
/// and Google's own colours for a light or a dark page. Used wherever a
/// student can sign in or upgrade with Google.
///
/// It replaced a grey button with a 4px radius that read as disabled next
/// to the orange one, and whose text vanished in the light theme.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  /// Null disables it.
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? AppColors.googleButtonOnDark : AppColors.googleButtonOnLight;
    return Semantics(
      label: loading ? '$label, loading' : null,
      excludeSemantics: loading,
      button: true,
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: c.fill,
            foregroundColor: c.text,
            disabledBackgroundColor: c.fill,
            disabledForegroundColor: c.text.withAlpha(140),
            side: BorderSide(color: c.stroke),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: loading
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.text,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/google_g.png',
                      width: 22,
                      height: 22,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.btnLabel.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
