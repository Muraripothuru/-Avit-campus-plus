import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Metallic border treatment for AVIT BlueFlow cards.
///
/// Flutter port of the v0 "Metallic Silver Border Card" template: a crisp
/// steel-silver outline, layered metallic glow and a highlight that travels
/// around the edge while the border ripples gently (the template's animated
/// `feDisplacementMap`, approximated here with a phase-shifted sine along the
/// rounded-rect perimeter).
///
/// The template ships in neutral silver (`#c0c0c0`); on AVIT's white cards a
/// pure silver reads as invisible, so the outline uses a cool steel silver
/// (`#97A6BF`) and the travelling highlight carries a royal-blue band
/// (`AppColors.royalBlue`) — the palette the rest of the app is built on.
class AVITMetallicBorder extends StatefulWidget {
  const AVITMetallicBorder({
    super.key,
    required this.child,
    this.surface,
    this.accent = AppColors.royalBlue,
    this.silver = const Color(0xFF97A6BF),
    this.borderRadius,
    this.borderWidth = 1.5,
    this.duration = const Duration(seconds: 6),
    this.elevation = true,
  });

  final Widget child;

  /// Surface the content sits on. Defaults to the theme's card colour.
  final Color? surface;

  /// Drives the glow and the coloured band of the travelling highlight.
  final Color accent;

  /// Base steel colour of the outline.
  final Color silver;

  final BorderRadius? borderRadius;
  final double borderWidth;

  /// One full sweep of the travelling highlight.
  final Duration duration;

  /// Whether the card also casts the standard AVIT soft shadow.
  final bool elevation;

  @override
  State<AVITMetallicBorder> createState() => _AVITMetallicBorderState();
}

class _AVITMetallicBorderState extends State<AVITMetallicBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late _MetallicBorderPainter _painter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _painter = _newPainter();
  }

  @override
  void didUpdateWidget(covariant AVITMetallicBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.accent != widget.accent ||
        oldWidget.silver != widget.silver ||
        oldWidget.borderWidth != widget.borderWidth ||
        oldWidget.borderRadius != widget.borderRadius ||
        oldWidget.duration != widget.duration) {
      _painter = _newPainter();
    }
  }

  _MetallicBorderPainter _newPainter() => _MetallicBorderPainter(
    animation: _controller,
    accent: widget.accent,
    silver: widget.silver,
    radius: widget.borderRadius ?? AppRadius.card,
    borderWidth: widget.borderWidth,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = widget.borderRadius ?? AppRadius.card;
    final Color base =
        widget.surface ?? (isDark ? AppColors.darkCard : AppColors.white);
    final Color shade = (isDark
        ? Color.lerp(base, AppColors.navyDeep, 0.45)!
        : Color.lerp(base, AppColors.navy, 0.05)!);

    return DecoratedBox(
      // Static halo — the template's glow-layer-1/2 + background-glow.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.accent.withValues(alpha: isDark ? 0.45 : 0.22),
            blurRadius: 20,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: widget.silver.withValues(alpha: isDark ? 0.35 : 0.5),
            blurRadius: 5,
          ),
          if (widget.elevation) ...AppShadow.soft,
        ],
      ),
      child: DecoratedBox(
        // Brushed-metal wash across the card surface.
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[base, base, shade],
            stops: const <double>[0, 0.55, 1],
          ),
        ),
        child: CustomPaint(foregroundPainter: _painter, child: widget.child),
      ),
    );
  }
}

class _MetallicBorderPainter extends CustomPainter {
  _MetallicBorderPainter({
    required this.animation,
    required this.accent,
    required this.silver,
    required this.radius,
    required this.borderWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color accent;
  final Color silver;
  final BorderRadius radius;
  final double borderWidth;

  /// Points sampled evenly along the outline; rebuilt only when the size
  /// changes so the per-frame work is a handful of `sin` calls.
  static const int _sampleCount = 144;

  /// Number of ripples that travel once around the edge per cycle.
  static const double _waves = 3;

  Size? _cachedSize;
  List<_EdgeSample>? _cachedEdge;

  static Radius _clampRadius(Radius corner, double max) =>
      Radius.elliptical(math.min(corner.x, max), math.min(corner.y, max));

  Path _basePath(Size size) {
    final Rect rect = (Offset.zero & size).deflate(borderWidth / 2);
    if (rect.width <= 0 || rect.height <= 0) return Path();
    final double maxRadius = math.min(rect.width, rect.height) / 2;
    final RRect rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: _clampRadius(radius.topLeft, maxRadius),
      topRight: _clampRadius(radius.topRight, maxRadius),
      bottomLeft: _clampRadius(radius.bottomLeft, maxRadius),
      bottomRight: _clampRadius(radius.bottomRight, maxRadius),
    );
    return Path()..addRRect(rrect);
  }

  List<_EdgeSample> _edgeFor(Size size) {
    final List<_EdgeSample>? cached = _cachedEdge;
    if (cached != null && _cachedSize == size && cached.isNotEmpty) {
      return cached;
    }
    final List<_EdgeSample> out = <_EdgeSample>[];
    final Path path = _basePath(size);
    for (final PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      for (int i = 0; i < _sampleCount; i++) {
        final Tangent? tangent = metric.getTangentForOffset(
          length * i / _sampleCount,
        );
        if (tangent == null) continue;
        out.add(
          _EdgeSample(
            tangent.position,
            Offset(tangent.vector.dy, -tangent.vector.dx),
          ),
        );
      }
      break;
    }
    _cachedSize = size;
    _cachedEdge = out;
    return out;
  }

  Path _wavePath(List<_EdgeSample> edge, double t, Size size) {
    final int count = edge.length;
    final double amplitude = math.min(2.4, size.shortestSide * 0.035);
    final double phase = t * math.pi * 2;
    final Path path = Path();
    for (int i = 0; i < count; i++) {
      final _EdgeSample sample = edge[i];
      final double wave = math.sin((i / count) * math.pi * 2 * _waves + phase);
      final Offset point = sample.position + sample.normal * (wave * amplitude);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Shader _highlight(Rect rect, double t) => LinearGradient(
    colors: <Color>[
      const Color(0xFFFBFDFF),
      const Color(0xFFC3CEE0),
      accent.withValues(alpha: 0.9),
      const Color(0xFF7E8DA9),
      const Color(0xFFE3E9F4),
      const Color(0xFFFBFDFF),
    ],
    stops: const <double>[0, 0.18, 0.38, 0.55, 0.78, 1],
    transform: GradientRotation(-math.pi / 6 + t * math.pi * 2),
  ).createShader(rect);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final List<_EdgeSample> edge = _edgeFor(size);
    if (edge.length < 3) return;

    final double t = animation.value;
    final Path wavePath = _wavePath(edge, t, size);
    final Path basePath = _basePath(size);

    // Soft halo behind the outline — the template's two glow layers.
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = silver.withValues(alpha: 0.28),
    );

    // The solid metallic outline the ripple travels over.
    canvas.drawPath(
      basePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = silver.withValues(alpha: 0.85),
    );

    // Travelling highlight with the royal-blue band.
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = _highlight(Offset.zero & size, t),
    );
  }

  @override
  bool shouldRepaint(covariant _MetallicBorderPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.silver != silver ||
      oldDelegate.radius != radius ||
      oldDelegate.borderWidth != borderWidth;
}

class _EdgeSample {
  const _EdgeSample(this.position, this.normal);

  final Offset position;
  final Offset normal;
}
