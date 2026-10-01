import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/pass.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Visitor passes: invite someone, track approval and show their QR.
class VisitorPassScreen extends StatefulWidget {
  const VisitorPassScreen({super.key});

  @override
  State<VisitorPassScreen> createState() => _VisitorPassScreenState();
}

class _VisitorPassScreenState extends State<VisitorPassScreen> {
  bool _loading = true;
  String? _error;
  List<VisitorPass> _passes = <VisitorPass>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AppUser? me = AppScope.of(context).state.user;
      final List<VisitorPass> rows = await deps.visitorPasses.myPasses(
        me?.studentId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _passes = rows;
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
        _error = 'Unable to load visitor passes';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Visitor Pass',
        subtitle: '${_passes.length} invite${_passes.length == 1 ? '' : 's'}',
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Invite a visitor',
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite'),
      ),
      body: _loading
          ? const LoadingList(itemCount: 4)
          : _error != null
          ? AVITErrorState(message: _error!, onRetry: _load)
          : AVITRefresh(
              onRefresh: _load,
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: <Widget>[
                  AVITCard(
                    color: AppColors.infoSurface,
                    borderColor: Colors.transparent,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.info_rounded, color: AppColors.info),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Visitors are verified against a government ID '
                            'at the gate and must be hosted by a student.',
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_passes.isEmpty)
                    AVITEmptyState(
                      title: 'No visitor invites yet',
                      message:
                          'Invite a parent, friend or recruiter to campus.',
                      icon: Icons.badge_rounded,
                      actionLabel: 'Invite someone',
                      onAction: _showCreateSheet,
                    )
                  else
                    for (final VisitorPass pass in _passes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _VisitorCard(
                          pass: pass,
                          onShowQr: () => _showQr(pass),
                        ),
                      ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
    );
  }

  void _showQr(VisitorPass pass) {
    final String? token = pass.qrToken;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (token == null)
              Text(
                'This invite is ${pass.status.label.toLowerCase()}. '
                'A QR code appears once the warden approves it.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium,
              )
            else
              AVITQrPanel(
                data: token,
                title: 'Visitor entry QR',
                subtitle:
                    '${pass.visitorName} • ${Formatters.dayShort.format(pass.visitDate)}',
              ),
            const SizedBox(height: AppSpacing.md),
            AVITButton(
              label: 'Close',
              variant: AVITButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateVisitorForm(),
    ).then((_) => _load());
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({required this.pass, required this.onShowQr});

  final VisitorPass pass;
  final VoidCallback onShowQr;

  AVITStatusTone get _tone => switch (pass.status) {
    PassStatus.pending => AVITStatusTone.warning,
    PassStatus.approved => AVITStatusTone.success,
    PassStatus.rejected => AVITStatusTone.danger,
    PassStatus.used => AVITStatusTone.info,
    _ => AVITStatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      onTap: pass.status.canBeUsed ? onShowQr : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AVITStatusChip(
                label: pass.status.label,
                tone: _tone,
                compact: true,
              ),
              AVITStatusChip(
                label: pass.idType,
                tone: AVITStatusTone.brand,
                compact: true,
              ),
              Text(
                Formatters.relativeDay(pass.visitDate),
                style: text.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const Icon(Icons.person_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(pass.visitorName, style: text.titleSmall)),
              Text(pass.visitorPhone, style: text.labelMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text('Purpose: ${pass.purpose}', style: text.bodySmall),
          if (pass.status.canBeUsed) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AVITButton(
              label: 'Show visitor QR',
              icon: Icons.qr_code_rounded,
              compact: true,
              expand: false,
              onPressed: onShowQr,
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateVisitorForm extends StatefulWidget {
  const _CreateVisitorForm();

  @override
  State<_CreateVisitorForm> createState() => _CreateVisitorFormState();
}

class _CreateVisitorFormState extends State<_CreateVisitorForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _purpose = TextEditingController();
  String _idType = 'Aadhaar';
  DateTime _visitDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null && mounted) setState(() => _visitDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final AppScope scope = AppScope.of(context);
    final AppUser? me = scope.state.user;
    try {
      await scope.state.deps.visitorPasses.create(
        hostStudentId: me?.studentId ?? '',
        hostStudentName: me?.fullName ?? '',
        visitorName: _name.text.trim(),
        visitorPhone: _phone.text.trim(),
        idType: _idType,
        visitDate: _visitDate,
        purpose: _purpose.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAVITSnackBar(
        context,
        message: 'Invite sent — waiting for warden approval',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAVITSnackBar(
        context,
        message: e.userMessage,
        tone: AVITSnackTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAVITSnackBar(
        context,
        message: 'Unable to send the invite right now',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Invite a visitor', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'The invite expires at the end of the visit date.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              AVITTextField(
                label: 'Visitor name',
                controller: _name,
                required: true,
                prefixIcon: Icons.person_rounded,
                validator: Validators.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              AVITTextField(
                label: 'Visitor mobile',
                controller: _phone,
                keyboardType: TextInputType.phone,
                required: true,
                prefixIcon: Icons.phone_rounded,
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AVITDropdown<String>(
                label: 'ID type',
                value: _idType,
                required: true,
                items:
                    <String>[
                          'Aadhaar',
                          'Driving licence',
                          'Passport',
                          'Voter ID',
                        ]
                        .map(
                          (String v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(v),
                          ),
                        )
                        .toList(),
                onChanged: (String? v) =>
                    setState(() => _idType = v ?? 'Aadhaar'),
              ),
              const SizedBox(height: AppSpacing.md),
              AVITTextField(
                label: 'Purpose of visit',
                controller: _purpose,
                required: true,
                maxLength: 100,
                prefixIcon: Icons.notes_rounded,
                validator: (String? v) =>
                    Validators.safeText(v, field: 'Purpose', maxLength: 100),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _pickDate,
                borderRadius: AppRadius.small,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Visit date',
                    suffixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                  ),
                  child: Text(Formatters.dayLong.format(_visitDate)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AVITButton(
                label: 'Send invite',
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
