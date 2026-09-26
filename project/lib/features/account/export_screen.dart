import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/io/save_file.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// `/settings/export` — download a copy of everything stored about you.
///
/// The right to a copy of your data is one the privacy policy promises,
/// and until now the only way to use it was to email us.
///
/// **Cost.** Every stored answer is one document read, and a keen student
/// has thousands against a shared daily quota of 50,000. So the screen
/// shows the size first (from `count()`, which is nearly free) and allows
/// one export per day on each device. That limit is a courtesy, not a
/// security boundary — someone determined can clear their browser — and
/// is only there to stop a double-tap or a curious reload from spending
/// a tenth of the day's reads twice.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  Future<int>? _size;
  DateTime? _lastExport;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  String _prefsKey(String uid) => 'export.lastAt.$uid';

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    _size = ref.read(accountRepositoryProvider).exportSize(user.uid);
    _loadLast(user.uid);
  }

  Future<void> _loadLast(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefsKey(uid));
      if (ms != null && mounted) {
        setState(() => _lastExport = DateTime.fromMillisecondsSinceEpoch(ms));
      }
    } catch (_) {
      // No storage: no limit. The courtesy is not worth an error.
    }
  }

  Future<void> _export() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await ref
          .read(accountRepositoryProvider)
          .exportOwnedDocuments(user.uid);
      final text = const JsonEncoder.withIndent('  ').convert(data);
      final saved = await saveTextFile(
        fileName: exportFileName(DateTime.now()),
        text: text,
      );
      final now = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsKey(user.uid), now.millisecondsSinceEpoch);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _lastExport = now;
        _messageIsError = false;
        _message = saved == SavedAs.download
            ? 'Downloaded. Look for it in your downloads folder.'
            : 'Copied to your clipboard. Paste it into a file to keep it.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = "Couldn't gather your data. Please try again later.";
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextAllowed = nextExportAllowedAt(_lastExport, now: DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Download your data')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'A copy of everything Paragon stores about you, as one '
                      'file you can open in any text editor:',
                      style: AppTheme.bodyLg.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final line in const [
                      'Your account: username, display name, email, picture, '
                          'bio, subjects and the optional details about you',
                      'Every question you have answered, and when',
                      'Your progress, topic tests and lessons finished',
                      'Your notes, highlights, bookmarks and revision cards',
                      'Problems you have reported',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '•  $line',
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FutureBuilder<int>(
                      future: _size,
                      builder: (context, snap) => Text(
                        snap.hasData
                            ? 'About ${snap.data} records.'
                            : snap.hasError
                            ? ''
                            : 'Counting…',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_message != null) ...[
                      Text(
                        _message!,
                        style: AppTheme.bodyMd.copyWith(
                          color: _messageIsError
                              ? AppColors.wrong
                              : AppColors.correct,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _busy || nextAllowed != null
                            ? null
                            : _export,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.trackDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Download my data',
                                style: AppTheme.btnLabel.copyWith(
                                  color: nextAllowed == null
                                      ? Colors.white
                                      : AppColors.textSecondaryDark,
                                ),
                              ),
                      ),
                    ),
                    if (nextAllowed != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'You downloaded a copy in the last day. You can '
                        'download another tomorrow.',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Null if an export may run now; otherwise when the next one may.
DateTime? nextExportAllowedAt(DateTime? last, {required DateTime now}) {
  if (last == null) return null;
  final next = last.add(const Duration(days: 1));
  return next.isAfter(now) ? next : null;
}

/// `paragon-data-2026-09-26.json`. No name or uid in it: files get
/// attached and forwarded, and the name should not identify anyone.
String exportFileName(DateTime when) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'paragon-data-${when.year}-${two(when.month)}-${two(when.day)}.json';
}
