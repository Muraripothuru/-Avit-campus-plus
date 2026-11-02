import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/campus_content.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';

/// Full content of one campus announcement.
///
/// The bookmark toggle is owned by the announcements list (which stays
/// mounted underneath this pushed route), so the list's bookmark state and
/// this screen always agree — the toggle updates both in one tap.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    required this.bookmarked,
    required this.onToggleBookmark,
  });

  final Announcement announcement;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Announcement',
        subtitle: announcement.category,
        actions: <Widget>[
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            onPressed: onToggleBookmark,
            icon: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: bookmarked ? AppColors.tangerine : null,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    AVITStatusChip(
                      label: announcement.category,
                      tone: AVITStatusTone.brand,
                      compact: true,
                    ),
                    Text(
                      Formatters.dayLong.format(announcement.date),
                      style: text.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(announcement.title, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Text(announcement.detail, style: text.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
