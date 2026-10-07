import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/auth/access_policy.dart';
import '../core/routes/app_routes.dart';
import '../core/services/connectivity_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/snackbar.dart';
import '../features/activities/activities_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/campus/campus_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/staff/admin_dashboard_screen.dart';
import '../features/staff/announcements_screen.dart';
import '../features/staff/audit_log_screen.dart';
import '../features/staff/security_dashboard_screen.dart';
import '../features/staff/warden_dashboard_screen.dart';
import '../models/user.dart';
import '../widgets/avit_app_bar.dart';
import '../widgets/avit_avatar.dart';
import '../widgets/avit_bottom_nav.dart';
import '../widgets/avit_drawer.dart';

/// Main authenticated scaffold.
///
/// Implements the required structure:
/// `Scaffold → AppBar + Drawer + Body + FloatingActionButton + BottomNavigationBar`
/// and switches content with `currentIndex` / `onTap` / `setState()`.
///
/// The tab set is role-specific: students see the campus sections while
/// security, warden and admin each get their own desk as the home tab, so
/// staff never see student options and students never see staff ones.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static int tabIndexForRoute(String route, UserRole? role) {
    final List<AppTab> tabs = AppTab.tabsFor(role ?? UserRole.student);
    final int index = tabs.indexWhere((AppTab t) => t.route == route);
    return index < 0 ? 0 : index;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex = widget.initialIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _switching = false;

  /// The signed-in role's tab set — recomputed on every access so a role
  /// change (sign-in/sign-out) can never leave a stale tab selected.
  List<AppTab> _tabsFor(BuildContext context) =>
      AppTab.tabsFor(AppScope.of(context).state.user?.role ?? UserRole.student);

  AppTab _tabOf(List<AppTab> tabs) =>
      _currentIndex < tabs.length ? tabs[_currentIndex] : tabs.first;

  /// Demonstrates `setState()` for content switching, as required.
  void _selectTab(int index) {
    if (index == _currentIndex || _switching) return;
    setState(() {
      _currentIndex = index;
      _switching = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _switching = false);
    });
  }

  void _handleDrawerNavigation(String route) {
    Navigator.of(_scaffoldKey.currentContext ?? context).pop();
    if (Routes.protected.contains(route)) {
      final List<AppTab> tabs = _tabsFor(context);
      final int index = tabs.indexWhere((AppTab t) => t.route == route);
      if (index >= 0) {
        _selectTab(index);
      } else if (ModalRoute.of(context)?.settings.name != route) {
        Navigator.of(context).pushNamed(route);
      }
    }
  }

  /// Contextual FAB: quick actions on Home, role tools on staff desks.
  void _handleFab() {
    switch (_tabOf(_tabsFor(context)).route) {
      case Routes.dashboard:
        _showQuickActions();
      case Routes.activities:
        AppScope.of(context).state.addReminder();
        showAVITSnackBar(
          context,
          message: 'Reminder created for your upcoming events',
          tone: AVITSnackTone.success,
        );
      case Routes.alerts:
        ScaffoldMessenger.of(context).clearSnackBars();
        showAVITSnackBar(
          context,
          message: 'All notifications marked as read',
          tone: AVITSnackTone.success,
        );
      case Routes.campus:
        Navigator.of(context).pushNamed(Routes.emergency);
      case Routes.profile:
        Navigator.of(context).pushNamed(Routes.settings);
      case Routes.security:
        Navigator.of(context).pushNamed(Routes.reportIncident);
      case Routes.warden:
        Navigator.of(context).pushNamed(Routes.complaints);
      default:
        break;
    }
  }

  void _showQuickActions() {
    final UserRole role =
        AppScope.of(context).state.user?.role ?? UserRole.student;
    final List<(IconData, String, String)> actions =
        <(IconData, String, String)>[
          (Icons.qr_code_scanner_rounded, 'Scan a pass', Routes.scanner),
          (Icons.qr_code_rounded, 'Gate pass', Routes.gatePass),
          (Icons.directions_bus_rounded, 'Transport', Routes.transport),
          (Icons.hourglass_top_rounded, 'Smart queue', Routes.smartQueue),
          (Icons.map_rounded, 'Campus map', Routes.campusMap),
          (Icons.emergency_rounded, 'Emergency', Routes.emergency),
        ].where((action) => AccessPolicy.allows(role, action.$3)).toList();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Jump straight into a campus service',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.95,
                children: <Widget>[
                  for (final (IconData icon, String label, String route)
                      in actions)
                    InkWell(
                      borderRadius: AppRadius.card,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed(route);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.paleBlue,
                          borderRadius: AppRadius.card,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(icon, color: AppColors.royalBlue, size: 26),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final String? error = scope.state.lastError;
    final int unread = scope.state.deps.localStore.unreadNotifications;
    final AppUser? me = scope.state.user;

    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        scope.state.clearError();
        showAVITSnackBar(context, message: error, tone: AVITSnackTone.error);
      });
    }

    final List<AppTab> tabs = _tabsFor(context);
    if (_currentIndex >= tabs.length) _currentIndex = 0;
    final AppTab tab = _tabOf(tabs);

    final List<Widget> pages = <Widget>[
      for (final AppTab t in tabs)
        switch (t) {
          AppTab.home => const DashboardScreen(key: ValueKey<String>('home')),
          AppTab.campus => const CampusScreen(key: ValueKey<String>('campus')),
          AppTab.activities => const ActivitiesScreen(
            key: ValueKey<String>('activities'),
          ),
          AppTab.securityDesk => const SecurityDashboardScreen(
            key: ValueKey<String>('security'),
            embedded: true,
          ),
          AppTab.wardenDesk => const WardenDashboardScreen(
            key: ValueKey<String>('warden'),
            embedded: true,
          ),
          AppTab.adminDesk => const AdminDashboardScreen(
            key: ValueKey<String>('admin'),
            embedded: true,
          ),
          AppTab.announcements => const AnnouncementsScreen(
            key: ValueKey<String>('announcements'),
            embedded: true,
          ),
          AppTab.auditLog => const AuditLogScreen(
            key: ValueKey<String>('audit'),
            embedded: true,
          ),
          AppTab.alerts => const AlertsScreen(key: ValueKey<String>('alerts')),
          AppTab.profile => const ProfileScreen(
            key: ValueKey<String>('profile'),
          ),
        },
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AVITAppBar(
        title: tab.label,
        subtitle: scope.state.user?.programme.isEmpty ?? true
            ? null
            : _subtitleFor(tab),
        showLogo: true,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (BuildContext ctx) => IconButton(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).pushNamed(Routes.search),
            icon: const Icon(Icons.search_rounded),
          ),
          AVITBadgeButton(
            icon: Icons.notifications_rounded,
            count: unread,
            onPressed: () => _selectTab(tabs.indexOf(AppTab.alerts)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => _selectTab(tabs.indexOf(AppTab.profile)),
              icon: me == null
                  ? const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.lightBlue,
                      child: Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppColors.royalBlue,
                      ),
                    )
                  : AVITAvatar(user: me, radius: 16),
            ),
          ),
        ],
      ),
      drawer: AVITDrawer(
        currentRoute: tab.route,
        onNavigate: _handleDrawerNavigation,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Always mounted: the banner listens to ConnectivityService and
            // collapses itself when the connection returns, so the
            // "back online" transition is never missed.
            _OfflineBanner(connectivity: scope.state.deps.connectivity),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> anim) {
                  final bool reduce = MediaQuery.disableAnimationsOf(context);
                  if (reduce) return child;
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.015),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: pages[_currentIndex],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(tab),
      bottomNavigationBar: AVITBottomNavigation(
        tabs: tabs,
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }

  String _subtitleFor(AppTab tab) => switch (tab) {
    AppTab.home => _greetingLabel,
    AppTab.campus => 'Services & facilities',
    AppTab.activities => 'Events, clubs and reminders',
    AppTab.securityDesk => 'Gate, passes & incidents',
    AppTab.wardenDesk => 'Hostel approvals & welfare',
    AppTab.adminDesk => 'Campus-wide control centre',
    AppTab.announcements => 'Publish campus updates',
    AppTab.auditLog => 'Security audit trail',
    AppTab.alerts => 'Notifications & emergencies',
    AppTab.profile => 'Your AVIT account',
  };

  String get _greetingLabel {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget? _buildFab(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return FloatingActionButton(
          tooltip: 'Quick actions',
          onPressed: _handleFab,
          child: const Icon(Icons.bolt_rounded),
        );
      case AppTab.activities:
        return FloatingActionButton.extended(
          tooltip: 'Create reminder',
          onPressed: _handleFab,
          icon: const Icon(Icons.add_alert_rounded),
          label: const Text('Reminder'),
        );
      case AppTab.alerts:
        return FloatingActionButton(
          tooltip: 'Mark all as read',
          onPressed: _handleFab,
          child: const Icon(Icons.done_all_rounded),
        );
      case AppTab.campus:
        return FloatingActionButton(
          tooltip: 'Emergency',
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.white,
          onPressed: _handleFab,
          child: const Icon(Icons.emergency_rounded),
        );
      case AppTab.profile:
        return FloatingActionButton(
          tooltip: 'Settings',
          onPressed: _handleFab,
          child: const Icon(Icons.settings_rounded),
        );
      case AppTab.securityDesk:
        return FloatingActionButton.extended(
          tooltip: 'Report incident',
          onPressed: _handleFab,
          icon: const Icon(Icons.report_problem_rounded),
          label: const Text('Incident'),
        );
      case AppTab.wardenDesk:
        return FloatingActionButton.extended(
          tooltip: 'Complaints',
          onPressed: _handleFab,
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Complaints'),
        );
      case AppTab.adminDesk:
      case AppTab.announcements:
      case AppTab.auditLog:
        return null;
    }
  }
}

/// Persistent connectivity strip.
///
/// Mounted for the lifetime of the shell and driven by a [ListenableBuilder]
/// over [ConnectivityService], so it appears and disappears without waiting
/// for an unrelated rebuild. Offers a manual retry for connections the
/// platform still reports as up (captive portals, dropped Wi-Fi).
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({required this.connectivity});

  final ConnectivityService connectivity;

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  late bool _wasOffline = !widget.connectivity.isOnline;
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    bool online;
    try {
      online = await widget.connectivity.refresh();
    } catch (_) {
      online = widget.connectivity.isOnline;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    showAVITSnackBar(
      context,
      message: online
          ? 'Back online — everything is up to date'
          : 'Still offline. Check your Wi-Fi or mobile data.',
      tone: online ? AVITSnackTone.success : AVITSnackTone.warning,
    );
  }

  void _announceReturn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Back online — everything is up to date',
        tone: AVITSnackTone.success,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.connectivity,
      builder: (BuildContext context, Widget? _) {
        final bool offline = !widget.connectivity.isOnline;
        final bool justReturned = _wasOffline && !offline;
        _wasOffline = offline;

        if (offline) {
          return Container(
            width: double.infinity,
            color: AppColors.warningSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're offline. Some information may be outdated.",
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.tangerineDeep),
                  ),
                ),
                TextButton(
                  onPressed: _checking ? null : _retry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Try again'),
                ),
              ],
            ),
          );
        }

        if (justReturned) _announceReturn();
        return const SizedBox.shrink();
      },
    );
  }
}
