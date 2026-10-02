import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Consistent SnackBar helper — floating, branded and accessible.
void showAVITSnackBar(
  BuildContext context, {
  required String message,
  AVITSnackTone tone = AVITSnackTone.neutral,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final Color accent = switch (tone) {
    AVITSnackTone.success => const Color(0xFF4ADE80),
    AVITSnackTone.error => const Color(0xFFFF8A93),
    AVITSnackTone.warning => const Color(0xFFFFA762),
    AVITSnackTone.neutral => AppColors.skyBlue,
  };

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(_iconFor(tone), size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.navyDeep,
        duration: duration,
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: accent,
                onPressed: onAction ?? () {},
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

enum AVITSnackTone { neutral, success, error, warning }

IconData _iconFor(AVITSnackTone tone) => switch (tone) {
  AVITSnackTone.success => Icons.check_circle_rounded,
  AVITSnackTone.error => Icons.error_rounded,
  AVITSnackTone.warning => Icons.warning_amber_rounded,
  AVITSnackTone.neutral => Icons.info_rounded,
};
