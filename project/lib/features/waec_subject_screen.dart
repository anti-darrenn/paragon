import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/models/subject.dart';

class WaecSubjectScreen extends ConsumerWidget {
  const WaecSubjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WAEC Prep')),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (subjects) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _WaecSubjectTile(subject: subjects[i], isGuest: isGuest),
        ),
      ),
    );
  }
}

class _WaecSubjectTile extends StatelessWidget {
  final Subject subject;
  final bool isGuest;
  const _WaecSubjectTile({required this.subject, required this.isGuest});

  // Spec §2.3.3 guest config restrictions: subject picker locked to
  // Mathematics for guests. This app's "subject picker" is this list
  // (there's no in-setup dropdown, since the subject is already chosen by
  // the time setup opens), so the lock lives here instead.
  bool get _lockedForGuest =>
      isGuest && subject.name.toLowerCase() != 'mathematics';

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSubject(subject.name);
    return ListTile(
      onTap: _lockedForGuest
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to choose your subject.')),
            )
          : () => context.push('/waec/${subject.id}/setup'),
      title: Text(
        subject.name,
        style: TextStyle(
          color: _lockedForGuest ? AppColors.textSecondaryDark : null,
        ),
      ),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _lockedForGuest ? AppColors.textSecondaryDark : color,
          shape: BoxShape.circle,
        ),
      ),
      trailing: _lockedForGuest
          ? const Icon(Icons.lock_outline, color: AppColors.textSecondaryDark)
          : const Icon(Icons.chevron_right),
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
