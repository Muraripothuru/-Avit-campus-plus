import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/academics.dart';
import '../../models/announcement.dart';
import '../../models/campus_event.dart';
import '../../data/repositories/content_repository.dart';
import '../../models/user.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Student home dashboard: greeting, today's schedule, attendance, quick
/// services, announcements and upcoming events.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  bool _started = false;

  List<TimetableEntry> _today = <TimetableEntry>[];
  List<Announcement> _announcements = <Announcement>[];
  List<CampusEvent> _events = <CampusEvent>[];
  double _attendance = 0;

  @override
  bool get wantKeepAlive => true;

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
      final List<TimetableEntry> all = await deps.content.timetable();
      final List<Announcement> anns = await deps.content.announcements();
      final List<CampusEvent> events = await deps.activities.events();
      final double overall = await deps.content.overallAttendance();
      if (!mounted) return;
      final int weekday = DateTime.now().weekday;
      setState(() {
        _today = all
            .where((TimetableEntry e) => e.weekday == weekday)
            .toList()
          ..sort(
            (TimetableEntry a, TimetableEntry b) =>
                a.startMinutes.compareTo(b.startMinutes),
          );
        _announcements = anns;
        _events = events
            .where((CampusEvent e) => e.startsAt.isAfter(DateTime.now()))
            .take(4)
            .toList();
        _attendance = overall;
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
        _error = 'Unable to load your dashboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppScope scope = AppScope.of(context);
    final AppUser? user = scope.state.user;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return AVITErrorState(message: _error!, onRetry: _load);
    }

    return AVITRefresh(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          _GreetingHeader(user: user),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _TodaySchedule(entries: _today),
              ),
              const SizedBox(width: AppSpacing.md),
              _AttendanceCard(percentage: _attendance),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Quick Services',
            subtitle: 'Everything you use on campus',
          ),
          _QuickServices(announcements: _announcements.length),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Announcements',
            subtitle: 'Latest from AVIT',
            actionLabel: 'See all',
            onAction: () => Navigator.pushNamed(context, Routes.announcements),
          ),
          if (_announcements.isEmpty)
            const AVITEmptyState(
              title: 'No announcements',
              message: 'You are all caught up.',
              icon: Icons.campaign_rounded,
            )
          else
            for (final Announcement a in _announcements.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AVITAnnouncementCard(
                  announcement: a,
                  onTap: () => _showAnnouncement(a),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Upcoming Events',
            subtitle: 'Register before seats run out',
            actionLabel: 'See all',
            onAction: () => Navigator.pushNamed(context, Routes.activities),
          ),
          if (_events.isEmpty)
            const AVITEmptyState(
              title: 'No upcoming events',
              message: 'Check the Activities tab for clubs and notices.',
              icon: Icons.event_rounded,
            )
          else
            for (final CampusEvent e in _events)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AVITEventCard(
                  event: e,
                  onOpen: () => _showEvent(e),
                  onRegister: () => _register(e),
                ),
              ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
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

  void _showEvent(CampusEvent e) {
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
            Text(e.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${Formatters.relativeDay(e.startsAt)} • '
              '${Formatters.time.format(e.startsAt)} • ${e.location}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Organised by ${e.organizer}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Text(e.description, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: e.registered ? 'Registered' : 'Register now',
              loading: false,
              onPressed: e.registered
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _register(e);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register(CampusEvent e) async {
    final ActivityRepository repo = AppScope.of(context).state.deps.activities;
    try {
      final CampusEvent updated = await repo.register(
        eventId: e.id,
      );
      if (!mounted) return;
      setState(() {
        final int i = _events.indexWhere((CampusEvent x) => x.id == e.id);
        if (i >= 0) _events[i] = updated;
      });
      showAVITSnackBar(
        context,
        message: 'Event registration successful',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (err) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: err.userMessage,
        tone: AVITSnackTone.error,
      );
    }
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime now = DateTime.now();

    return AVITCard(
      gradient: AppColors.heroGradient,
      borderColor: Colors.transparent,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${Formatters.greeting(now)}, '
                  '${(user?.fullName ?? 'Student').split(' ').first}',
                  style: text.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.dayLong.format(now),
                  style: text.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.16),
                        borderRadius: AppRadius.pillShape,
                      ),
                      child: Text(
                        (user?.programme ?? 'AVIT').isEmpty
                            ? 'AVIT'
                            : _short(user!.programme),
                        style: text.labelSmall?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    if (user?.semester != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.16),
                          borderRadius: AppRadius.pillShape,
                        ),
                        child: Text(
                          'Sem ${user!.semester}',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const Icon(
                Icons.wifi_rounded,
                color: Color(0xFF4ADE80),
                size: 16,
              ),
              const SizedBox(height: 4),
              Text(
                'Campus online',
                style: text.labelSmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.pillShape,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.badge_rounded,
                      size: 14,
                      color: AppColors.royalBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      user?.studentId ?? '',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _short(String value) {
    final String cleaned = value.replaceAll('B.Tech ', '');
    return cleaned.length > 26 ? '${cleaned.substring(0, 26)}…' : cleaned;
  }
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule({required this.entries});

  final List<TimetableEntry> entries;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TimetableEntry? current = entries
        .where((TimetableEntry e) => e.overlaps(DateTime.now()))
        .cast<TimetableEntry?>()
        .firstWhere((TimetableEntry? e) => e != null, orElse: () => null);

    return AVITCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text("Today's Schedule", style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            Text(
              'No classes scheduled today',
              style: text.bodySmall,
            )
          else
            for (final TimetableEntry e in entries.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: e == current
                            ? AppColors.success
                            : AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 74,
                      child: Text(
                        e.startTime,
                        style: text.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            e.subject,
                            style: text.titleSmall?.copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${e.room} • ${e.faculty}',
                            style: text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      child: Column(
        children: <Widget>[
          Text('Attendance', style: text.titleSmall),
          const SizedBox(height: 10),
          ProgressRing(
            value: percentage / 100,
            size: 88,
            strokeWidth: 9,
            label: '${percentage.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          Text(
            percentage >= 75 ? 'On track' : 'Needs attention',
            style: text.labelSmall?.copyWith(
              color: percentage >= 75
                  ? AppColors.success
                  : AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Required 75%',
            style: text.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickServices extends StatelessWidget {
  const _QuickServices({required this.announcements});

  final int announcements;

  static const List<(IconData, String, String, AVITStatusTone)> _services =
      <(IconData, String, String, AVITStatusTone)>[
        (Icons.qr_code_rounded, 'Gate Pass', Routes.gatePass, AVITStatusTone.brand),
        (Icons.directions_bus_rounded, 'Transport', Routes.transport, AVITStatusTone.brand),
        (Icons.badge_rounded, 'Visitor Pass', Routes.visitorPass, AVITStatusTone.brand),
        (Icons.hourglass_top_rounded, 'Smart Queue', Routes.smartQueue, AVITStatusTone.info),
        (Icons.map_rounded, 'Campus Map', Routes.campusMap, AVITStatusTone.info),
        (Icons.local_library_rounded, 'Library', Routes.library, AVITStatusTone.brand),
        (Icons.emergency_rounded, 'Emergency', Routes.emergency, AVITStatusTone.danger),
        (Icons.support_agent_rounded, 'Help', Routes.help, AVITStatusTone.info),
      ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.82,
      children: <Widget>[
        for (final (IconData icon, String label, String route, AVITStatusTone tone)
            in _services)
          AVITServiceCard(
            title: label,
            icon: icon,
            tone: tone,
            onTap: () => Navigator.pushNamed(context, route),
          ),
      ],
    );
  }
}
