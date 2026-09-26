import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/lessons/lesson_check.dart';
import '../../../core/lessons/lesson_doc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Lists what is wrong with the lesson body as it is typed: broken maths,
/// unclosed blocks, quick checks without one right answer, leftover to-dos.
///
/// Rechecked half a second after typing stops, not on every keystroke —
/// parsing every maths span is cheap but not free.
class ProblemsPanel extends StatefulWidget {
  const ProblemsPanel({super.key, required this.body});

  final TextEditingController body;

  @override
  State<ProblemsPanel> createState() => _ProblemsPanelState();
}

class _ProblemsPanelState extends State<ProblemsPanel> {
  List<LessonIssue> _issues = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _issues = checkLesson(widget.body.text);
    widget.body.addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.body.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _issues = checkLesson(widget.body.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    final errors = _issues
        .where((i) => i.severity == IssueSeverity.error)
        .length;
    final colour = _issues.isEmpty
        ? AppColors.correct
        : errors > 0
        ? AppColors.wrong
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colour.withAlpha(120)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _issues.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.report_outlined,
                size: 16,
                color: colour,
              ),
              const SizedBox(width: 8),
              Text(
                _issues.isEmpty
                    ? 'NO PROBLEMS'
                    : '${_issues.length} PROBLEM${_issues.length == 1 ? '' : 'S'}',
                style: AppTheme.label.copyWith(color: colour),
              ),
            ],
          ),
          for (final i in _issues.take(20))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Line ${i.line}: ${i.message}',
                style: AppTheme.caption.copyWith(
                  color: i.severity == IssueSeverity.error
                      ? AppColors.wrong
                      : AppColors.warning,
                ),
              ),
            ),
          if (_issues.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '…and ${_issues.length - 20} more',
                style: AppTheme.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
