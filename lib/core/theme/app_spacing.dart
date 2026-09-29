import 'package:flutter/widgets.dart';

/// AVIT BlueFlow uses a strict 8pt spacing system (with 4pt half-steps).
abstract final class AppSpacing {
  static const double unit = 8;

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 56;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets tightPadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: sm,
  );

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);

  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
}

/// Corner radius tokens for the AVIT BlueFlow UI.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius small = BorderRadius.circular(sm);
  static final BorderRadius large = BorderRadius.circular(xl);
  static final BorderRadius pillShape = BorderRadius.circular(pill);
}

/// Elevation / shadow tokens.
abstract final class AppShadow {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x140A1F44),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x240A1F44),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0D0A1F44),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}
