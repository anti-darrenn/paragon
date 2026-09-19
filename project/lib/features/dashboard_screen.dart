import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final weeklyAsync = ref.watch(weeklyAttemptsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // No hardcoded leading: this screen is the app's home ('/'), where
        // a back arrow pointing at '/' would be a no-op. When it is reached
        // by a push instead, Material's automaticallyImplyLeading supplies
        // a real back button on its own.
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: userDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (userData) {
          final rawStreak = userData?['currentStreak'];
          final streak = rawStreak is int
              ? rawStreak
              : (rawStreak is num ? rawStreak.toInt() : 0);
          // UserRepository stores `displayName: user.displayName ?? ''`, so
          // an anonymous user — and an email sign-up that never set a name
          // — has an empty string here, not null. A null-only fallback
          // therefore greeted them as "Hey,  👋". Treat blank as missing.
          final storedName = (userData?['displayName'] as String?)?.trim();
          final displayName = (storedName == null || storedName.isEmpty)
              ? 'Student'
              : storedName;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ───────────────────────────────────────────
                Text(
                  'Hey, $displayName 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep the streak going.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // ── Stats row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppColors.primary,
                        value: '$streak',
                        label: 'Day streak',
                        sublabel: streak == 0
                            ? 'Start today'
                            : streak == 1
                            ? '1 day'
                            : '$streak days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: weeklyAsync.when(
                        loading: () => const _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '—',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                        error: (e, st) => const _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '0',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                        data: (count) => _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.accentBlue,
                          value: '$count',
                          label: 'This week',
                          sublabel: 'Questions',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Continue practising ────────────────────────────────
                _SectionHeader('Continue Practising'),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.play_circle_filled_rounded,
                  iconColor: AppColors.primary,
                  title: 'Back to Subjects',
                  subtitle: 'Pick a topic and keep drilling',
                  onTap: () => context.go('/subjects'),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.accentBlue,
                  title: 'WAEC Exam Mode',
                  subtitle: 'Timed past-paper practice',
                  onTap: () => context.go('/waec'),
                ),
                const SizedBox(height: 28),

                // ── Accuracy by topic (placeholder) ───────────────────
                _SectionHeader('Accuracy by Topic'),
                const SizedBox(height: 4),
                const SizedBox(height: 10),
                const _AccuracyEmptyState(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String sublabel;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            sublabel,
            style: TextStyle(
              color: iconColor.withAlpha((0.8 * 255).round()),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _AccuracyEmptyState extends StatelessWidget {
  const _AccuracyEmptyState();

  // Replaces a chart that listed five hardcoded topic names — "Quadratic
  // Equations", "Trigonometry" and so on — each showing "No data". They
  // were invented, not read from Firestore: not the user's topics, not
  // even necessarily topics that exist. Per-topic accuracy is real work
  // (it needs topicStats, which nothing writes yet), and until it exists
  // an honest empty state beats a convincing fake one.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_outlined,
                size: 18,
                color: AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 10),
              Text(
                'Nothing to show yet',
                style: AppTheme.bodyLg.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Once you have practised a few topics, your accuracy for each '
            'one will appear here.',
            style: AppTheme.bodyMd.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
