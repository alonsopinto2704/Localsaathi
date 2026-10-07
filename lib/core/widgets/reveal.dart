import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Fades [child] in while it rises a few pixels into place, once, when it is
/// first built.
///
/// Siblings pass their [index] to stagger. Delays stop growing after a handful
/// of items so the bottom of a list never lags behind a person who has already
/// started reading. Skipped entirely when the system asks for reduced motion.
///
/// Only use it where the child is built once per load (a `Column`, a
/// `SliverToBoxAdapter`); inside a lazy list, items scrolled back into view
/// would replay the entrance.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const int _maxStaggered = 6;
  static const double _rise = 12;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final Duration delay = AppDurations.stagger * index.clamp(0, _maxStaggered);
    final Duration total = AppDurations.reveal + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      // The interval holds at 0 for the stagger delay, so no timers are needed.
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: AppCurves.enter,
      ),
      child: child,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _rise),
          child: child,
        ),
      ),
    );
  }
}
