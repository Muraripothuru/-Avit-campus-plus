import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Customised AVIT AppBar: logo mark, optional subtitle, actions and a
/// scroll-aware elevation. Used by every top-level screen for consistency.
class AVITAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AVITAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showLogo = false,
    this.actions = const <Widget>[],
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.pinned = false,
    this.onRefresh,
    this.backgroundColor,
    this.fgColor,
  });

  final String title;
  final String? subtitle;
  final bool showLogo;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool pinned;
  final Future<void> Function()? onRefresh;
  final Color? backgroundColor;
  final Color? fgColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: fgColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: text.bodySmall?.copyWith(color: fgColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return AppBar(
      title: showLogo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _LogoMark(size: 30),
                const SizedBox(width: 10),
                Flexible(child: heading),
              ],
            )
          : heading,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: fgColor,
    );
  }
}

/// Circular AVIT monogram used in app bars and the drawer header.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.tangerine,
          width: (size * 0.075).clamp(1.5, 4).toDouble(),
        ),
      ),
      child: Center(
        child: Text(
          'A',
          style: TextStyle(
            color: AppColors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Reusable circular icon button with a notification badge.
class AVITBadgeButton extends StatelessWidget {
  const AVITBadgeButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.count = 0,
    this.tooltip = 'Notifications',
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int count;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (Widget child, Animation<double> a) =>
            ScaleTransition(scale: a, child: child),
        child: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: AppColors.danger,
          child: Icon(icon, key: ValueKey<String>('$icon$count'), size: 23),
        ),
      ),
    );
  }
}
