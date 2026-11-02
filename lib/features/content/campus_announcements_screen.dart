import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/announcement.dart' as repo show Announcement;
import '../../models/campus_content.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import 'announcement_detail_screen.dart';

/// Student Announcements: every campus bulletin with its category, date and
/// a preview line, plus a per-item bookmark toggle.
///
/// The bookmark set lives on this screen's [State], so the list stays
/// mounted under the pushed [AnnouncementDetailScreen] and a round trip
/// through the detail route never loses a bookmark.
class CampusAnnouncementsScreen extends StatefulWidget {
  const CampusAnnouncementsScreen({super.key});

  @override
  State<CampusAnnouncementsScreen> createState() =>
      _CampusAnnouncementsScreenState();
}

class _CampusAnnouncementsScreenState
    extends State<CampusAnnouncementsScreen> {
  bool _loading = true;
  String? _error;
  bool _started = false;
  List<Announcement> _items = <Announcement>[];

  /// Bookmarked announcement IDs.
  final Set<String> _bookmarkedIds = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<repo.Announcement> source = await deps.content.announcements();
      if (!mounted) return;
      setState(() {
        _items = source.isEmpty
            ? List<Announcement>.of(demoAnnouncements)
            : source.map(_map).toList(growable: false);
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load announcements';
        _loading = false;
      });
    }
  }

  static Announcement _map(repo.Announcement a) => Announcement(
    id: a.id,
    title: a.title,
    category: a.category.label,
    date: a.publishedAt,
    preview: _firstSentence(a.body),
    detail: a.body,
  );

  static String _firstSentence(String body) {
    final int end = body.indexOf('. ');
    if (end < 0) return body;
    return body.substring(0, end + 1);
  }

  void _toggleBookmark(String id) {
    setState(() {
      if (!_bookmarkedIds.add(id)) _bookmarkedIds.remove(id);
    });
  }

  Future<void> _openDetail(Announcement announcement) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => AnnouncementDetailScreen(
          announcement: announcement,
          bookmarked: _bookmarkedIds.contains(announcement.id),
          onToggleBookmark: () => _toggleBookmark(announcement.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingList(itemCount: 6);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Announcements'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Announcements',
        subtitle: 'Published by AVIT administration',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView.builder(
          padding: AppSpacing.screenPadding,
          itemCount: _items.length,
          itemBuilder: (BuildContext context, int index) {
            final Announcement announcement = _items[index];
            return _AnnouncementRow(
              announcement: announcement,
              bookmarked: _bookmarkedIds.contains(announcement.id),
              onToggleBookmark: () => _toggleBookmark(announcement.id),
              onTap: () => _openDetail(announcement),
            );
          },
        ),
      ),
    );
  }
}

/// One announcement: category accent, chip, date, title, preview and the
/// trailing bookmark toggle.
class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.announcement,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.onTap,
  });

  final Announcement announcement;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  static Color _accentFor(String category) => switch (category) {
    'Examination' => AppColors.warning,
    'Emergency' => AppColors.danger,
    'Events' => AppColors.royalBlue,
    'Hostel' => AppColors.info,
    'Transport' => AppColors.info,
    'Security' => AppColors.danger,
    'Academic' => AppColors.primaryBlue,
    'Campus' => AppColors.success,
    _ => AppColors.primaryBlue,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AVITCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: _accentFor(announcement.category),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    AVITStatusChip(
                      label: announcement.category,
                      tone: AVITStatusTone.brand,
                      compact: true,
                    ),
                    Text(
                      Formatters.relativeDay(announcement.date),
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
                const SizedBox(height: 2),
                Text(
                  announcement.preview,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            visualDensity: VisualDensity.compact,
            onPressed: onToggleBookmark,
            icon: Icon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 22,
              color: bookmarked ? AppColors.tangerine : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
