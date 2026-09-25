import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/guest_limits.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/models/subject.dart';
import '../core/widgets/load_error.dart';

class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paragon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 22),
            tooltip: 'Dashboard',
            // The dashboard is home ('/') now, so this navigates rather
            // than pushing a second copy on top of the subject list.
            onPressed: () => context.go('/'),
          ),
          // Entry point to the course index pages. Kept alongside the
          // existing grid rather than replacing it — this screen is
          // unchanged otherwise.
          TextButton(
            onPressed: () => context.push('/courses'),
            child: const Text(
              'Courses',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/waec'),
            child: const Text(
              'WAEC Prep',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(subjectsProvider),
        ),
        data: (subjects) => subjects.isEmpty
            ? const Center(child: Text('No subjects yet.'))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: subjects.length,
                  itemBuilder: (context, i) =>
                      _SubjectCard(subject: subjects[i], isGuest: isGuest),
                ),
              ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final bool isGuest;
  const _SubjectCard({required this.subject, required this.isGuest});

  /// Matches the WAEC subject list, via the same rule. Before this, a
  /// guest was locked out of Physics in exam mode and free to drill it
  /// here — the same product, two answers.
  bool get _locked =>
      GuestLimits.locks(isGuest: isGuest, subjectName: subject.name);

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSubject(subject.name);
    return GestureDetector(
      onTap: _locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(GuestLimits.lockedSubjectMessage)),
            )
          : () => context.push('/subject/${subject.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha((0.12 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.4 * 255).round())),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                if (_locked)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Colors.white38,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              subject.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _locked ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _locked ? 'Sign in to unlock' : '${subject.unitCount} units',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
