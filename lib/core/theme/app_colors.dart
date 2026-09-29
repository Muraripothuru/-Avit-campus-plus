import 'package:flutter/material.dart';

/// AVIT BlueFlow design palette.
///
/// Deliberately restrained: navy/royal blue hierarchy, white surfaces,
/// soft grey backgrounds. Green = success, orange = warning and red is
/// reserved exclusively for danger / emergency states.
abstract final class AppColors {
  // ---------------------------------------------------------------- brand
  static const Color navy = Color(0xFF0A1F44);
  static const Color navyDeep = Color(0xFF061530);
  static const Color royalBlue = Color(0xFF1E4FD8);
  static const Color primaryBlue = Color(0xFF1565D8);
  static const Color skyBlue = Color(0xFF4E9BFF);
  static const Color lightBlue = Color(0xFFE8F1FF);
  static const Color paleBlue = Color(0xFFF3F7FF);

  // ------------------------------------------------------------- neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF1F7);
  static const Color border = Color(0xFFE1E7F0);

  static const Color textPrimary = Color(0xFF0F1B33);
  static const Color textSecondary = Color(0xFF5B6B85);
  static const Color textTertiary = Color(0xFF8A97AC);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // --------------------------------------------------------------- status
  static const Color success = Color(0xFF12924F);
  static const Color successSurface = Color(0xFFE4F7EC);
  static const Color warning = Color(0xFFF0A11A);
  static const Color warningSurface = Color(0xFFFFF4E0);
  static const Color danger = Color(0xFFD92D3F);
  static const Color dangerSurface = Color(0xFFFFE9EC);
  static const Color info = Color(0xFF2E7BE5);
  static const Color infoSurface = Color(0xFFE8F1FF);

  // ------------------------------------------------------------- gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123C8C), Color(0xFF1E63E8)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1F44), Color(0xFF17419B), Color(0xFF1E63E8)],
  );

  static const LinearGradient softWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEFF5FF), Color(0xFFF5F7FA)],
  );

  // ------------------------------------------------------------ elevation
  static const Color shadow = Color(0x140A1F44);
  static const Color shadowStrong = Color(0x240A1F44);

  // ------------------------------------------------------------ dark theme
  static const Color darkBackground = Color(0xFF060E1E);
  static const Color darkSurface = Color(0xFF0D1830);
  static const Color darkCard = Color(0xFF122244);
  static const Color darkBorder = Color(0xFF1E3159);
  static const Color darkTextPrimary = Color(0xFFEDF2FA);
  static const Color darkTextSecondary = Color(0xFF9AABC4);
}
