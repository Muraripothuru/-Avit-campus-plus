import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/avit_app_bar.dart';
import '../widgets/avit_inputs.dart';

/// 404-style fallback that names the route which could not be opened.
///
/// Reached through `onUnknownRoute` / the `onGenerateRoute` fallback whenever
/// an unregistered route name is pushed, so the student can see exactly which
/// name failed instead of a silent redirect.
class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key, required this.routeName});

  /// The unregistered route name, shown verbatim on screen.
  final String routeName;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    // Safe back control: only offer the button when a route can be popped.
    final bool canGoBack = Navigator.canPop(context);

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Page not found',
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '404',
                style: text.displayLarge?.copyWith(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This route does not exist',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.small,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(routeName, style: text.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.xl),
              AVITButton(
                label: 'Go to dashboard',
                icon: Icons.home_rounded,
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.dashboard,
                  (Route<dynamic> route) => false,
                ),
              ),
              if (canGoBack) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                AVITButton(
                  label: 'Go back',
                  icon: Icons.arrow_back_rounded,
                  variant: AVITButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
