import 'package:flutter/widgets.dart';

/// Layout helpers so no screen hard-codes a device size.
///
/// Breakpoints follow a simple phone / large-phone / tablet ladder.
abstract final class Breakpoints {
  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1080;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Number of grid columns for the current width.
  static int gridColumns(BuildContext context, {int max = 4}) {
    final double w = MediaQuery.sizeOf(context).width;
    if (w >= expanded) return max;
    if (w >= medium) return max.clamp(2, 3);
    return 2;
  }

  /// Content max width keeps tablets from stretching cards to the horizon.
  static double contentMaxWidth(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    return w >= large ? 1080 : w;
  }
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  double get statusBarHeight => MediaQuery.paddingOf(this).top;
  bool get isTablet => Breakpoints.isTablet(this);
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
