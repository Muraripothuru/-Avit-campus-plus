import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/user.dart';

/// Premium animated navigation drawer with grouped destinations.
class AVITDrawer extends StatelessWidget {
  const AVITDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
  });

  final String currentRoute;
  final ValueChanged<String> onNavigate;

  static const Map<String, List<(_Group, List<(_Item, String)>)>>
  _structure = <String, List<(_Group, List<(_Item, String)>)>>{
    'Main': <(_Group, List<(_Item, String)>)>[
      (_Group('Main'), <(_Item, String)>[
        (_Item('Dashboard', Icons.dashboard_rounded), Routes.dashboard),
        (_Item('Campus', Icons.location_city_rounded), Routes.campus),
        (_Item('Activities', Icons.event_note_rounded), Routes.activities),
        (
          _Item('Notifications', Icons.notifications_rounded),
          Routes.alerts,
        ),
      ]),
    ],
    'Academic': <(_Group, List<(_Item, String)>)>[
      (_Group('Academic'), <(_Item, String)>[
        (_Item('Timetable', Icons.schedule_rounded), Routes.timetable),
        (_Item('Attendance', Icons.pie_chart_rounded), Routes.attendance),
        (_Item('Courses', Icons.menu_book_rounded), Routes.courses),
        (_Item('Examination', Icons.assignment_rounded), Routes.examinations),
        (
          _Item('Academic Calendar', Icons.calendar_month_rounded),
          Routes.academicCalendar,
        ),
      ]),
    ],
    'Campus Services': <(_Group, List<(_Item, String)>)>[
      (_Group('Campus Services'), <(_Item, String)>[
        (_Item('Gate Pass', Icons.qr_code_rounded), Routes.gatePass),
        (_Item('Transport', Icons.directions_bus_rounded), Routes.transport),
        (_Item('Visitor Pass', Icons.badge_rounded), Routes.visitorPass),
        (_Item('Smart Queue', Icons.hourglass_top_rounded), Routes.smartQueue),
        (_Item('Campus Map', Icons.map_rounded), Routes.campusMap),
        (_Item('Library', Icons.local_library_rounded), Routes.library),
        (_Item('Cafeteria', Icons.restaurant_rounded), Routes.cafeteria),
        (_Item('Hostel', Icons.apartment_rounded), Routes.hostel),
      ]),
    ],
    'Safety': <(_Group, List<(_Item, String)>)>[
      (_Group('Safety'), <(_Item, String)>[
        (_Item('Emergency', Icons.emergency_rounded), Routes.emergency),
        (_Item('Security', Icons.local_police_rounded), Routes.security),
        (
          _Item('Report Incident', Icons.report_problem_rounded),
          Routes.reportIncident,
        ),
        (_Item('Complaints', Icons.support_agent_rounded), Routes.complaints),
      ]),
    ],
    'Account': <(_Group, List<(_Item, String)>)>[
      (_Group('Account'), <(_Item, String)>[
        (_Item('Profile', Icons.person_rounded), Routes.profile),
        (_Item('Settings', Icons.settings_rounded), Routes.settings),
        (_Item('Help Centre', Icons.help_rounded), Routes.help),
        (_Item('About AVIT', Icons.info_rounded), Routes.about),
        (
          _Item('Privacy & Security', Icons.shield_rounded),
          Routes.privacy,
        ),
      ]),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final AppUser? user = scope.state.user;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double headerHeight =
        168 + MediaQuery.paddingOf(context).top * 0.2;

    return Drawer(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _DrawerHeader(
              user: user,
              height: headerHeight,
              isDark: isDark,
            ),
            for (final MapEntry<String, List<(_Group, List<(_Item, String)>)>>
                entry
                in _structure.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  entry.key.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              for (final (_Group _, List<(_Item, String)> items)
                  in entry.value) ...<Widget>[
                for (final (_Item item, String route) in items)
                  _DrawerTile(
                    item: item,
                    route: route,
                    selected: currentRoute == route,
                    onTap: () => onNavigate(route),
                  ),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group(this.label);
  final String label;
}

class _Item {
  const _Item(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.user,
    required this.height,
    required this.isDark,
  });

  final AppUser? user;
  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppUser? u = user;

    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Hero(
              tag: 'avit-profile-avatar',
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(u?.fullName ?? 'AV'),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    u?.fullName ?? 'AVIT Student',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u?.displayId ?? '',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (u?.programme != null && u!.programme.isNotEmpty)
                        _shortProgramme(u.programme),
                      if (u?.semester != null) 'Sem ${u!.semester}',
                    ].join(' • '),
                    style: text.labelSmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: text.labelSmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'AV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String _shortProgramme(String programme) {
    final String cleaned = programme
        .replaceAll('B.Tech ', '')
        .replaceAll('M.Tech ', '');
    return cleaned.length > 26 ? '${cleaned.substring(0, 26)}…' : cleaned;
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.item,
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final _Item item;
  final String route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.lightBlue : Colors.transparent,
        borderRadius: AppRadius.small,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          size: 21,
          color: selected ? AppColors.primaryBlue : null,
        ),
        title: Text(
          item.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? AppColors.primaryBlue : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: selected
            ? const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.primaryBlue,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
