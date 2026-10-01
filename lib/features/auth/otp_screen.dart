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
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Arguments passed to [OtpScreen] by name.
class OtpArguments {
  const OtpArguments({
    required this.destination,
    required this.title,
    required this.subtitle,
    this.onVerified,
    this.developmentCode,
    this.resetPassword = false,
  });

  /// Email or phone the code was sent to.
  final String destination;
  final String title;
  final String subtitle;
  final Future<void> Function()? onVerified;
  final String? developmentCode;

  /// When true the screen also collects a new password after verification.
  final bool resetPassword;
}

/// Six-digit one-time code entry with resend cooldown and attempt feedback.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.arguments});

  final OtpArguments arguments;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  int _secondsLeft = 0;
  bool _verifying = false;
  bool _verified = false;
  String? _error;
  int _attempts = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startCooldown();
      _surfaceDevelopmentCode();
    }
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _shake.dispose();
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

  /// Development mode: surfaces the demo code instead of sending an email.
  void _surfaceDevelopmentCode() {
    final String? code = widget.arguments.developmentCode;
    if (code == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Development mode — your code is $code',
        tone: AVITSnackTone.warning,
        duration: const Duration(seconds: 8),
      );
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final String? invalid = Validators.otp(_code.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      _shake.forward(from: 0);
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.verifyOtp(
        widget.arguments.destination,
        _code.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
      });
      if (widget.arguments.resetPassword) return;
      if (widget.arguments.onVerified != null) {
        await widget.arguments.onVerified!();
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.userMessage;
        _attempts++;
      });
      _shake.forward(from: 0);
      if (_attempts >= AppConstants.maxOtpAttempts) {
        showAVITSnackBar(
          context,
          message: 'Too many attempts — request a new code',
          tone: AVITSnackTone.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Unable to verify the code right now';
      });
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.requestOtp(widget.arguments.destination);
      if (!mounted) return;
      setState(() {
        _startCooldown();
        _error = null;
      });
      _surfaceDevelopmentCode();
      showAVITSnackBar(
        context,
        message: 'A new code is on its way',
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

  Future<void> _finishReset() async {
    if (!_password.text.isNotEmpty) return;
    final String? bad =
        Validators.password(_password.text) ??
        Validators.confirmPassword(_confirm.text, _password.text);
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    setState(() => _verifying = true);
    final AppScope scope = AppScope.of(context);
    try {
      await scope.state.deps.auth.resetPassword(
        identifier: widget.arguments.destination,
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
      setState(() => _verifying = false);
      showAVITSnackBar(
        context,
        message: e.userMessage,
        tone: AVITSnackTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
      showAVITSnackBar(
        context,
        message: 'Unable to reset the password right now',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool showPasswordStep = widget.arguments.resetPassword && _verified;

    return Scaffold(
      appBar: AppBar(title: const Text('Verification code')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showPasswordStep) ...<Widget>[
                    const SuccessState(
                      title: 'Code verified',
                      message: 'Choose a new password for your account.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AVITTextField(
                      label: 'New password',
                      controller: _password,
                      obscure: true,
                      required: true,
                      prefixIcon: Icons.lock_rounded,
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
                      onSubmitted: (_) => _finishReset(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AVITButton(
                      label: 'Update password',
                      loading: _verifying,
                      onPressed: _verifying ? null : _finishReset,
                    ),
                  ] else ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_rounded,
                        size: 40,
                        color: AppColors.royalBlue,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      widget.arguments.title,
                      style: text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.arguments.subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (BuildContext context, Widget? child) {
                        final double offset =
                            (1 - Curves.elasticOut.transform(_shake.value)) * 6;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: AVITTextField(
                        label: '6-digit code',
                        hint: '123456',
                        controller: _code,
                        required: true,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        prefixIcon: Icons.password_rounded,
                        errorText: _error,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _verify(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              _secondsLeft > 0
                                  ? 'Resend in ${_secondsLeft}s'
                                  : 'Didn’t get it?',
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
                    const SizedBox(height: AppSpacing.sm),
                    AVITButton(
                      label: 'Verify code',
                      loading: _verifying,
                      onPressed: _verifying ? null : _verify,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AVITButton(
                      label: 'Use a different account',
                      variant: AVITButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
