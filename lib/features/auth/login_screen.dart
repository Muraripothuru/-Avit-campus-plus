import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/security/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../widgets/avit_inputs.dart';

/// Sign-in screen with validation, loading, lockout messaging, remember-me
/// and optional biometric sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  bool _remember = true;
  bool _loading = false;
  bool _biometricReady = false;
  String? _identifierError;
  String? _passwordError;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
  }

  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Inherited lookups are only legal after initState.
    _prefill();
    _checkBiometrics();
  }

  Future<void> _prefill() async {
    final AppScope scope = AppScope.of(context);
    final String? last = await scope.state.deps.store.read(
      SecureKeys.lastUserId,
    );
    if (last != null && last.contains('@') && mounted && _remember) {
      setState(() => _identifier.text = last);
    }
  }

  Future<void> _checkBiometrics() async {
    final AppScope scope = AppScope.of(context);
    final bool available = await scope.state.deps.biometrics.isAvailable();
    if (mounted) setState(() => _biometricReady = available);
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _identifierError = Validators.userIdOrEmail(_identifier.text);
      _passwordError = _password.text.isEmpty ? 'Password is required' : null;
    });

    if (_identifierError != null || _passwordError != null) {
      _shake.forward(from: 0);
      return;
    }

    setState(() => _loading = true);
    final AppScope scope = AppScope.of(context);
    final String identifier = _identifier.text.trim();
    final bool ok = await scope.state.signIn(
      identifier: identifier,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      if (_remember) {
        await scope.state.deps.store.write(SecureKeys.lastUserId, identifier);
      }
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Welcome back, ${scope.state.displayName.split(' ').first}',
        tone: AVITSnackTone.success,
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.dashboard,
        (Route<dynamic> route) => false,
      );
      return;
    }

    setState(() => _failedAttempts++);
    _shake.forward(from: 0);
    showAVITSnackBar(
      context,
      message: scope.state.lastError ?? 'Incorrect ID or password',
      tone: AVITSnackTone.error,
    );
    if (_failedAttempts >= AppConstants.maxLoginAttempts) {
      _showLockoutNotice();
    }
  }

  void _showLockoutNotice() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Too many attempts'),
        content: Text(
          'For your security, sign-in is paused for '
          '${AppConstants.loginLockDuration.inMinutes} minutes. '
          'You can reset your password instead.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, Routes.forgotPassword);
            },
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
  }

  Future<void> _biometricLogin() async {
    final AppScope scope = AppScope.of(context);
    final bool ok = await scope.state.deps.biometrics.authenticate(
      reason: 'Sign in to AVIT Campus+',
    );
    if (!mounted) return;
    if (ok) {
      await scope.state.loadSessionUser();
      if (!mounted) return;
      if (scope.state.isAuthenticated) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.dashboard,
          (Route<dynamic> route) => false,
        );
        return;
      }
    }
    showAVITSnackBar(
      context,
      message: 'Biometric sign-in was not completed',
      tone: AVITSnackTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppScope scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Welcome back', style: text.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in with your AVIT account to continue.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (scope.state.isDemo) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: AppSpacing.tightPadding,
                      decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius: AppRadius.small,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.science_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Development mode — use student@avit.ac.in '
                              'with the demo password from the README.',
                              style: text.bodySmall?.copyWith(
                                color: const Color(0xFF8A5B00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          AVITTextField(
                            label: 'Student ID or Email',
                            hint: 'AVIT2026CS001 or you@avit.ac.in',
                            controller: _identifier,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.alternate_email_rounded,
                            required: true,
                            errorText: _identifierError,
                            onChanged: (_) =>
                                setState(() => _identifierError = null),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AVITTextField(
                            label: 'Password',
                            controller: _password,
                            obscure: true,
                            required: true,
                            prefixIcon: Icons.lock_rounded,
                            textInputAction: TextInputAction.done,
                            errorText: _passwordError,
                            onSubmitted: (_) => _submit(),
                            onChanged: (_) =>
                                setState(() => _passwordError = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Checkbox(
                        value: _remember,
                        onChanged: (bool? v) =>
                            setState(() => _remember = v ?? false),
                      ),
                      Text(
                        'Remember me',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, Routes.forgotPassword),
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AVITButton(
                    label: 'Login',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  if (_biometricReady) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    AVITButton(
                      label: 'Use biometric sign-in',
                      icon: Icons.fingerprint_rounded,
                      variant: AVITButtonVariant.secondary,
                      onPressed: _biometricLogin,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'New to AVIT Campus+?',
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (c.maxWidth * 0.45).clamp(96.0, 200.0),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              Routes.signup,
                            ),
                            child: const Text(
                              'Create account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
