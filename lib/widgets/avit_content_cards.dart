import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/formatters.dart';
import '../models/announcement.dart';
import '../models/campus_event.dart';
import 'avit_cards.dart';

/// Interactive service tile used on the dashboard and Campus tab.
class AVITServiceCard extends StatelessWidget {
  const AVITServiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.tone = AVITStatusTone.brand,
    this.badge,
    this.imageAsset,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final AVITStatusTone tone;
  final VoidCallback onTap;
  final int? badge;

  /// Example image that fills the entire tile; falls back to [icon].
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (tone) {
      AVITStatusTone.danger => AppColors.danger,
      AVITStatusTone.success => AppColors.success,
      AVITStatusTone.warning => AppColors.warning,
      AVITStatusTone.info => AppColors.info,
      AVITStatusTone.neutral => AppColors.textSecondary,
      AVITStatusTone.brand => AppColors.royalBlue,
    };
    final TextTheme text = Theme.of(context).textTheme;

    if (imageAsset != null) {
      return AVITAnimatedCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double imageHeight =
                ((constraints.maxHeight - 36) * 0.72).clamp(40.0, 88.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: Image.asset(
                        imageAsset!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Icon(icon, color: accent, size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return AVITAnimatedCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const Spacer(),
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: AppRadius.pillShape,
                  ),
                  child: Text(
                    '$badge',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: text.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Event card with cover, meta row and a register action.
class AVITEventCard extends StatelessWidget {
  const AVITEventCard({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onRegister,
    this.onFavourite,
    this.compact = false,
  });

  final CampusEvent event;
  final VoidCallback onOpen;
  final VoidCallback onRegister;
  final VoidCallback? onFavourite;
  final bool compact;

  static const List<(IconData, Color)> _covers = <(IconData, Color)>[
    (Icons.security_rounded, Color(0xFF123C8C)),
    (Icons.cloud_rounded, Color(0xFF1E63E8)),
    (Icons.sports_soccer_rounded, Color(0xFF12924F)),
    (Icons.music_note_rounded, Color(0xFF7C3AED)),
    (Icons.work_rounded, Color(0xFF0F766E)),
    (Icons.smart_toy_rounded, Color(0xFFB45309)),
  ];

  (IconData, Color) get _cover {
    for (final (IconData i, Color c) in _covers) {
      if (event.imageAsset.isNotEmpty &&
          event.imageAsset.toLowerCase().contains(_keyFor(i))) {
        return (i, c);
      }
    }
    return _covers.first;
  }

  static String _keyFor(IconData icon) {
    if (icon == Icons.security_rounded) return 'cyber';
    if (icon == Icons.cloud_rounded) return 'cloud';
    if (icon == Icons.sports_soccer_rounded) return 'sports';
    if (icon == Icons.music_note_rounded) return 'culture';
    if (icon == Icons.work_rounded) return 'career';
    return 'robot';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final (IconData coverIcon, Color coverColor) = _cover;

    return AVITAnimatedCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cover strip — gradient + icon, no heavyweight images.
          Container(
            height: compact ? 84 : 104,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[coverColor, coverColor.withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: 12,
                  bottom: -14,
                  child: Icon(
                    coverIcon,
                    size: 88,
                    color: AppColors.white.withValues(alpha: 0.14),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  top: AppSpacing.sm,
                  child: AVITStatusChip(
                    label: event.category,
                    tone: AVITStatusTone.neutral,
                    compact: true,
                  ),
                ),
                if (onFavourite != null)
                  Positioned(
                    right: 6,
                    top: 4,
                    child: IconButton(
                      tooltip: event.favourite
                          ? 'Remove favourite'
                          : 'Add favourite',
                      onPressed: onFavourite,
                      icon: Icon(
                        event.favourite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                Positioned(
                  left: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  child: Text(
                    event.title,
                    style: text.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.relativeDay(event.startsAt),
                      style: text.bodySmall,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.time.format(event.startsAt),
                      style: text.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    AVITStatusChip(
                      label: event.isFull
                          ? 'Fully booked'
                          : '${event.seatsLeft} seats left',
                      tone: event.isFull
                          ? AVITStatusTone.warning
                          : AVITStatusTone.success,
                      icon: event.isFull
                          ? Icons.hourglass_bottom_rounded
                          : Icons.event_available_rounded,
                      compact: true,
                    ),
                    const Spacer(),
                    if (event.registered)
                      const AVITStatusChip(
                        label: 'Registered',
                        tone: AVITStatusTone.brand,
                        icon: Icons.check_circle_rounded,
                        compact: true,
                      )
                    else
                      TextButton(
                        onPressed: event.isFull ? null : onRegister,
                        child: Text(event.isFull ? 'Full' : 'Register'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Announcement row with category accent.
class AVITAnnouncementCard extends StatelessWidget {
  const AVITAnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  Color get _accent => switch (announcement.category) {
    AnnouncementCategory.exam => AppColors.warning,
    AnnouncementCategory.emergency => AppColors.danger,
    AnnouncementCategory.events => AppColors.royalBlue,
    AnnouncementCategory.hostel => AppColors.info,
    AnnouncementCategory.transport => AppColors.info,
    AnnouncementCategory.security => AppColors.danger,
    AnnouncementCategory.academic => AppColors.primaryBlue,
    AnnouncementCategory.campus => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITAnimatedCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AVITStatusChip(
                      label: announcement.category.label,
                      tone: AVITStatusTone.brand,
                      compact: true,
                    ),
                    if (announcement.pinned) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      Formatters.relativeDay(announcement.publishedAt),
                      style: text.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  announcement.title,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.body,
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed QR pass display with a reveal animation.
class AVITQrPanel extends StatelessWidget {
  const AVITQrPanel({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
    this.size = 200,
  });

  final String data;
  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: text.titleMedium),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.small,
              border: Border.all(color: AppColors.border),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double v, Widget? child) =>
                  Opacity(
                opacity: v.clamp(0, 1),
                child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
              ),
              child: QrImageView(
                data: data,
                size: size,
                backgroundColor: AppColors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.navy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Show this code at the gate',
            style: text.labelMedium,
          ),
        ],
      ),
    );
  }
}
