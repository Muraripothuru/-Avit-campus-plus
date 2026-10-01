import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Active sessions with per-device and bulk revocation.
class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  bool _loading = true;
  String? _error;
  bool _busy = false;
  List<UserSession> _sessions = <UserSession>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<UserSession> rows = await AppScope.of(context).state.deps.auth
          .sessions();
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.userMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load sessions';
        _loading = false;
      });
    }
  }

  Future<void> _revoke(UserSession session) async {
    setState(() => _busy = true);
    try {
      await AppScope.of(context).state.deps.auth.revokeSession(session.id);
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Session revoked',
        tone: AVITSnackTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAVITSnackBar(
        context,
        message: 'Could not revoke the session',
        tone: AVITSnackTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text(
          'Every other device will be logged out immediately.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).state.deps.auth.revokeAllSessions();
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'All other sessions signed out',
        tone: AVITSnackTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAVITSnackBar(
        context,
        message: 'Could not sign out other devices',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Login activity'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Login activity',
        subtitle: '${_sessions.length} active sessions',
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out everywhere',
            onPressed: _busy ? null : _revokeAll,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITStatusChip(
              label: 'Sessions refresh automatically on sign-in',
              tone: AVITStatusTone.info,
              icon: Icons.shield_rounded,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_sessions.isEmpty)
              const AVITEmptyState(
                title: 'No sessions recorded',
                message: 'Devices appear here after you sign in.',
                icon: Icons.devices_rounded,
              )
            else
              for (final UserSession session in _sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          session.device.toLowerCase().contains('phone')
                              ? Icons.phone_iphone_rounded
                              : Icons.laptop_mac_rounded,
                          color: session.current
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              LayoutBuilder(
                                builder:
                                    (
                                      BuildContext context,
                                      BoxConstraints constraints,
                                    ) => Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            session.device,
                                            style: text.titleSmall,
                                          ),
                                        ),
                                        if (session.current)
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  (constraints.maxWidth * 0.5)
                                                      .clamp(80.0, 150.0),
                                            ),
                                            child: AVITStatusChip(
                                              label: 'This device',
                                              tone: AVITStatusTone.success,
                                              compact: true,
                                            ),
                                          ),
                                      ],
                                    ),
                              ),
                              Text(
                                '${Formatters.relativeDay(session.lastActive)} • '
                                '${Formatters.time.format(session.lastActive)}',
                                style: text.labelSmall,
                              ),
                              Text(
                                session.locationLabel,
                                style: text.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        if (!session.current)
                          IconButton(
                            tooltip: 'Revoke',
                            onPressed: _busy ? null : () => _revoke(session),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: 'Sign out of all other devices',
              variant: AVITButtonVariant.secondary,
              icon: Icons.devices_other_rounded,
              loading: _busy,
              onPressed: _busy ? null : _revokeAll,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password_rounded),
              title: Text('Also change your password', style: text.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, Routes.forgotPassword),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
