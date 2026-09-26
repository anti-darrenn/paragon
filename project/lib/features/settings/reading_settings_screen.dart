import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/appearance_provider.dart';
import '../../core/providers/reading_settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/math_text.dart';
import '../../core/theme/app_palette.dart';

/// Reading settings — `/settings/reading`.
///
/// Text size, line spacing, reading font and low-data mode, stored on this
/// device (see `reading_settings_provider.dart`). Open to guests: none of
/// it needs an account.
///
/// The preview renders the way lesson articles are asked to render (body
/// height times the spacing multiplier, in the chosen font) and includes a
/// line of maths, because what a larger size does to a fraction is the
/// thing a student most needs to see before committing to it.
class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  static const _textSizeLabels = [
    'Smaller',
    'Default',
    'Large',
    'Larger',
    'Largest',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Reading')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Preview(settings: settings),
                    const SizedBox(height: 24),

                    if (kAppearanceChoiceEnabled)
                      _Section(
                        title: 'Appearance',
                        hint:
                            'The light theme is new. If anything is hard to '
                            'read in it, tell us from Settings → Help with your '
                            'account.',
                        child: _Choices<Appearance>(
                          values: Appearance.values,
                          selected: ref.watch(appearanceProvider),
                          label: (v) => v.label,
                          onSelected: ref.read(appearanceProvider.notifier).set,
                        ),
                      ),

                    _Section(
                      title: 'Text size',
                      hint:
                          'Applies across the whole app, on top of your '
                          "device's own text size.",
                      child: _Choices<int>(
                        values: List.generate(kTextScaleSteps.length, (i) => i),
                        selected: settings.textScaleStep,
                        label: (i) => _textSizeLabels[i],
                        onSelected: notifier.setTextScaleStep,
                      ),
                    ),
                    _Section(
                      title: 'Line spacing',
                      hint: 'Space between lines in lesson articles.',
                      child: _Choices<LineSpacing>(
                        values: LineSpacing.values,
                        selected: settings.lineSpacing,
                        label: (v) => v.label,
                        onSelected: notifier.setLineSpacing,
                      ),
                    ),
                    _Section(
                      title: 'Reading font',
                      hint:
                          'Used for lesson articles. Atkinson Hyperlegible '
                          'keeps look-alike characters such as l, I and 1 '
                          'distinct.',
                      child: _Choices<ReadingFont>(
                        values: ReadingFont.values,
                        selected: settings.font,
                        label: (v) => v.label,
                        onSelected: notifier.setFont,
                      ),
                    ),

                    _LowDataToggle(
                      value: settings.lowDataMode,
                      onChanged: notifier.setLowDataMode,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: settings.isDefault ? null : notifier.reset,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.palette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Reset to defaults',
                          style: AppTheme.btnLabel.copyWith(
                            color: settings.isDefault
                                ? context.palette.textSecondary
                                : context.palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Saved on this device, and with your account when you '
                      'are signed in so they follow you to other devices.',
                      textAlign: TextAlign.center,
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
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

class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final ReadingSettings settings;

  @override
  Widget build(BuildContext context) {
    // Mirrors the contract in lineSpacingProvider / readingFontProvider:
    // the renderer's own body height, multiplied; the font applied on top.
    final body = settings.font.apply(
      AppTheme.bodyLg.copyWith(
        color: context.palette.textPrimary,
        height: 1.6 * settings.lineSpacing.multiplier,
      ),
    );

    return Container(
      key: const ValueKey('reading-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREVIEW',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A quadratic equation has at most two real roots. Il1 and O0 '
            'are the characters most often misread in a hurry.',
            style: body,
          ),
          const SizedBox(height: 10),
          MathText(
            text:
                r'The roots of \(ax^2 + bx + c = 0\) are '
                r'\(x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}\).',
            style: body,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.hint,
    required this.child,
  });

  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A wrapping row of choice chips — wraps rather than scrolls, so the
/// largest text size on a narrow phone still shows every option.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
            showCheckmark: false,
            backgroundColor: context.palette.surface,
            selectedColor: AppColors.primary.withAlpha((0.2 * 255).round()),
            side: BorderSide(
              color: v == selected ? AppColors.primary : context.palette.border,
            ),
            labelStyle: AppTheme.bodyMd.copyWith(
              color: v == selected
                  ? context.palette.textPrimary
                  : context.palette.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _LowDataToggle extends StatelessWidget {
  const _LowDataToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low-data mode',
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lesson videos and images load only when you tap them.',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('low-data-switch'),
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
