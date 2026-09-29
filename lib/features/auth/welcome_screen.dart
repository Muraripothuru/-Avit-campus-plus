import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Intro splash shown only for unknown routes — the app itself opens
/// straight into the dashboard with no login gate.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _controller,
                              curve: const Interval(0, 0.6),
                            ),
                            child: Text(
                              AppConstants.appName,
                              style: text.headlineMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _controller,
                              curve: const Interval(0.2, 0.8),
                            ),
                            child: Text(
                              AppConstants.universityName,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _CampusIllustration(animation: _controller)),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.4, 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your campus, in your pocket',
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gate passes, attendance, events, transport and '
                        'emergency help — all in one secure app.',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight parallax campus illustration built from shapes — no image
/// assets to download, so it renders instantly.
class _CampusIllustration extends StatelessWidget {
  const _CampusIllustration({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        final double t = animation.value;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double w = constraints.maxWidth;
            final double h = constraints.maxHeight;
            return ClipRRect(
              borderRadius: AppRadius.large,
              child: Container(
                width: w,
                height: h,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -40,
                      top: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 18,
                      child: Opacity(
                        opacity: 0.16 + 0.1 * t,
                        child: const Icon(
                          Icons.school_rounded,
                          size: 140,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - t)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            _block(width: 74, height: 96, t: t, delay: 0.1),
                            _block(width: 54, height: 132, t: t, delay: 0.25),
                            _block(width: 88, height: 78, t: t, delay: 0.4),
                            _block(width: 46, height: 112, t: t, delay: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 26,
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _pill(
                                label: 'Gate Pass',
                                icon: Icons.qr_code_rounded,
                                t: t,
                                delay: 0.35,
                              ),
                              const SizedBox(width: 10),
                              _pill(
                                label: 'Attendance',
                                icon: Icons.pie_chart_rounded,
                                t: t,
                                delay: 0.5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _pill(
                                label: 'Emergency',
                                icon: Icons.emergency_rounded,
                                t: t,
                                delay: 0.65,
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
          },
        );
      },
    );
  }

  Widget _block({
    required double width,
    required double height,
    required double t,
    required double delay,
  }) {
    final double p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - p)),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.22),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required double t,
    required double delay,
  }) {
    final double p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - p)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.pillShape,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.royalBlue),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
