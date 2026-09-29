import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Circular progress ring used for attendance and queue progress.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
    this.label,
    this.center,
    this.tone,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String? label;
  final Widget? center;
  final Color? tone;
  final Duration duration;

  Color get _color {
    if (tone != null) return tone!;
    if (value >= 0.85) return AppColors.success;
    if (value >= 0.75) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: reduce ? value.clamp(0, 1) : 0, end: value.clamp(0, 1)),
        duration: reduce ? Duration.zero : duration,
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double animated, Widget? child) =>
            Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                _color.withValues(alpha: 0.18),
              ),
            ),
            CircularProgressIndicator(
              value: animated,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
            if (center != null)
              Center(child: center)
            else if (label != null)
              Center(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight line chart drawn with a custom painter (no chart package).
class TrendLine extends StatelessWidget {
  const TrendLine({
    super.key,
    required this.values,
    this.height = 84,
    this.color = AppColors.primaryBlue,
    this.fill = true,
    this.labels = const <String>[],
  });

  final List<double> values;
  final double height;
  final Color color;
  final bool fill;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: height, child: const SizedBox.shrink());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double t, Widget? _) =>
                CustomPaint(
              painter: _LinePainter(
                values: values,
                progress: t,
                color: color,
                fill: fill,
              ),
              size: Size(double.infinity, height),
            ),
          ),
        ),
        if (labels.length == values.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels
                  .map(
                    (String l) => Text(
                      l,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.fill,
  });

  final List<double> values;
  final double progress;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double min = values.reduce((double a, double b) => a < b ? a : b);
    final double max = values.reduce((double a, double b) => a > b ? a : b);
    final double range = (max - min) == 0 ? 1 : (max - min);

    final List<Offset> points = <Offset>[
      for (int i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height - ((values[i] - min) / range) * (size.height - 8) - 4,
        ),
    ];

    final int visible = (points.length * progress).round().clamp(2, points.length);
    final List<Offset> shown = points.sublist(0, visible);

    final Path line = Path()..moveTo(shown.first.dx, shown.first.dy);
    for (final Offset p in shown) {
      line.lineTo(p.dx, p.dy);
    }

    if (fill) {
      final Path area = Path.from(line)
        ..lineTo(shown.last.dx, size.height)
        ..lineTo(shown.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(shown.last, 4, Paint()..color = color);
    canvas.drawCircle(
      shown.last,
      7,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress || old.values != values;
}

/// Horizontal comparison bar used in admin analytics.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.color = AppColors.royalBlue,
  });

  final String label;
  final double value; // 0..1
  final String? caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                caption ?? '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? _) =>
                  LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
