import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';

/// About screen: identity, version, module list and legal links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<(IconData, String, String)> _modules =
      <(IconData, String, String)>[
    (Icons.school_rounded, 'Academics', 'Timetable, attendance, exams'),
    (Icons.directions_bus_rounded, 'Transport', 'Bus routes and seat booking'),
    (Icons.badge_rounded, 'Gate & visitor passes', 'QR based campus entry'),
    (Icons.qr_code_scanner_rounded, 'Smart verification', 'Scan at the gate'),
    (Icons.queue_music_rounded, 'Smart queue', 'Tokens without the wait'),
    (Icons.emergency_rounded, 'Safety', 'Emergency, incidents, complaints'),
    (Icons.campaign_rounded, 'Announcements', 'Campus-wide updates'),
    (Icons.groups_rounded, 'Clubs & events', 'Never miss a fest'),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(title: 'About', subtitle: AppConstants.appName),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITCard(
            gradient: AppColors.heroGradient,
            borderColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppConstants.appName,
                  style: text.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  AppConstants.tagline,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    AVITStatusChip(
                      label: 'v${AppConstants.appVersion} '
                          '(build ${AppConstants.buildNumber})',
                      tone: AVITStatusTone.brand,
                      compact: true,
                    ),
                    AVITStatusChip(
                      label: 'Stable channel',
                      tone: AVITStatusTone.success,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Institution',
            subtitle: AppConstants.universityName,
          ),
          AVITCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConstants.universityName,
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Puducherry, India • Affiliated to Anna University • '
                  'NAAC accredited.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Campus+ brings academics, campus services, safety and '
                  'administration into a single verified app for students, '
                  'security, wardens and administrators.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(title: 'Modules'),
          AVITCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _modules.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _modules[i].$1,
                      color: AppColors.royalBlue,
                    ),
                    title: Text(_modules[i].$2, style: text.titleSmall),
                    subtitle: Text(_modules[i].$3, style: text.labelSmall),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(title: 'Legal'),
          AVITCard(
            child: Column(
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: Text('Privacy policy', style: text.titleSmall),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, Routes.privacy),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_rounded),
                  title: Text('Open source licenses', style: text.titleSmall),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(context: context),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_rounded),
                  title: Text('Contact support', style: text.titleSmall),
                  subtitle: Text(
                    AppConstants.supportEmail,
                    style: text.labelSmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pushNamed(context, Routes.help),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'Made for the AVIT campus community',
              style: text.labelSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
