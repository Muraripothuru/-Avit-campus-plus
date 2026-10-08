import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../routes/app_routes.dart';
import '../theme/app_spacing.dart';
import 'snackbar.dart';

/// Shared account sign-out used by every interface (student home, security,
/// warden and admin): confirm with a dialog, end the session, then land the
/// user back on the login screen.
Future<void> confirmSignOut(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Sign out?'),
      content: const Text(
        'You will need your ID and password to sign back in.',
      ),
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
  if (confirmed != true || !context.mounted) return;
  try {
    await AppScope.of(context).state.signOut();
    if (!context.mounted) return;
    showAVITSnackBar(
      context,
      message: 'Signed out successfully',
      tone: AVITSnackTone.success,
    );
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.login, (Route<dynamic> route) => false);
  } catch (_) {
    if (!context.mounted) return;
    showAVITSnackBar(
      context,
      message: 'Could not sign out — please try again',
      tone: AVITSnackTone.error,
    );
  }
}
