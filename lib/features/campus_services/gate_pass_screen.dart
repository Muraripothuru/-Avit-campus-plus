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

/// Gate pass requests: create → review status → signed QR at the gate.
class GatePassScreen extends StatefulWidget {
  const GatePassScreen({super.key});

  @override
  State<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends State<GatePassScreen> {
  bool _loading = true;
  String? _error;
  List<GatePass> _passes = <GatePass>[];
  String _filter = 'All';

  static const List<String> _filters = <String>[
    'All',
    'Pending',
    'Approved',
    'History',
  ];

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
      final List<GatePass> rows = await deps.gatePasses.myPasses(
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
        _error = 'Unable to load your gate passes';
        _loading = false;
      });
    }
  }

  List<GatePass> get _visible => switch (_filter) {
    'Pending' =>
      _passes.where((GatePass p) => p.status == PassStatus.pending).toList(),
    'Approved' =>
      _passes.where((GatePass p) => p.status == PassStatus.approved).toList(),
    'History' => _passes.where((GatePass p) => p.status.isTerminal).toList(),
    _ => _passes,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Gate Pass',
        subtitle: '${_passes.length} request${_passes.length == 1 ? '' : 's'}',
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'New gate pass',
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New pass'),
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
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (BuildContext context, int index) {
                        final bool selected = _filters[index] == _filter;
                        return ChoiceChip(
                          label: Text(_filters[index]),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _filter = _filters[index]),
                          selectedColor: AppColors.lightBlue,
                          labelStyle: text.labelMedium?.copyWith(
                            color: selected ? AppColors.primaryBlue : null,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryBlue
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillShape,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_visible.isEmpty)
                    AVITEmptyState(
                      title: 'No passes in "$_filter"',
                      message: 'Tap “New pass” to request permission to leave campus.',
                      icon: Icons.qr_code_rounded,
                      actionLabel: 'New pass',
                      onAction: _showCreateSheet,
                    )
                  else
                    for (final GatePass pass in _visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PassCard(
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

  void _showQr(GatePass pass) {
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (token == null)
                Text(
                  'This pass is ${pass.status.label.toLowerCase()} — a QR code '
                  'is only issued after approval.',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                )
              else
                AVITQrPanel(
                  data: token,
                  title: 'Gate pass QR',
                  subtitle:
                      '${pass.destination} • valid until '
                      '${Formatters.dayShort.format(pass.inBy)}',
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
      builder: (BuildContext ctx) => const Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: SingleChildScrollView(child: _CreateGatePassForm()),
      ),
    ).then((_) => _load());
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass, required this.onShowQr});

  final GatePass pass;
  final VoidCallback onShowQr;

  AVITStatusTone get _tone => switch (pass.status) {
    PassStatus.pending => AVITStatusTone.warning,
    PassStatus.approved => AVITStatusTone.success,
    PassStatus.rejected => AVITStatusTone.danger,
    PassStatus.used => AVITStatusTone.info,
    PassStatus.expired => AVITStatusTone.neutral,
    PassStatus.cancelled => AVITStatusTone.neutral,
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
                icon: pass.status == PassStatus.approved
                    ? Icons.verified_rounded
                    : pass.status == PassStatus.pending
                    ? Icons.hourglass_top_rounded
                    : Icons.info_outline_rounded,
                compact: true,
              ),
              AVITStatusChip(
                label: pass.destination,
                tone: AVITStatusTone.brand,
                compact: true,
              ),
              Text(
                Formatters.relativeDay(pass.createdAt),
                style: text.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(pass.reason, style: text.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.logout_rounded, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      Formatters.dayShort.format(pass.outAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.login_rounded, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      Formatters.dayShort.format(pass.inBy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.schedule_rounded, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${Formatters.time.format(pass.outAt)} – '
                      '${Formatters.time.format(pass.inBy)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (pass.reviewerComment.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: AppSpacing.tightPadding,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.small,
              ),
              child: Text(
                '${pass.reviewedBy.isEmpty ? 'Reviewer' : pass.reviewedBy}: '
                '${pass.reviewerComment}',
                style: text.labelSmall,
              ),
            ),
          ],
          if (pass.status.canBeUsed) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AVITButton(
              label: 'Show QR code',
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

class _CreateGatePassForm extends StatefulWidget {
  const _CreateGatePassForm();

  @override
  State<_CreateGatePassForm> createState() => _CreateGatePassFormState();
}

class _CreateGatePassFormState extends State<_CreateGatePassForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _destination = TextEditingController();

  DateTime _outAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _inBy = DateTime.now().add(const Duration(hours: 5));
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isOut) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isOut ? _outAt : _inBy,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isOut ? _outAt : _inBy),
    );
    if (time == null || !mounted) return;
    final DateTime combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isOut) {
        _outAt = combined;
        if (_inBy.isBefore(_outAt)) {
          _inBy = _outAt.add(const Duration(hours: 2));
        }
      } else {
        _inBy = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final AppScope scope = AppScope.of(context);
    final AppUser? me = scope.state.user;
    try {
      await scope.state.deps.gatePasses.create(
        studentId: me?.studentId ?? '',
        studentName: me?.fullName ?? '',
        reason: _reason.text.trim(),
        destination: _destination.text.trim(),
        outAt: _outAt,
        inBy: _inBy,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAVITSnackBar(
        context,
        message: 'Request submitted — waiting for warden approval',
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
        message: 'Unable to submit the request right now',
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
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('New gate pass', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'A warden approves every request before a QR is issued.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AVITTextField(
              label: 'Reason',
              hint: 'Medical appointment, home visit…',
              controller: _reason,
              required: true,
              maxLength: 120,
              validator: (String? v) =>
                  Validators.safeText(v, field: 'Reason', maxLength: 120),
            ),
            const SizedBox(height: AppSpacing.md),
            AVITTextField(
              label: 'Destination',
              hint: 'Where are you going?',
              controller: _destination,
              required: true,
              maxLength: 80,
              validator: (String? v) =>
                  Validators.safeText(v, field: 'Destination', maxLength: 80),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimeField(
                    label: 'Exit',
                    value: _outAt,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TimeField(
                    label: 'Return by',
                    value: _inBy,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: 'Submit request',
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
        ),
        child: Text(
          '${Formatters.monthDay.format(value)} • '
          '${Formatters.time.format(value)}',
          style: text.bodyMedium,
        ),
      ),
    );
  }
}
