import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import 'read_meter.dart';

/// A small pill in the corner of a debug build showing billed Firestore
/// reads: on this screen, and since the last reset. Tap it to copy a
/// per-screen table for `docs/audit/QUOTA.md` (also printed to the
/// console); long-press to reset before measuring a flow.
///
/// Returns [child] unchanged outside debug builds.
class ReadMeterOverlay extends StatelessWidget {
  const ReadMeterOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    final meter = ReadMeter.instance;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned(
          left: 8,
          bottom: 8,
          child: ListenableBuilder(
            listenable: meter,
            builder: (context, _) => GestureDetector(
              onTap: () {
                final report = meter.report();
                debugPrint(report);
                Clipboard.setData(ClipboardData(text: report));
              },
              onLongPress: meter.reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  border: Border.all(color: context.palette.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'reads ${meter.onScreen} · ${meter.total}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
