import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'avit_metallic_border.dart';

/// Rounded card with soft shadow — the base surface of AVIT BlueFlow.
class AVITCard extends StatelessWidget {
  const AVITCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderRadius,
    this.borderColor,
    this.onTap,
    this.elevation = 0,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double elevation;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = borderRadius ?? AppRadius.card;

    final Widget surface = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (isDark ? AppColors.darkCard : AppColors.white))
            : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ?? (isDark ? AppColors.darkBorder : AppColors.border),
        ),
        boxShadow: elevation > 0 ? AppShadow.raised : AppShadow.subtle,
      ),
      // ListTiles inside the card paint their background and ink on their
      // nearest Material; without this the card's own background would hide
      // them (Flutter raises an assertion in debug builds).
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: surface),
    );
  }
}

/// Card that presses like a physical button (scale + shadow microinteraction).
class AVITAnimatedCard extends StatefulWidget {
  const AVITAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.color,
    this.scaleDown = 0.97,
    this.metallic = false,
    this.metallicAccent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double scaleDown;

  /// Replaces the plain border + shadow with [AVITMetallicBorder].
  final bool metallic;

  /// Accent used by [metallic]; defaults to the brand royal blue.
  final Color? metallicAccent;

  @override
  State<AVITAnimatedCard> createState() => _AVITAnimatedCardState();
}

class _AVITAnimatedCardState extends State<AVITAnimatedCard> {
  bool _pressed = false;

  void _set(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // When [AVITAnimatedCard.metallic] is on the wrapper owns the surface,
    // the glow and the outline, so the container only keeps the padding and
    // reserves the 1px border box to leave the geometry untouched.
    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: widget.metallic
          ? BoxDecoration(
              borderRadius: AppRadius.card,
              border: Border.all(color: const Color(0x00000000)),
            )
          : BoxDecoration(
              color:
                  widget.color ??
                  (isDark ? AppColors.darkCard : AppColors.white),
              borderRadius: AppRadius.card,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              boxShadow: _pressed ? AppShadow.subtle : AppShadow.soft,
            ),
      child: widget.child,
    );

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _set(false);
              widget.onTap?.call();
            },
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.metallic
            ? AVITMetallicBorder(
                accent: widget.metallicAccent ?? AppColors.royalBlue,
                child: card,
              )
            : card,
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class AVITSectionHeader extends StatelessWidget {
  const AVITSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(
      left: AppSpacing.xs,
      right: AppSpacing.xs,
      bottom: AppSpacing.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleLarge),
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
          ),
          if (actionLabel != null)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth * 0.4).clamp(72.0, 220.0),
                    ),
                    child: TextButton(
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}

/// Status pill used for pass states, counters and alerts.
class AVITStatusChip extends StatelessWidget {
  const AVITStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AVITStatusTone.neutral,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final AVITStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      AVITStatusTone.neutral => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
      ),
      AVITStatusTone.info => (AppColors.infoSurface, AppColors.info),
      AVITStatusTone.success => (AppColors.successSurface, AppColors.success),
      AVITStatusTone.warning => (AppColors.warningSurface, AppColors.warning),
      AVITStatusTone.danger => (AppColors.dangerSurface, AppColors.danger),
      AVITStatusTone.brand => (AppColors.lightBlue, AppColors.royalBlue),
    };
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? bg.withValues(alpha: 0.18) : bg,
        borderRadius: AppRadius.pillShape,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

enum AVITStatusTone { neutral, info, success, warning, danger, brand }

/// Compact label + value used across dashboard tiles.
class AVITMetricTile extends StatelessWidget {
  const AVITMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AVITStatusTone.brand,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final AVITStatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (tone) {
      AVITStatusTone.success => AppColors.success,
      AVITStatusTone.warning => AppColors.warning,
      AVITStatusTone.danger => AppColors.danger,
      AVITStatusTone.info => AppColors.info,
      _ => AppColors.primaryBlue,
    };
    return AVITAnimatedCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.small,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
