import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Premium AVIT splash: logo fade + scale, name slide-up, loader, then
/// a smooth transition into the authentication flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.72, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<Offset> _titleSlide =
      Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _taglineOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited lookups are illegal during initState.
    if (_decided) return;
    _decided = true;
    _decideDestination(AppScope.of(context));
  }

  Future<void> _decideDestination(AppScope scope) async {
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    await scope.state.bootstrap();
    if (!mounted) return;

    final String next = scope.state.isAuthenticated
        ? Routes.dashboard
        : Routes.welcome;
    // Clear whatever stack exists so the app always starts from one root.
    Navigator.of(context)
        .pushNamedAndRemoveUntil(next, (Route<dynamic> route) => false);
  }

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
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 62,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _logoOpacity,
                            child: Text(
                              AppConstants.appName,
                              style: text.displayMedium?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: Text(
                            AppConstants.tagline,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.86),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: Column(
                            children: <Widget>[
                              const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppConstants.universityName,
                                textAlign: TextAlign.center,
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.7),
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
        ),
      ),
    );
  }
}

/// Wrapper used so the outgoing splash can animate out during a route swap.
class SplashScreenAnimatedNext extends StatelessWidget {
  const SplashScreenAnimatedNext({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: const AlwaysStoppedAnimation<double>(1),
    child: child,
  );
}
