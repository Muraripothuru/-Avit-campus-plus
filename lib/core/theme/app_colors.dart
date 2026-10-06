import 'package:flutter/material.dart';

/// AVIT Cobalt & Linen design palette.
///
/// Anchors:
///  * **Cobalt blue** `#185ADB` — every primary surface, button, link and
///    icon. Replaces the old royal-blue/primary-blue pair.
///  * **Tangerine** `#FF8A3D` — the accent: attention/warning ink, selected
///    segments, emblem ring and cover art. Never used for danger, which
///    stays red.
///  * **Cream linen** `#F5F1E8` — the canvas every screen sits on, with
///    warm-white cards floated above it.
///
/// Deliberately restrained: cobalt hierarchy, warm neutral text, cream
/// surfaces. Green = success, tangerine = warning and red is reserved
/// exclusively for danger / emergency states.
abstract final class AppColors {
  // ------------------------------------------------------------- anchors
  static const Color cobalt = Color(0xFF185ADB);
  static const Color tangerine = Color(0xFFFF8A3D);
  static const Color creamLinen = Color(0xFFF5F1E8);

  // ---------------------------------------------------------------- brand
  /// Deep cobalt-navy — the darkest end of the brand ramp.
  static const Color navyDeep = Color(0xFF071B45);

  /// Cobalt navy — hero mid-tone, snack bars, dark accents.
  static const Color navy = Color(0xFF0E2F73);

  /// The cobalt accent: icons, brand tone, status ink.
  static const Color royalBlue = Color(0xFF185ADB);

  /// The cobalt workhorse: buttons, focus rings, selection, indicators.
  static const Color primaryBlue = Color(0xFF185ADB);

  /// Light cobalt — dark-mode primary and highlights.
  static const Color skyBlue = Color(0xFF5E8CF2);

  /// Pale cobalt tints — chips, selected fills, washes.
  static const Color lightBlue = Color(0xFFE3EBFE);
  static const Color paleBlue = Color(0xFFEEF3FE);

  // -------------------------------------------------------------- accent
  /// Tangerine ink — legible orange-brown for notes and small text.
  static const Color tangerineDeep = Color(0xFF8A5B00);

  /// Pale tangerine fill for the accent family.
  static const Color tangerineSurface = Color(0xFFFFEEE0);

  // ------------------------------------------------------------- neutrals
  static const Color white = Color(0xFFFFFFFF);

  /// Cream linen — the app canvas.
  static const Color background = Color(0xFFF5F1E8);

  /// Warm white — cards, bars and inputs floated on the cream canvas.
  static const Color surface = Color(0xFFFFFDF8);

  /// Deeper cream — disabled fills, neutral chips, skeletons. Read against
  /// the [surface] cards so the linen shows through wherever content rests.
  static const Color surfaceMuted = Color(0xFFECE5D5);

  /// Cool cobalt hairline so every card, field and divider carries the
  /// brand colour.
  static const Color border = Color(0xFFDCE4F5);

  /// Warm neutrals so text sits comfortably on cream.
  static const Color textPrimary = Color(0xFF22201A);
  static const Color textSecondary = Color(0xFF6B6558);
  static const Color textTertiary = Color(0xFF736E60);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // --------------------------------------------------------------- status
  static const Color success = Color(0xFF12924F);
  static const Color successSurface = Color(0xFFE4F5EA);

  /// Orange = warning: a deepened tangerine so ink on pale fills stays
  /// readable, while the bright [tangerine] remains the brand accent.
  static const Color warning = Color(0xFFEE7518);
  static const Color warningSurface = Color(0xFFFFEEE0);

  static const Color danger = Color(0xFFD92D3F);
  static const Color dangerSurface = Color(0xFFFFE9EC);
  static const Color info = Color(0xFF2E7BE5);
  static const Color infoSurface = Color(0xFFE6EEFE);

  /// Ink weights for the status colours above: each clears WCAG AA (4.5:1)
  /// on its matching `*Surface`, which the brighter fills do not.
  static const Color successText = Color(0xFF107E44);
  static const Color warningText = tangerineDeep;
  static const Color dangerText = Color(0xFFCD2B3C);
  static const Color infoText = Color(0xFF286AC6);

  // ------------------------------------------------------------- gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0E2F73), Color(0xFF185ADB)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF071B45), Color(0xFF0E2F73), Color(0xFF185ADB)],
  );

  /// Pale cobalt melting into cream — ties the brand ramp to the canvas.
  static const LinearGradient softWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFEAF1FE), Color(0xFFF5F1E8)],
  );

  // ------------------------------------------------------------ elevation
  static const Color shadow = Color(0x140E2F73);
  static const Color shadowStrong = Color(0x240E2F73);

  // ------------------------------------------------------------ dark theme
  static const Color darkBackground = Color(0xFF08122B);
  static const Color darkSurface = Color(0xFF0D1A36);
  static const Color darkCard = Color(0xFF122247);
  static const Color darkBorder = Color(0xFF20345F);
  static const Color darkTextPrimary = Color(0xFFEDF2FA);
  static const Color darkTextSecondary = Color(0xFF9CABC7);
}
