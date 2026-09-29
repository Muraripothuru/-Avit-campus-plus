import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/announcement.dart';
import '../../models/app_notification.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Notifications, campus announcements and the always-visible emergency card.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;

  List<AppNotification> _items = <AppNotification>[];
  List<Announcement> _announcements = <Announcement>[];
  NotificationCategory? _filter;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<AppNotification> notes = await deps.activities.notifications();
      final List<Announcement> anns = await deps.content.announcements();
      if (!mounted) return;
      setState(() {
        _items = notes;
        _announcements = anns;
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
        _error = 'Unable to load notifications';
        _loading = false;
      });
    }
  }

  List<AppNotification> get _visible => _filter == null
      ? _items
      : _items
          .where((AppNotification n) => n.category == _filter)
          .toList(growable: false);

  int get _unread => _items.where((AppNotification n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return AVITErrorState(message: _error!, onRetry: _load);
    }

    return AVITRefresh(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          _EmergencyCard(unread: _unread),
          const SizedBox(height: AppSpacing.md),
          AVITSectionHeader(
            title: 'Notifications',
            subtitle: _unread == 0
                ? "You're all caught up"
                : '$_unread unread notification${_unread == 1 ? '' : 's'}',
            actionLabel: _unread == 0 ? null : 'Mark all read',
            onAction: _unread == 0 ? null : _markAllRead,
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final (String, NotificationCategory?) chip
                    in <(String, NotificationCategory?)>[
                      ('All', null),
                      ('Academic', NotificationCategory.academic),
                      ('Events', NotificationCategory.events),
                      ('Security', NotificationCategory.security),
                      ('Hostel', NotificationCategory.hostel),
                      ('Transport', NotificationCategory.transport),
                      ('System', NotificationCategory.system),
                    ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(chip.$1),
                      selected: _filter == chip.$2,
                      onSelected: (_) => setState(() => _filter = chip.$2),
                      selectedColor: AppColors.lightBlue,
                      labelStyle: text.labelMedium?.copyWith(
                        color: _filter == chip.$2 ? AppColors.primaryBlue : null,
                        fontWeight: _filter == chip.$2
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: _filter == chip.$2
                            ? AppColors.primaryBlue
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillShape,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_visible.isEmpty)
            const AVITEmptyState(
              title: 'Nothing in this category',
              message: 'New updates will arrive here.',
              icon: Icons.notifications_paused_rounded,
            )
          else
            for (final AppNotification n in _visible)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _NotificationTile(
                  notification: n,
                  onOpen: () => _open(n),
                  onDelete: () => _delete(n),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Announcements',
            subtitle: 'Published by AVIT administration',
          ),
          if (_announcements.isEmpty)
            const AVITEmptyState(
              title: 'No announcements',
              message: 'Official notices will show up here.',
              icon: Icons.campaign_rounded,
            )
          else
            for (final Announcement a in _announcements)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AVITAnnouncementCard(
                  announcement: a,
                  onTap: () => _showAnnouncement(a),
                ),
              ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _open(AppNotification n) async {
    if (n.read) return;
    final AppDependencies deps = AppScope.of(context).state.deps;
    await deps.activities.markRead(n.id);
    if (!mounted) return;
    setState(() {
      final int i = _items.indexWhere((AppNotification x) => x.id == n.id);
      if (i >= 0) _items[i] = _items[i].copyWith(read: true);
    });
    if (n.actionRoute != null && Routes.protected.contains(n.actionRoute)) {
      if (!mounted) return;
      Navigator.pushNamed(context, n.actionRoute!);
    }
  }

  Future<void> _markAllRead() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    await deps.activities.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((AppNotification n) => n.copyWith(read: true))
          .toList();
    });
    showAVITSnackBar(
      context,
      message: 'All notifications marked as read',
      tone: AVITSnackTone.success,
    );
  }

  Future<void> _delete(AppNotification n) async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    await deps.activities.delete(n.id);
    if (!mounted) return;
    setState(() => _items.removeWhere((AppNotification x) => x.id == n.id));
    showAVITSnackBar(
      context,
      message: 'Notification removed',
      tone: AVITSnackTone.neutral,
      actionLabel: 'Undo',
    );
  }

  void _showAnnouncement(Announcement a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AVITStatusChip(
              label: a.category.label,
              tone: AVITStatusTone.brand,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(a.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${a.author} • ${Formatters.dayLong.format(a.publishedAt)}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(a.body, style: Theme.of(ctx).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: 'Close',
              variant: AVITButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF8C1024), Color(0xFFD92D3F)],
      ),
      borderColor: Colors.transparent,
      onTap: () => Navigator.pushNamed(context, Routes.emergency),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Emergency assistance',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Security, medical, fire and women safety — one tap.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            children: <Widget>[
              const Icon(
                Icons.phone_in_talk_rounded,
                color: AppColors.white,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.emergencyNumber,
                style: text.labelMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unread > 0) ...<Widget>[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: AppRadius.pillShape,
                  ),
                  child: Text(
                    '$unread new',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onOpen,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  IconData get _icon => switch (notification.category) {
    NotificationCategory.academic => Icons.school_rounded,
    NotificationCategory.events => Icons.event_rounded,
    NotificationCategory.security => Icons.shield_rounded,
    NotificationCategory.hostel => Icons.apartment_rounded,
    NotificationCategory.transport => Icons.directions_bus_rounded,
    NotificationCategory.system => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool unread = !notification.read;

    return Dismissible(
      key: ValueKey<String>(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: AppRadius.card,
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      child: AVITCard(
        color: unread ? AppColors.lightBlue : null,
        onTap: onOpen,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: unread ? AppColors.white : AppColors.surfaceMuted,
                borderRadius: AppRadius.small,
              ),
              child: Icon(_icon, size: 20, color: AppColors.royalBlue),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AVITStatusChip(
                        label: notification.category.label,
                        tone: AVITStatusTone.brand,
                        compact: true,
                      ),
                      const Spacer(),
                      Text(
                        Formatters.relativeDay(notification.receivedAt),
                        style: text.labelSmall,
                      ),
                      if (unread) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: text.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
