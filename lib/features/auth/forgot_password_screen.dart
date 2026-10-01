import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_inputs.dart';

/// Two-step password recovery: request a code, then set a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  int _step = 0; // 0 = request, 1 = code + new password
  bool _busy = false;
  String? _error;
  int _secondsLeft = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startCooldown();
    }
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Timer? _cooldown;

  /// Counts the resend cooldown down and stops itself; cancelled on dispose
  /// so no timer outlives the screen.
  void _startCooldown() {
    _cooldown?.cancel();
    _secondsLeft = AppConstants.otpCooldown.inSeconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted || _secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    final String? invalid = Validators.userIdOrEmail(_identifier.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.requestPasswordReset(_identifier.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 1;
      });
      _startCooldown();
      final AuthRepository repo = scope.state.deps.auth;
      final String? devCode = repo is DemoAuthRepository
          ? repo.debugLastOtp
          : null;
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: devCode != null
            ? 'Development mode — your code is $devCode'
            : 'If an account exists, a reset code is on its way',
        tone: AVITSnackTone.success,
        duration: const Duration(seconds: 6),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to send a reset code right now';
      });
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.requestPasswordReset(_identifier.text.trim());
      if (!mounted) return;
      setState(_startCooldown);
      showAVITSnackBar(
        context,
        message: 'A new reset code is on its way',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: e.userMessage,
        tone: AVITSnackTone.error,
      );
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    final String? invalid =
        Validators.otp(_code.text) ??
        Validators.password(_password.text) ??
        Validators.confirmPassword(_confirm.text, _password.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.resetPassword(
        identifier: _identifier.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Password updated — sign in with your new password',
        tone: AVITSnackTone.success,
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.login, (Route<dynamic> route) => false);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to reset the password right now';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: _step == 0 ? _buildRequest(text) : _buildReset(text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequest(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.lightBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 40,
            color: AppColors.royalBlue,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Forgot your password?',
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Enter your student ID or institutional email and we will send '
          'you a 6-digit reset code.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AVITTextField(
          label: 'Student ID or email',
          controller: _identifier,
          keyboardType: TextInputType.emailAddress,
          required: true,
          prefixIcon: Icons.alternate_email_rounded,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _requestCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AVITButton(
          label: 'Send reset code',
          loading: _busy,
          onPressed: _busy ? null : _requestCode,
        ),
        const SizedBox(height: AppSpacing.sm),
        AVITButton(
          label: 'Back to sign in',
          variant: AVITButtonVariant.ghost,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildReset(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AVITCard(
          color: AppColors.infoSurface,
          borderColor: Colors.transparent,
          child: Row(
            children: <Widget>[
              const Icon(Icons.mark_email_read_rounded, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'We sent a code to ${_identifier.text.trim()}. '
                  'It expires in ${AppConstants.otpTtl.inMinutes} minutes.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AVITTextField(
          label: '6-digit reset code',
          controller: _code,
          keyboardType: TextInputType.number,
          required: true,
          maxLength: 6,
          prefixIcon: Icons.password_rounded,
          errorText: _error,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        AVITTextField(
          label: 'New password',
          controller: _password,
          obscure: true,
          required: true,
          prefixIcon: Icons.lock_rounded,
          helper: '8+ chars with upper, lower, number and symbol',
          validator: Validators.password,
        ),
        const SizedBox(height: AppSpacing.md),
        AVITTextField(
          label: 'Confirm new password',
          controller: _confirm,
          obscure: true,
          required: true,
          prefixIcon: Icons.lock_reset_rounded,
          textInputAction: TextInputAction.done,
          validator: (String? v) =>
              Validators.confirmPassword(v, _password.text),
          onSubmitted: (_) => _reset(),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend in ${_secondsLeft}s'
                      : 'Code not received?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (c.maxWidth * 0.45).clamp(96.0, 200.0),
                ),
                child: TextButton(
                  onPressed: _secondsLeft > 0 ? null : _resend,
                  child: const Text(
                    'Resend code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AVITButton(
          label: 'Reset password',
          loading: _busy,
          onPressed: _busy ? null : _reset,
        ),
        const SizedBox(height: AppSpacing.sm),
        AVITButton(
          label: 'Start over',
          variant: AVITButtonVariant.ghost,
          onPressed: () => setState(() {
            _step = 0;
            _error = null;
            _code.clear();
          }),
        ),
      ],
    );
  }
}
