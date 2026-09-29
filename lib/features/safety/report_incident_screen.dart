import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/safety.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Security desk: file a new incident report and review recent ones.
class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _severity = 'medium';
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();
  List<IncidentReport> _incidents = <IncidentReport>[];

  static const Map<String, (String, AVITStatusTone)> _severityMeta =
      <String, (String, AVITStatusTone)>{
    'low': ('Low', AVITStatusTone.info),
    'medium': ('Medium', AVITStatusTone.warning),
    'high': ('High', AVITStatusTone.danger),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<IncidentReport> rows = await deps.security.incidents();
      if (!mounted) return;
      setState(() {
        _incidents = rows;
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
        _error = 'Unable to load incident reports';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final String? titleError = Validators.safeText(
      _title.text,
      field: 'Title',
      minLength: 5,
      maxLength: 80,
    );
    if (titleError != null) {
      showAVITSnackBar(context, message: titleError, tone: AVITSnackTone.warning);
      return;
    }
    final String? descError = Validators.safeText(
      _description.text,
      field: 'Description',
      minLength: 15,
      maxLength: 600,
    );
    if (descError != null) {
      showAVITSnackBar(context,
          message: descError, tone: AVITSnackTone.warning);
      return;
    }
    final String? locationError = Validators.safeText(
      _location.text,
      field: 'Location',
      maxLength: 120,
    );
    if (locationError != null) {
      showAVITSnackBar(context,
          message: locationError, tone: AVITSnackTone.warning);
      return;
    }

    final AppState state = AppScope.of(context).state;
    final AppUser? me = state.user;
    setState(() => _submitting = true);
    try {
      await state.deps.security.reportIncident(
        title: _title.text.trim(),
        description: _description.text.trim(),
        severity: _severity,
        location: _location.text.trim(),
        reportedBy: me?.fullName ?? 'Security Desk',
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _title.clear();
        _description.clear();
        _location.clear();
      });
      showAVITSnackBar(
        context,
        message: 'Incident logged and added to the security register.',
        tone: AVITSnackTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAVITSnackBar(
        context,
        message: 'Could not save the report. Please retry.',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Report Incident'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Report Incident',
        subtitle: 'Security register',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('New report', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Title',
                    required: true,
                    controller: _title,
                    hint: 'Unauthorized entry near hostels',
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Description',
                    required: true,
                    controller: _description,
                    maxLines: 4,
                    maxLength: 600,
                    hint: 'What happened? Include time, people involved…',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Location',
                    required: true,
                    controller: _location,
                    maxLength: 120,
                    prefixIcon: Icons.place_rounded,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Severity', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final String level in _severityMeta.keys)
                        ChoiceChip(
                          label: Text(_severityMeta[level]!.$1),
                          selected: _severity == level,
                          onSelected: (_) => setState(() => _severity = level),
                          selectedColor: AppColors.lightBlue,
                          labelStyle: text.labelMedium?.copyWith(
                            color: _severity == level
                                ? AppColors.primaryBlue
                                : null,
                            fontWeight: _severity == level
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: _severity == level
                                ? AppColors.primaryBlue
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillShape,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITButton(
                    label: 'File report',
                    icon: Icons.gavel_rounded,
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Recent incidents',
              subtitle: '${_incidents.length} on file',
            ),
            if (_incidents.isEmpty)
              const AVITEmptyState(
                title: 'Register is clear',
                message: 'No incidents have been reported recently.',
                icon: Icons.health_and_safety_rounded,
              )
            else
              for (final IncidentReport report in _incidents)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child:
                                  Text(report.title, style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: _severityMeta[report.severity]?.$1 ??
                                  report.severity,
                              tone: _severityMeta[report.severity]?.$2 ??
                                  AVITStatusTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.location} • '
                          '${Formatters.dayLong.format(report.reportedAt)} '
                          '${Formatters.time.format(report.reportedAt)}',
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(report.description, style: text.bodySmall),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            AVITStatusChip(
                              label: report.status,
                              tone: report.status.toLowerCase() == 'resolved'
                                  ? AVITStatusTone.success
                                  : AVITStatusTone.warning,
                              compact: true,
                            ),
                            const Spacer(),
                            Text(
                              'By ${report.reportedBy}',
                              style: text.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
