import 'package:flutter/material.dart';

/// Entrance helper: fades [child] in while sliding it up, starting after
/// [delay]. Used for staggered dashboard section reveals.
class AVITFadeUp extends StatelessWidget {
  const AVITFadeUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final int totalMs = duration.inMilliseconds + delay.inMilliseconds;
    final double start = delay.inMilliseconds / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (BuildContext context, double value, Widget? cached) {
        final double v = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - v)),
            child: cached,
          ),
        );
      },
      child: child,
    );
  }
}
