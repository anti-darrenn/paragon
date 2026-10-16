import 'package:flutter/material.dart';

import 'load_error.dart';

/// A screen whose code is downloaded the first time it is opened.
///
/// The studio, live quiz rooms, the WAEC exam, settings, onboarding and the
/// other screens a student opens rarely or never are `deferred as` imports
/// in the router, so the first visit downloads less (audit F1).
///
/// **Every deferred prefix must be loaded through its own `loadLibrary`
/// before any of its code runs**, even when another prefix's load has
/// already downloaded the same code: compiled JavaScript checks each
/// prefix, and using one that was never loaded throws ("Deferred library
/// … was not loaded"), which renders a blank screen. So loads are shared
/// by [load] itself — `waec_setup.loadLibrary` and `waec_exam.loadLibrary`
/// are separate entries — never by a group name. Grouping them by name
/// once let the exam reuse the setup screen's load and go blank.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});

  /// The deferred prefix's `loadLibrary`, the one whose code [builder] uses.
  final Future<void> Function() load;
  final WidgetBuilder builder;

  static final Map<Future<void> Function(), Future<void>> _loads = {};

  /// Forgets every load. A widget test's futures belong to that test, so
  /// tests start clean.
  @visibleForTesting
  static void resetLoads() => _loads.clear();

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future = _start();

  Future<void> _start() =>
      DeferredScreen._loads.putIfAbsent(widget.load, widget.load);

  // The same element can be rebuilt for another library (one route
  // replacing another in place); its old load proves nothing about this one.
  @override
  void didUpdateWidget(DeferredScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _future = _start();
  }

  void _retry() {
    DeferredScreen._loads.remove(widget.load);
    setState(() => _future = _start());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) {
          return widget.builder(context);
        }
        return Scaffold(
          body: snap.hasError
              ? LoadError(error: snap.error!, onRetry: _retry)
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
