import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Preferences: appearance, biometrics, notifications, privacy and account.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _eventReminders = true;
  bool _emailDigest = false;
  bool _busy = false;

  Future<void> _toggleBiometric(bool value) async {
    final AppState state = AppScope.of(context).state;
    setState(() => _busy = true);
    final bool ok = await state.setBiometric(value);
    if (!mounted) return;
    setState(() => _busy = false);
    showAVITSnackBar(
      context,
      message: ok
          ? (value ? 'Biometric sign-in enabled' : 'Biometric sign-in disabled')
          : 'Biometric authentication was cancelled',
      tone: ok ? AVITSnackTone.success : AVITSnackTone.warning,
    );
  }

  Future<void> _signOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your password to sign back in.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).state.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppState state = AppScope.of(context).state;
    final bool biometricOn = state.biometricOptIn;

    return Scaffold(
      appBar: AVITAppBar(title: 'Settings', subtitle: 'Preferences & account'),
      body: AVITRefresh(
        onRefresh: () async {},
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITSectionHeader(title: 'Appearance'),
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Theme', style: text.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: <ThemeMode>{state.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      state.setThemeMode(selection.first);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(title: 'Security'),
            AVITCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Biometric sign-in', style: text.titleSmall),
                    subtitle: Text(
                      'Use fingerprint or face unlock on this device',
                      style: text.labelSmall,
                    ),
                    value: biometricOn,
                    onChanged: _busy ? null : _toggleBiometric,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password_rounded),
                    title: Text('Change password', style: text.titleSmall),
                    subtitle: Text(
                      'Password updated 3 months ago',
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.forgotPassword),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.devices_rounded),
                    title: Text('Login activity', style: text.titleSmall),
                    subtitle: Text(
                      'Review and revoke active sessions',
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.loginActivity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(title: 'Notifications'),
            AVITCard(
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Push notifications', style: text.titleSmall),
                    subtitle: Text(
                      'Announcements, passes and alerts',
                      style: text.labelSmall,
                    ),
                    value: _notifications,
                    onChanged: (bool v) =>
                        setState(() => _notifications = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Event reminders', style: text.titleSmall),
                    subtitle: Text(
                      'Nudge me 30 minutes before an event',
                      style: text.labelSmall,
                    ),
                    value: _eventReminders,
                    onChanged: (bool v) =>
                        setState(() => _eventReminders = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Weekly email digest', style: text.titleSmall),
                    subtitle: Text(
                      'Summary of campus activity every Monday',
                      style: text.labelSmall,
                    ),
                    value: _emailDigest,
                    onChanged: (bool v) => setState(() => _emailDigest = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(title: 'Privacy & support'),
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
                    leading: const Icon(Icons.help_rounded),
                    title: Text('Help & FAQs', style: text.titleSmall),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pushNamed(context, Routes.help),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_rounded),
                    title: Text('About AVIT Campus+', style: text.titleSmall),
                    subtitle: Text(
                      'Version ${AppConstants.appVersion}',
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pushNamed(context, Routes.about),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.isDemo)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AVITStatusChip(
                  label: 'Demo data mode — connect an API to go live',
                  tone: AVITStatusTone.warning,
                  icon: Icons.science_rounded,
                ),
              ),
            AVITButton(
              label: 'Sign out',
              variant: AVITButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: _signOut,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
