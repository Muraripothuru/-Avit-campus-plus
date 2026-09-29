import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../data/repositories/staff_repository.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_feedback.dart';

/// Administrator overview: campus KPIs, trends, users and quick actions.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  AdminStats? _stats;
  List<AppUser> _users = <AppUser>[];

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
      final AdminStats stats = await deps.admin.stats();
      final List<AppUser> users = await deps.admin.users();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load administration data';
        _loading = false;
      });
    }
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    try {
      await AppScope.of(context)
          .state
          .deps
          .admin
          .setUserRole(userId: user.id, role: role.apiValue);
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: '${user.fullName} is now ${role.label}',
        tone: AVITSnackTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      showAVITSnackBar(context,
          message: 'Role update failed', tone: AVITSnackTone.error);
    }
  }

  void _promptRole(AppUser user) {
    final TextTheme text = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Change role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(user.fullName),
            const SizedBox(height: AppSpacing.sm),
            for (final UserRole role in UserRole.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(role.label),
                subtitle: Text(
                  role == user.role ? 'Current role' : '',
                  style: text.labelSmall,
                ),
                trailing: role == user.role
                    ? const Icon(Icons.check_circle_rounded)
                    : const Icon(Icons.radio_button_unchecked_rounded),
                onTap: () {
                  if (role == user.role) return;
                  Navigator.pop(ctx);
                  _changeRole(user, role);
                },
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AdminStats? stats = _stats;

    if (_loading) return const LoadingList(itemCount: 6);
    if (_error != null || stats == null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Administration'),
        body: AVITErrorState(
          message: _error ?? 'No data available',
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Administration',
        subtitle: 'Campus-wide control centre',
        actions: <Widget>[
          IconButton(
            tooltip: 'Audit log',
            onPressed: () => Navigator.pushNamed(context, Routes.auditLog),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              gradient: AppColors.heroGradient,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Students enrolled',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          '${stats.totalStudents}',
                          style: text.headlineMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${stats.activeUsers} active users today',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      AVITStatusChip(
                        label: '${stats.pendingRequests} pending',
                        tone: AVITStatusTone.warning,
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      AVITStatusChip(
                        label: '${stats.emergencyAlerts} alerts',
                        tone: stats.emergencyAlerts == 0
                            ? AVITStatusTone.success
                            : AVITStatusTone.danger,
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Gate passes live',
                    value: '${stats.activeGatePasses}',
                    icon: Icons.badge_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Visitors today',
                    value: '${stats.visitorsToday}',
                    icon: Icons.groups_rounded,
                    tone: AVITStatusTone.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Events running',
                    value: '${stats.events}',
                    icon: Icons.celebration_rounded,
                    tone: AVITStatusTone.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Open complaints',
                    value: '${stats.complaints}',
                    icon: Icons.support_agent_rounded,
                    tone: AVITStatusTone.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Attendance trend',
              subtitle: 'Last 8 weeks, all departments',
            ),
            AVITCard(
              child: TrendLine(
                values: stats.attendanceTrend,
                labels: const <String>['8w', '6w', '4w', '2w', 'Now'],
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Pass activity',
              subtitle: 'Gate passes vs visitors, last 7 days',
            ),
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TrendLine(
                    values: stats.gatePassTrend,
                    color: AppColors.success,
                    fill: false,
                    height: 64,
                    labels: const <String>['Mon', 'Wed', 'Fri', 'Sun'],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TrendLine(
                    values: stats.visitorTrend,
                    color: AppColors.info,
                    fill: false,
                    height: 64,
                    labels: const <String>['Mon', 'Wed', 'Fri', 'Sun'],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Transport usage',
              subtitle: 'Seats booked by route',
            ),
            AVITCard(
              child: Column(
                children: <Widget>[
                  for (final (String route, double usage)
                      in stats.transportUsage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: BarRow(
                        label: route,
                        value: usage,
                        caption: '${(usage * 100).round()}% full',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Quick actions',
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Publish announcement',
                    value: 'Campus wide',
                    icon: Icons.campaign_rounded,
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.announcements),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Audit trail',
                    value: 'Every action',
                    icon: Icons.receipt_long_rounded,
                    tone: AVITStatusTone.info,
                    onTap: () => Navigator.pushNamed(context, Routes.auditLog),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Users',
              subtitle: '${_users.length} accounts • tap to change role',
            ),
            for (final AppUser user in _users)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AVITCard(
                  onTap: () => _promptRole(user),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.lightBlue,
                        child: Text(
                          user.fullName.isEmpty
                              ? '?'
                              : user.fullName
                                  .substring(0, 1)
                                  .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(user.fullName, style: text.titleSmall),
                            Text(user.displayId, style: text.labelSmall),
                          ],
                        ),
                      ),
                      AVITStatusChip(
                        label: user.role.label,
                        tone: user.role == UserRole.admin
                            ? AVITStatusTone.danger
                            : user.role == UserRole.student
                                ? AVITStatusTone.brand
                                : AVITStatusTone.info,
                        compact: true,
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
