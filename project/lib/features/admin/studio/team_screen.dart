import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ui/ui.dart';
import '../../../core/auth/staff_role.dart';
import '../../../core/models/subject.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/repositories/staff_invite_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import 'studio_error.dart';

/// `/admin/team`: who writes and reviews, and for which subjects. Admins
/// only; the rules refuse everyone else.
///
/// Saving records a request. `tools/admin/apply_roles.js` applies it
/// within 15 minutes, and the person then signs out and in again to pick
/// it up. See [StaffInviteRepository] for why it can't be instant.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _email = TextEditingController();
  String _role = 'writer';
  bool _allSubjects = true;
  final Set<String> _subjects = {};
  bool _saving = false;
  String? _error;

  /// Whose access the form is changing, once "Change" was chosen on a row.
  /// Null while adding someone. Said above the form, with Cancel: the form
  /// used to refill silently, out of sight at the top of the page.
  String? _editing;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _edit(StaffInvite i) {
    setState(() {
      _editing = i.email;
      _email.text = i.email;
      _role = i.role == 'none' ? 'writer' : i.role;
      _allSubjects = i.subjects.isEmpty;
      _subjects
        ..clear()
        ..addAll(i.subjects);
      _error = null;
    });
  }

  void _cancelEdit() => setState(() {
    _editing = null;
    _email.clear();
    _role = 'writer';
    _allSubjects = true;
    _subjects.clear();
    _error = null;
  });

  Future<void> _save({String? role, String? email}) async {
    final address = (email ?? _email.text).trim();
    if (!looksLikeEmail(address)) {
      setState(() => _error = 'Enter the email address they sign in with.');
      return;
    }
    if (role == null && !_allSubjects && _subjects.isEmpty) {
      setState(
        () => _error = 'Pick at least one subject, or choose All subjects.',
      );
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(staffInviteRepositoryProvider)
          .request(
            email: address,
            role: role ?? _role,
            subjects: role == 'none' || _allSubjects
                ? const []
                : _subjects.toList(),
            requestedBy: uid,
          );
      if (!mounted) return;
      if (email == null) {
        _email.clear();
        setState(() {
          _editing = null;
          _allSubjects = true;
          _subjects.clear();
        });
      }
      showToast(
        context,
        'Saved. It takes effect within 15 minutes; they then sign out and in '
        'again.',
        tone: Tone.success,
      );
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(staffRoleProvider) != StaffRole.admin) {
      return Scaffold(
        appBar: ParagonAppBar(title: const Text('Team')),
        body: const Center(child: Text('Only an admin can manage the team.')),
      );
    }
    final subjects =
        ref.watch(subjectsProvider).asData?.value ?? const <Subject>[];
    final names = {for (final s in subjects) s.id: s.name};
    final invites = ref.watch(staffInvitesProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: const Text('Team')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            children: [
              Text(
                'Writers draft lessons and submit them. Reviewers also publish, send work back, '
                'and handle problem reports. Limit either to some subjects, or allow all. '
                'They need an account first: they sign up in the app like anyone else.',
                style: AppTheme.bodyMd.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                _editing == null ? 'Add someone' : 'Change $_editing',
                action: _editing == null
                    ? null
                    : AppButton(
                        label: 'Cancel',
                        tone: ButtonTone.ghost,
                        size: ButtonSize.sm,
                        onPressed: _cancelEdit,
                      ),
              ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Their email address',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'writer', label: Text('Writer')),
                  ButtonSegment(value: 'reviewer', label: Text('Reviewer')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All subjects'),
                value: _allSubjects,
                onChanged: (v) => setState(() => _allSubjects = v),
              ),
              if (!_allSubjects)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in subjects)
                      FilterChip(
                        label: Text(s.name),
                        selected: _subjects.contains(s.id),
                        onSelected: (on) => setState(
                          () =>
                              on ? _subjects.add(s.id) : _subjects.remove(s.id),
                        ),
                      ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InlineAlert(
                  tone: Tone.danger,
                  message: _error!,
                  announce: true,
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: _editing == null ? 'Add to the team' : 'Save changes',
                  loading: _saving,
                  onPressed: () => _save(),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'The team',
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Everyone added here. Accounts given a role some other way (the '
                'set_role.js script) are not listed.',
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              invites.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) =>
                    StudioError(message: "Couldn't load the team.", error: e),
                data: (list) => list.isEmpty
                    ? Text(
                        'Nobody added yet.',
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      )
                    : Column(
                        children: [
                          for (final i in list)
                            _InviteRow(
                              invite: i,
                              subjectNames: names,
                              onEdit: () => _edit(i),
                              // Both asked first: one takes a person's role
                              // away, the other deletes the record.
                              onRemove: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Remove ${i.email} from the team?',
                                  message:
                                      'Their role is taken away at the next '
                                      'sign-in. Their work stays.',
                                  confirmLabel: 'Remove from the team',
                                  destructive: true,
                                );
                                if (ok)
                                  await _save(role: 'none', email: i.email);
                              },
                              onForget: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Delete this record?',
                                  message:
                                      'The invite for ${i.email} is deleted. '
                                      'It does not change any role already '
                                      'given.',
                                  confirmLabel: 'Delete record',
                                  destructive: true,
                                );
                                if (ok) {
                                  await ref
                                      .read(staffInviteRepositoryProvider)
                                      .forget(i.email);
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.subjectNames,
    required this.onEdit,
    required this.onRemove,
    required this.onForget,
  });

  final StaffInvite invite;
  final Map<String, String> subjectNames;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final removed = invite.role == 'none';
    final scope = invite.subjects.isEmpty
        ? 'all subjects'
        : invite.subjects.map((id) => subjectNames[id] ?? id).join(', ');
    final colour = switch (invite.state) {
      InviteState.applied => AppColors.correct,
      InviteState.error => AppColors.wrong,
      _ => AppColors.warning,
    };
    return Card(
      color: context.palette.surface,
      child: ListTile(
        title: Text(
          invite.email,
          style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
        ),
        subtitle: Text(
          [
            removed
                ? 'Removed from the team'
                : '${invite.role == 'reviewer' ? 'Reviewer' : 'Writer'} · $scope',
            invite.state.label +
                (invite.message.isEmpty ? '' : ': ${invite.message}'),
          ].join('\n'),
          style: AppTheme.caption.copyWith(color: colour),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          color: context.palette.surface,
          onSelected: (v) => switch (v) {
            'edit' => onEdit(),
            'remove' => onRemove(),
            _ => onForget(),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Change')),
            if (!removed)
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove from the team'),
              ),
            if (removed)
              const PopupMenuItem(
                value: 'forget',
                child: Text('Delete this record'),
              ),
          ],
        ),
      ),
    );
  }
}
