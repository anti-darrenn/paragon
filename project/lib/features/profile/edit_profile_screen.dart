import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/avatar.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../onboarding/onboarding_scaffold.dart';
import 'avatar_picker.dart';
import '../../core/theme/app_palette.dart';

/// Edit profile — `/settings/name`: avatar, display name and bio.
///
/// The route keeps its old name because it began as the display-name
/// editor, and links to it exist. Username is not here: it has its own
/// rules and its own screen.
///
/// Display name is required, matching the onboarding step:
/// `resolveOnboardingStep` treats a blank one as an outstanding step, so
/// saving an empty name would drop the student back into the funnel.
///
/// The bio is private, like everything on `users/{uid}` — nobody else can
/// read it. The copy says so, because a bio box normally implies an
/// audience.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();

  /// Filled from the user document once, then left alone — a later
  /// snapshot must not overwrite what the student is typing.
  bool _hydrated = false;

  Avatar? _avatar;
  String? _storedAvatar;
  String _storedName = '';
  String _storedBio = '';

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userData = ref.watch(userDataProvider).asData?.value;
    if (!_hydrated && userData != null) {
      _hydrated = true;
      _storedAvatar = userData['avatar'] as String?;
      _storedName = (userData['displayName'] as String?)?.trim() ?? '';
      _storedBio = (userData['bio'] as String?)?.trim() ?? '';
      _avatar = Avatar.parse(_storedAvatar, seed: user?.uid ?? '');
      _name.text = _storedName;
      _bio.text = _storedBio;
    }

    final avatar = _avatar ?? Avatar.parse(null, seed: user?.uid ?? '');
    final initials = initialsFor(
      _name.text,
      fallback: userData?['username'] as String?,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AvatarDisc(
                        avatar: avatar,
                        initials: initials,
                        size: 88,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AvatarPicker(
                      selected: avatar,
                      initials: initials,
                      onChanged: (a) => setState(() => _avatar = a),
                    ),
                    const SizedBox(height: 28),
                    OnboardingTextField(
                      controller: _name,
                      label: 'DISPLAY NAME',
                      hintText: 'Your name',
                      maxLength: 30,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'What Paragon calls you. Not unique; change it whenever '
                      'you like.',
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    OnboardingTextField(
                      controller: _bio,
                      label: 'BIO',
                      hintText: 'Aiming for an A1 in Physics',
                      maxLength: kBioMaxLength,
                      maxLines: 3,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A line about you or what you are working towards. '
                      'Only you can see it. ${_bio.text.trim().length}'
                      '/$kBioMaxLength',
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
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
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Pick a name to go by, at least 2 characters.');
      return;
    }
    final bio = _bio.text.trim();
    if (bio.length > kBioMaxLength) {
      setState(() => _error = 'Keep your bio to $kBioMaxLength characters.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    // Only what changed, so an untouched field costs no write and a
    // snapshot from another device is not overwritten with stale values.
    final repo = ref.read(userRepositoryProvider);
    final avatar = _avatar?.storageValue;
    try {
      if (avatar != null && avatar != _storedAvatar) {
        await repo.setAvatar(uid: user.uid, avatar: avatar);
      }
      if (name != _storedName) {
        await repo.setDisplayName(uid: user.uid, displayName: name);
      }
      if (bio != _storedBio) {
        await repo.setBio(uid: user.uid, bio: bio);
      }
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
