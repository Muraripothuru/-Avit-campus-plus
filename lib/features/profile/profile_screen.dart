import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/user.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Student / staff profile with account actions and role-aware entries.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppScope scope = AppScope.of(context);
    final AppUser? user = scope.state.user;
    final TextTheme text = Theme.of(context).textTheme;

    if (user == null) {
      return const Center(child: AVITLoading(label: 'Loading profile'));
    }

    return AVITRefresh(
      onRefresh: () async => scope.state.loadSessionUser(),
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          _ProfileHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Account',
            subtitle: 'Your AVIT identity and verification',
          ),
          AVITCard(
            child: Column(
              children: <Widget>[
                _DetailRow(
                  icon: Icons.badge_rounded,
                  label: user.isStudent ? 'Student ID' : 'Staff ID',
                  value: user.displayId,
                ),
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.mail_rounded,
                  label: 'Email',
                  value: user.email,
                  trailing: AVITStatusChip(
                    label: user.emailVerified ? 'Verified' : 'Unverified',
                    tone: user.emailVerified
                        ? AVITStatusTone.success
                        : AVITStatusTone.warning,
                    compact: true,
                  ),
                ),
                const Divider(height: 1),
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: user.phone.isEmpty
                      ? 'Not added'
                      : Formatters.maskPhone(user.phone),
                ),
                if (user.isStudent) ...<Widget>[
                  const Divider(height: 1),
                  _DetailRow(
                    icon: Icons.school_rounded,
                    label: 'Programme',
                    value: user.programme.isEmpty ? '-' : user.programme,
                  ),
                  if (user.semester != null) ...<Widget>[
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.calendar_view_week_rounded,
                      label: 'Semester',
                      value: 'Semester ${user.semester}',
                    ),
                  ],
                ],
                if (user.hostel != null && user.hostel!.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _DetailRow(
                    icon: Icons.apartment_rounded,
                    label: 'Hostel',
                    value: user.hostel!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(title: 'Manage', subtitle: 'Security and preferences'),
          _ActionTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Theme, biometrics, notifications',
            onTap: () => Navigator.pushNamed(context, Routes.settings),
          ),
          _ActionTile(
            icon: Icons.history_rounded,
            title: 'Login activity',
            subtitle: 'Devices and recent sign-ins',
            onTap: () => Navigator.pushNamed(context, Routes.loginActivity),
          ),
          _ActionTile(
            icon: Icons.shield_rounded,
            title: 'Privacy & security',
            subtitle: 'Consent, data and password policy',
            onTap: () => Navigator.pushNamed(context, Routes.privacy),
          ),
          _ActionTile(
            icon: Icons.support_agent_rounded,
            title: 'Help centre',
            subtitle: 'FAQs and how to reach us',
            onTap: () => Navigator.pushNamed(context, Routes.help),
          ),
          _ActionTile(
            icon: Icons.info_rounded,
            title: 'About AVIT Campus+',
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: () => Navigator.pushNamed(context, Routes.about),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Staff console',
            subtitle: 'Available to your role only',
          ),
          if (user.role == UserRole.student)
            AVITCard(
              color: AppColors.surfaceMuted,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Security, warden and administrator tools appear here '
                      'once your account is granted that role.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            if (user.role == UserRole.security) ...<Widget>[
              _ActionTile(
                icon: Icons.local_police_rounded,
                title: 'Security desk',
                subtitle: 'Scanner, movements and incidents',
                onTap: () => Navigator.pushNamed(context, Routes.security),
              ),
              _ActionTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Pass scanner',
                subtitle: 'Verify gate and visitor QR codes',
                onTap: () => Navigator.pushNamed(context, Routes.scanner),
              ),
            ],
            if (user.role == UserRole.warden)
              _ActionTile(
                icon: Icons.apartment_rounded,
                title: 'Warden console',
                subtitle: 'Approve passes and hostel requests',
                onTap: () => Navigator.pushNamed(context, Routes.warden),
              ),
            if (user.role == UserRole.admin) ...<Widget>[
              _ActionTile(
                icon: Icons.dashboard_rounded,
                title: 'Administrator console',
                subtitle: 'Analytics, users and publishing',
                onTap: () => Navigator.pushNamed(context, Routes.admin),
              ),
              _ActionTile(
                icon: Icons.policy_rounded,
                title: 'Audit log',
                subtitle: 'Every privileged action, in order',
                onTap: () => Navigator.pushNamed(context, Routes.auditLog),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          AVITButton(
            label: 'Sign out',
            variant: AVITButtonVariant.danger,
            icon: Icons.logout_rounded,
            onPressed: () => _confirmLogout(),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: const Text('Sign out?'),
            content: const Text(
              'You will need to sign in again to access your campus account.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await AppScope.of(context).state.signOut();
    if (!mounted) return;
    showAVITSnackBar(
      context,
      message: 'Logged out successfully',
      tone: AVITSnackTone.success,
    );
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AVITCard(
      gradient: AppColors.heroGradient,
      borderColor: Colors.transparent,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Hero(
                tag: 'avit-profile-avatar',
                child: Container(
                  width: 68,
                  height: 68,
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
                    Formatters.initials(user.fullName),
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
                  children: <Widget>[
                    Text(
                      user.fullName,
                      style: text.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.displayId,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AVITStatusChip(
                      label: user.role.label,
                      tone: AVITStatusTone.success,
                      icon: Icons.verified_user_rounded,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'Verified email',
                  value: user.emailVerified ? 'Yes' : 'No',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Biometric',
                  value: user.biometricEnabled ? 'On' : 'Off',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Member since',
                  value: user.createdAt == null
                      ? '—'
                      : Formatters.monthDay.format(user.createdAt!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.royalBlue),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: text.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: text.titleSmall?.copyWith(fontSize: 14)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AVITCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: AppRadius.small,
              ),
              child: Icon(icon, size: 20, color: AppColors.royalBlue),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: text.titleSmall),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
