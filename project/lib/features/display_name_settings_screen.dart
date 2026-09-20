import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/repositories/user_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'onboarding/onboarding_scaffold.dart';

/// Change your display name — `/settings/name`.
///
/// Display name is the one identity field that was always meant to be
/// changeable and never was. Username is permanent by design — the
/// reservation in `usernames/{key}` cannot be released, and the rules make
/// it immutable once set — but a display name is just what the app calls
/// you, it is not unique, and nothing depends on its stability. There was
/// simply no screen.
///
/// It is required rather than optional, matching the onboarding step:
/// `resolveOnboardingStep` treats a blank display name as an outstanding
/// step, so saving an empty one here would drop the student back into the
/// funnel on their next navigation.
class DisplayNameSettingsScreen extends ConsumerStatefulWidget {
  const DisplayNameSettingsScreen({super.key});

  @override
  ConsumerState<DisplayNameSettingsScreen> createState() =>
      _DisplayNameSettingsScreenState();
}

class _DisplayNameSettingsScreenState
    extends ConsumerState<DisplayNameSettingsScreen> {
  final _controller = TextEditingController();

  /// Filled from the user document once, then left alone — a later
  /// snapshot must not overwrite what the student is typing.
  bool _hydrated = false;

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final userData = userDataAsync.asData?.value;
    if (!_hydrated && userData != null) {
      _hydrated = true;
      _controller.text = (userData['displayName'] as String?)?.trim() ?? '';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Display name')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What Paragon calls you. It does not have to be unique, '
                    'and you can change it whenever you like.',
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OnboardingTextField(
                    controller: _controller,
                    label: 'DISPLAY NAME',
                    hintText: 'Your name',
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save',
                              style: AppTheme.btnLabel.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Pick a name to go by.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .setDisplayName(uid: user.uid, displayName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved.')));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save that. Please try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
