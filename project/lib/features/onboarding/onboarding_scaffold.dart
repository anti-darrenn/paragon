import 'package:flutter/material.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Shared chrome for the onboarding funnel.
///
/// Deliberately *not* built on `ParagonPage`: the funnel must not offer a
/// top nav, a logo link home, or any other way out. The only exits are the
/// primary action and — on the optional last step — a skip link.
///
/// Back navigation is blocked (`PopScope(canPop: false)`), per spec §2.1:
/// a half-finished profile is not a state the app can render.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.isLoading = false,
    this.errorText,
    this.onSkip,
    this.skipLabel = 'Skip for now',
  });

  final OnboardingStep step;
  final String title;
  final String subtitle;
  final Widget child;

  final String primaryLabel;

  /// Null disables the primary button — used while a step's input is not
  /// yet valid.
  final VoidCallback? onPrimary;

  final bool isLoading;
  final String? errorText;

  /// Only the optional steps (avatar, profile) supply this.
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepIndicator(step: step),
                    const SizedBox(height: 28),

                    Text(
                      title,
                      style: AppTheme.displayLg.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: AppTheme.bodyLg.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 28),

                    child,

                    if (errorText != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.wrong,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: AppTheme.bodyMd.copyWith(
                                color: AppColors.wrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : onPrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.trackDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textSecondaryDark,
                                ),
                              )
                            : Text(
                                primaryLabel,
                                style: AppTheme.btnLabel.copyWith(
                                  color: onPrimary == null
                                      ? AppColors.textSecondaryDark
                                      : Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),

                    if (onSkip != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isLoading ? null : onSkip,
                        child: Text(
                          skipLabel,
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Step 2 of 5" plus a segmented bar, one segment per step.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final current = step.stepNumber ?? OnboardingStep.totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step $current of ${OnboardingStep.totalSteps}',
          style: AppTheme.caption.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= OnboardingStep.totalSteps; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppColors.primary
                        : AppColors.trackDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Text field styled for the funnel. Shared so the four steps can't drift.
class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.prefixText,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.onSubmitted,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final String? label;
  final String? prefixText;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          autofocus: autofocus,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: AppTheme.bodyLg.copyWith(color: AppColors.textPrimaryDark),
          decoration: InputDecoration(
            hintText: hintText,
            counterText: '',
            prefixText: prefixText,
            prefixStyle: AppTheme.bodyLg.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            suffixIcon: suffix,
            hintStyle: AppTheme.bodyLg.copyWith(
              color: AppColors.textSecondaryDark.withAlpha(
                (0.6 * 255).round(),
              ),
            ),
            filled: true,
            fillColor: AppColors.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
