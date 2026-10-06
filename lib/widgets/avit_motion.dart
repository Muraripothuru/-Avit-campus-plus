import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

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

/// Cover ring: a single accent stroke races once around [child]'s rounded
/// border — a comet head with a soft glow and a fading tail — then the whole
/// ring dissolves. Used on the dashboard Quick Services tiles.
///
/// The sweep is deliberately finite (unlike a looping template): it stops
/// ticking on its own, so widget tests never wait on a repeating ticker.
class AVITRingSweep extends StatelessWidget {
  const AVITRingSweep({
    super.key,
    required this.child,
    this.accent = AppColors.royalBlue,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1150),
    this.inset = 3,
  });

  final Widget child;

  /// Stroke colour of the sweep; usually the tile's accent.
  final Color accent;

  /// How long to wait after first build before the sweep starts.
  final Duration delay;

  /// Sweep travel time (excluding [delay]).
  final Duration duration;

  /// Distance in pixels the ring is pulled inside the child's edge.
  final double inset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final int totalMs = duration.inMilliseconds + delay.inMilliseconds;
    final double start = delay.inMilliseconds / totalMs;

    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: totalMs),
              curve: Interval(start, 1, curve: Curves.easeInOutCubic),
              builder: (BuildContext context, double value, Widget? _) =>
                  CustomPaint(
                    painter: _RingSweepPainter(
                      progress: value.clamp(0.0, 1.0),
                      accent: accent,
                      inset: inset,
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingSweepPainter extends CustomPainter {
  const _RingSweepPainter({
    required this.progress,
    required this.accent,
    required this.inset,
  });

  final double progress;
  final Color accent;
  final double inset;

  /// Envelope: quick fade-in, hold, then dissolve over the last quarter.
  static double _envelope(double t) {
    const double fadeIn = 0.08;
    const double fadeOut = 0.74;
    if (t <= fadeIn) {
      return (t / fadeIn).clamp(0.0, 1.0);
    }
    if (t >= fadeOut) {
      return ((1 - (t - fadeOut) / (1 - fadeOut))).clamp(0.0, 1.0);
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || size.isEmpty) return;

    final Rect rect = (Offset.zero & size).deflate(inset);
    if (rect.isEmpty) return;

    final Path path = Path()..addRRect(AppRadius.card.toRRect(rect));
    final List<PathMetric> metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final PathMetric metric = metrics.first;
    final double total = metric.length;
    if (total <= 0) return;

    final double head = total * progress;
    final double tailStart = math.max(0.0, head - total * 0.30);
    final double headStart = math.max(0.0, head - total * 0.05);
    final double a = _envelope(progress);
    if (a <= 0.001) return;

    // Fading tail behind the head.
    final Paint trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.26 * a);
    canvas.drawPath(metric.extractPath(tailStart, head), trail);

    // Soft glow + bright head.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = accent.withValues(alpha: 0.32 * a);
    canvas.drawPath(metric.extractPath(headStart, head), glow);

    final Paint headPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.95 * a);
    canvas.drawPath(metric.extractPath(headStart, head), headPaint);
  }

  @override
  bool shouldRepaint(_RingSweepPainter old) =>
      progress != old.progress || accent != old.accent || inset != old.inset;
}
