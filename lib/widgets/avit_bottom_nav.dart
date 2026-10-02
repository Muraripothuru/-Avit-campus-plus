import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Section shown on each of the five bottom-navigation tabs.
enum AppTab {
  home('Home', Icons.dashboard_rounded, Routes.dashboard),
  campus('Campus', Icons.location_city_rounded, Routes.campus),
  activities('Activities', Icons.event_note_rounded, Routes.activities),
  alerts('Alerts', Icons.notifications_rounded, Routes.alerts),
  profile('Profile', Icons.person_rounded, Routes.profile);

  const AppTab(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// Customised bottom navigation with an animated selection indicator.
class AVITBottomNavigation extends StatelessWidget {
  const AVITBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int unread = AppScope.of(context)
        .state
        .deps
        .localStore
        .unreadNotifications;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F0E2F73),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < AppTab.values.length; i++)
                Expanded(
                  child: _NavTab(
                    tab: AppTab.values[i],
                    selected: i == currentIndex,
                    badge: i == AppTab.values.indexOf(AppTab.alerts)
                        ? unread
                        : 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatefulWidget {
  const _NavTab({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.selected) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _NavTab old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      widget.selected ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) _controller.value = widget.selected ? 1 : 0;

    final Color active = AppColors.primaryBlue;
    final Color inactive = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.textTertiary;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.tab.label,
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            final double t = _controller.value;
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 + 4 * t,
                      vertical: 5 - 1 * t,
                    ),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.transparent,
                        AppColors.lightBlue,
                        t,
                      ),
                      borderRadius: AppRadius.pillShape,
                    ),
                    child: Badge(
                      isLabelVisible: widget.badge > 0,
                      label: Text('${widget.badge}'),
                      backgroundColor: AppColors.danger,
                      child: Icon(
                        widget.tab.icon,
                        size: 22,
                        color: Color.lerp(inactive, active, t),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.tab.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: Color.lerp(inactive, active, t),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
