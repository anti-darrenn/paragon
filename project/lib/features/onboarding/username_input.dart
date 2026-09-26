import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';

enum UsernameAvailability { unknown, checking, free, taken }

/// The state behind a [UsernameInput]: what was typed, whether it is
/// valid, and whether it looked free. Shared by the onboarding step and
/// the change-username screen so the two cannot drift apart.
///
/// The availability check is **advisory**: it is debounced and can always
/// be stale by submit time. The transaction in `UserRepository` decides;
/// [markTaken] records a refusal from it.
class UsernameInputController extends ChangeNotifier {
  final text = TextEditingController();

  UsernameAvailability availability = UsernameAvailability.unknown;
  String? validationError;
  String? submitError;

  String get raw => text.text.trim();

  bool get canSubmit =>
      raw.isNotEmpty &&
      validationError == null &&
      availability != UsernameAvailability.taken &&
      availability != UsernameAvailability.checking;

  String? get message {
    if (submitError != null) return submitError;
    if (validationError != null) return validationError;
    if (availability == UsernameAvailability.taken) {
      return 'That username is already taken.';
    }
    return null;
  }

  /// Runs the rules now, for a submit that did not wait for typing to
  /// settle. Returns whether the value passed.
  bool validateNow() {
    validationError = UsernameRules.validate(raw);
    notifyListeners();
    return validationError == null;
  }

  void markTaken(String message) {
    availability = UsernameAvailability.taken;
    submitError = message;
    notifyListeners();
  }

  /// Tells listeners that [UsernameInput] changed the fields above.
  void changed() => notifyListeners();

  void setSubmitError(String? message) {
    submitError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// The @handle field with live validation and a debounced availability
/// check (300ms, spec §2.1).
class UsernameInput extends StatefulWidget {
  const UsernameInput({
    super.key,
    required this.controller,
    required this.isAvailable,
    this.autofocus = false,
    this.onSubmitted,
  });

  final UsernameInputController controller;

  /// Whether a normalised key is free for this student to take.
  final Future<bool> Function(String key) isAvailable;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<UsernameInput> createState() => _UsernameInputState();
}

class _UsernameInputState extends State<UsernameInput> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _debounceTimer;

  /// Guards against a slow earlier check landing after a newer one and
  /// overwriting its result.
  int _checkSequence = 0;

  UsernameInputController get _c => widget.controller;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounceTimer?.cancel();
    _c.submitError = null;
    _c.validationError = raw.trim().isEmpty
        ? null // don't scold someone mid-type on an empty field
        : UsernameRules.validate(raw);
    _c.availability = UsernameAvailability.unknown;
    _c.changed();

    if (_c.validationError != null || raw.trim().isEmpty) return;
    _debounceTimer = Timer(_debounce, () => _checkAvailability(raw));
  }

  Future<void> _checkAvailability(String raw) async {
    final key = UsernameRules.normalise(raw);
    final sequence = ++_checkSequence;
    _c.availability = UsernameAvailability.checking;
    _c.changed();

    try {
      final free = await widget.isAvailable(key);
      if (!mounted || sequence != _checkSequence) return;
      _c.availability = free
          ? UsernameAvailability.free
          : UsernameAvailability.taken;
    } catch (_) {
      // A failed check is not a failed username — stay quiet and let the
      // transaction at submit time be the judge.
      if (!mounted || sequence != _checkSequence) return;
      _c.availability = UsernameAvailability.unknown;
    }
    _c.changed();
  }

  Widget? _suffixIcon() => switch (_c.availability) {
    UsernameAvailability.checking => const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textSecondaryDark,
        ),
      ),
    ),
    UsernameAvailability.free => const Icon(
      Icons.check_circle_rounded,
      color: AppColors.correct,
      size: 20,
    ),
    UsernameAvailability.taken => const Icon(
      Icons.cancel_rounded,
      color: AppColors.wrong,
      size: 20,
    ),
    UsernameAvailability.unknown => null,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingTextField(
            controller: _c.text,
            label: 'USERNAME',
            hintText: 'chidi_99',
            prefixText: '@',
            autofocus: widget.autofocus,
            maxLength: UsernameRules.maxLength,
            onChanged: _onChanged,
            onSubmitted: (_) {
              if (_c.canSubmit) widget.onSubmitted?.call();
            },
            suffix: _suffixIcon(),
          ),
          const SizedBox(height: 10),
          Text(
            '${UsernameRules.minLength}–${UsernameRules.maxLength} characters. '
            'Letters, numbers and underscores.',
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          if (_c.availability == UsernameAvailability.free) ...[
            const SizedBox(height: 8),
            Text(
              '@${_c.raw} is available.',
              style: AppTheme.caption.copyWith(color: AppColors.correct),
            ),
          ],
        ],
      ),
    );
  }
}
