import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/repositories/user_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'onboarding/profile_form.dart';

/// Edit the optional profile — `/settings/profile`.
///
/// The onboarding step has told students "you can edit it later in
/// settings" since it shipped, with nothing behind it: Settings had no
/// editor, and while the router does permit `/onboarding/profile` after
/// the funnel, nothing linked there. This is the screen that sentence was
/// describing.
///
/// It imports the form from `onboarding/` rather than the other way round.
/// The fields belong to the onboarding step that defines them; this screen
/// is the second reader, and sharing them is what stops the two drifting
/// into showing different questions.
///
/// **Clearing a field deletes it.** Every field here is optional and this
/// is data about students who are largely minors, so emptying a box has to
/// mean "remove this", not "leave what you had". `updateProfile` is the
/// method that does that; `setProfile`, which onboarding uses, deliberately
/// does not.
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _form = ProfileFormController();

  /// The form is filled from the user document once it arrives, and never
  /// again — re-hydrating on a later snapshot would overwrite whatever the
  /// student had begun typing.
  bool _hydrated = false;

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final userData = userDataAsync.asData?.value;
    if (!_hydrated && userData != null) {
      _hydrated = true;
      _form.hydrate(userData['profile']);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('About you')),
      body: SafeArea(
        child: userDataAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          children: [
                            Text(
                              'All optional. Clearing a box deletes what we '
                              'hold for it.',
                              style: AppTheme.bodyMd.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ProfileFormFields(
                              controller: _form,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'We use this to shape what Paragon covers. It '
                              'is never sent to analytics and never shown to '
                              'other students — see the Privacy Policy.',
                              style: AppTheme.caption.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _error!,
                            style: AppTheme.bodyMd.copyWith(
                              color: AppColors.wrong,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
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
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .updateProfile(uid: user.uid, profile: _form.toProfile());
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
