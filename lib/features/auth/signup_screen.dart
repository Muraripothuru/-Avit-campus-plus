import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_inputs.dart';
import 'otp_screen.dart';

/// Account creation: institutional identity → credentials → OTP verification.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _studentId = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _programme;
  int? _semester;
  bool _loading = false;
  bool _consent = true;

  static const List<String> _programmes = <String>[
    'B.Tech Computer Science and Engineering',
    'B.Tech Information Technology',
    'B.Tech Electronics and Communication',
    'B.Tech Electrical and Electronics',
    'B.Tech Mechanical Engineering',
    'B.Tech Civil Engineering',
    'M.Tech Computer Science and Engineering',
    'Master of Business Administration',
    'Master of Computer Applications',
  ];

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_programme == null || _semester == null) {
      showAVITSnackBar(
        context,
        message: 'Choose your programme and semester',
        tone: AVITSnackTone.warning,
      );
      return;
    }
    if (!_consent) {
      showAVITSnackBar(
        context,
        message: 'Please accept the campus terms to continue',
        tone: AVITSnackTone.warning,
      );
      return;
    }

    setState(() => _loading = true);
    final AppScope scope = AppScope.of(context);
    final String email = _email.text.trim();
    try {
      await scope.state.deps.auth.requestOtp(email);
      if (!mounted) return;
      setState(() => _loading = false);
      final AuthRepository repo = scope.state.deps.auth;
      final String? code = repo is DemoAuthRepository ? repo.debugLastOtp : null;
      Navigator.pushNamed(
        context,
        Routes.otp,
        arguments: OtpArguments(
          destination: email,
          title: 'Verify your email',
          subtitle: 'We sent a 6-digit code to $email',
          developmentCode: code is String ? code : null,
          onVerified: _complete,
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAVITSnackBar(context, message: e.userMessage, tone: AVITSnackTone.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAVITSnackBar(
        context,
        message: 'Unable to send the verification code right now',
        tone: AVITSnackTone.error,
      );
    }
  }

  Future<void> _complete() async {
    final AppScope scope = AppScope.of(context);
    final bool ok = await scope.state.signUp(
      fullName: _name.text.trim(),
      studentId: _studentId.text.trim().toUpperCase(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      programme: _programme!,
      semester: _semester!,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      showAVITSnackBar(
        context,
        message: 'Account created — welcome to AVIT Campus+',
        tone: AVITSnackTone.success,
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.dashboard,
        (Route<dynamic> route) => false,
      );
      return;
    }
    showAVITSnackBar(
      context,
      message: scope.state.lastError ?? 'Unable to create the account',
      tone: AVITSnackTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Join AVIT Campus+', style: text.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Use your institutional details — the campus team '
                      'verifies every account.',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AVITTextField(
                      label: 'Full name',
                      controller: _name,
                      required: true,
                      prefixIcon: Icons.person_rounded,
                      validator: Validators.name,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Student ID',
                      hint: 'AVIT2026CS042',
                      controller: _studentId,
                      required: true,
                      prefixIcon: Icons.badge_rounded,
                      validator: Validators.studentId,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Institutional email',
                      hint: 'you@avit.ac.in',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      required: true,
                      prefixIcon: Icons.alternate_email_rounded,
                      validator: Validators.institutionalEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Mobile number',
                      hint: '10-digit Indian number',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      required: true,
                      prefixIcon: Icons.phone_rounded,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITDropdown<String>(
                      label: 'Programme',
                      value: _programme,
                      required: true,
                      hint: 'Select your programme',
                      items: _programmes
                          .map(
                            (String p) =>
                                DropdownMenuItem<String>(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (String? v) =>
                          setState(() => _programme = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITDropdown<int>(
                      label: 'Semester',
                      value: _semester,
                      required: true,
                      hint: 'Select current semester',
                      items: List<DropdownMenuItem<int>>.generate(
                        8,
                        (int i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text('Semester ${i + 1}'),
                        ),
                      ),
                      onChanged: (int? v) => setState(() => _semester = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Password',
                      controller: _password,
                      obscure: true,
                      required: true,
                      prefixIcon: Icons.lock_rounded,
                      helper: '8+ chars with upper, lower, number and symbol',
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Confirm password',
                      controller: _confirm,
                      obscure: true,
                      required: true,
                      prefixIcon: Icons.lock_reset_rounded,
                      textInputAction: TextInputAction.done,
                      validator: (String? v) =>
                          Validators.confirmPassword(v, _password.text),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITCard(
                      color: AppColors.surfaceMuted,
                      borderColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Checkbox(
                            value: _consent,
                            onChanged: (bool? v) =>
                                setState(() => _consent = v ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _consent = !_consent),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I agree to the AVIT acceptable-use and '
                                  'privacy policy, and to campus safety '
                                  'communications.',
                                  style: text.bodySmall,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AVITButton(
                      label: 'Send verification code',
                      icon: Icons.mail_outline_rounded,
                      loading: _loading,
                      onPressed: _loading ? null : _submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AVITButton(
                      label: 'Back to sign in',
                      variant: AVITButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
