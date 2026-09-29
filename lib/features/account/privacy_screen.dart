import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';

/// Privacy policy presented in short, readable sections.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<({IconData icon, String title, String body})> _sections =
      <({IconData icon, String title, String body})>[
    (
      icon: Icons.badge_rounded,
      title: 'What we collect',
      body: 'Your name, institutional email, student ID, programme and '
          'semester for identity. Attendance, passes and complaint history '
          'are linked to that identity so services work for you.',
    ),
    (
      icon: Icons.location_on_rounded,
      title: 'Location data',
      body: 'Location is shared only when you explicitly raise an emergency '
          'and switch on location sharing. It is transmitted to the security '
          'control room for that request only and never used for tracking.',
    ),
    (
      icon: Icons.camera_alt_rounded,
      title: 'Camera access',
      body: 'The camera is used only while the QR scanner screen is open — '
          'to verify gate and visitor passes. Frames are processed on device '
          'and never stored or uploaded.',
    ),
    (
      icon: Icons.fingerprint_rounded,
      title: 'Biometrics',
      body: 'Fingerprint or face data stays with your device OS. The app '
          'only receives a yes/no result and never sees or stores biometric '
          'templates.',
    ),
    (
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      body: 'Announcements, event reminders and pass updates are sent to '
          'your device. You can turn each category off in Settings.',
    ),
    (
      icon: Icons.storage_rounded,
      title: 'How data is stored',
      body: 'Sessions and preferences are stored in encrypted platform '
          'storage. In live mode, data is served over HTTPS from the campus '
          'API with short-lived access tokens and refresh rotation.',
    ),
    (
      icon: Icons.group_rounded,
      title: 'Who can see your data',
      body: 'Students see their own records. Wardens see hostel-related '
          'requests, security sees pass and gate records, and administrators '
          'see aggregate campus data. Every privileged access is written to '
          'an audit log.',
    ),
    (
      icon: Icons.delete_forever_rounded,
      title: 'Retention & deletion',
      body: 'Operational records are retained per institutional policy. You '
          'may request correction or deletion of your profile data by '
          'emailing campusplus@avit.ac.in.',
    ),
    (
      icon: Icons.lock_rounded,
      title: 'Your controls',
      body: 'Review active sessions and revoke them from Login activity, '
          'manage notification categories in Settings, and withdraw '
          'biometric sign-in at any time.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AVITAppBar(
        title: 'Privacy policy',
        subtitle: 'Last updated 1 September 2026',
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Plain-language summary', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'We collect only what the campus needs to teach, protect '
                  'and support you. Nothing is sold, nothing is used for '
                  'advertising, and every privileged access is logged.',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final section in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AVITCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(section.icon, color: AppColors.royalBlue),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(section.title, style: text.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(section.body, style: text.bodySmall),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AVITStatusChip(
            label: 'Questions? campusplus@avit.ac.in',
            tone: AVITStatusTone.info,
            icon: Icons.mail_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
