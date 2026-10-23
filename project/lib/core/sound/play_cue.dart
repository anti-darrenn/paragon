import 'package:flutter/widgets.dart';

import 'sfx.dart';

/// Plays [cue] once, when it first appears, and draws [child]. For a moment
/// that is shown rather than tapped: a live quiz's verdict, the podium.
/// Key it by what it marks (the question) so the next one plays again.
///
/// Silent unless the student turned sound effects on, like every cue.
class PlayCue extends StatefulWidget {
  const PlayCue({super.key, required this.cue, required this.child});

  final SfxCue cue;
  final Widget child;

  @override
  State<PlayCue> createState() => _PlayCueState();
}

class _PlayCueState extends State<PlayCue> {
  @override
  void initState() {
    super.initState();
    Sfx.play(widget.cue);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
