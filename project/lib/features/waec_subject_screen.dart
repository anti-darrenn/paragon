import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/repositories/learning_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/models/subject.dart';

class WaecSubjectScreen extends ConsumerWidget {
  const WaecSubjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

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
              _WaecSubjectTile(subject: subjects[i]),
        ),
      ),
    );
  }
}

class _WaecSubjectTile extends StatelessWidget {
  final Subject subject;
  const _WaecSubjectTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSubject(subject.name);
    return ListTile(
      onTap: () => context.push('/waec/${subject.id}/exam'),
      title: Text(subject.name),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      trailing: const Icon(Icons.chevron_right),
      tileColor: Theme.of(context).colorScheme.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}