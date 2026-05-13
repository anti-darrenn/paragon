import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/unit.dart';

class UnitListScreen extends ConsumerWidget {
  final String subjectId;
  const UnitListScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider(subjectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Units')),
      body: unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (units) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: units.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _UnitTile(unit: units[i], subjectId: subjectId),
        ),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  final Unit unit;
  final String subjectId;
  const _UnitTile({required this.unit, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/subject/$subjectId/unit/${unit.id}'),
      title: Text(unit.name),
      trailing: const Icon(Icons.chevron_right),
      tileColor: Theme.of(context).colorScheme.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}