import 'package:flutter/material.dart';

import 'load_error.dart';

/// A screen whose code is downloaded the first time it is opened.
///
/// The studio, live quiz rooms, the WAEC exam, settings, onboarding and the
/// other screens a student opens rarely or never are `deferred as` imports
/// in the router, so the first visit downloads less (audit F1). Each
/// library loads once per session; [id] names it, so every route into the
/// same library shares one download.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.id,
    required this.load,
    required this.builder,
  });

  final String id;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  static final Map<String, Future<void>> _loads = {};

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future = _start();

  Future<void> _start() =>
      DeferredScreen._loads.putIfAbsent(widget.id, widget.load);

  void _retry() {
    DeferredScreen._loads.remove(widget.id);
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
