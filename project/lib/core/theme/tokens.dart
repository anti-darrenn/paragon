/// The scales every screen spaces, rounds and animates by, so pages share
/// one rhythm instead of each choosing its own numbers.
///
/// - [Space]: gaps and padding.
/// - [Radii]: corner radii. Tags and chips are small, buttons, fields and
///   answer options medium, cards, dialogs and sheets large.
/// - [Motion]: durations and the one curve, all zero under reduced motion.
library;

import 'package:flutter/widgets.dart';

/// Spacing steps. Prefer these to a bare number in new code.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii.
abstract final class Radii {
  /// Tags, chips, small controls.
  static const double sm = 8;

  /// Buttons, fields, answer options.
  static const double md = 12;

  /// Cards, dialogs, sheets.
  static const double lg = 16;

  /// Fully round ends.
  static const double pill = 999;
}

/// Whether the device has asked for less motion. On the web this follows
/// the browser's `prefers-reduced-motion`.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Animation durations and the curve they share.
abstract final class Motion {
  /// A state change on one control: a hover, a press, a tick.
  static const fast = Duration(milliseconds: 120);

  /// Something arriving or leaving: a panel, a verdict, a page.
  static const medium = Duration(milliseconds: 220);

  /// A value filling in: a progress bar, a ring.
  static const slow = Duration(milliseconds: 360);

  /// A finish worth marking: a score ring filling, a level changing.
  static const celebrate = Duration(milliseconds: 900);

  static const Curve curve = Curves.easeOutCubic;

  /// [duration], or no time at all when the device asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
