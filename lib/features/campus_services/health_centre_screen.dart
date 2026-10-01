import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/campus_services.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Campus health centre: browse services, book a slot, track appointments.
class HealthCentreScreen extends StatefulWidget {
  const HealthCentreScreen({super.key});

  @override
  State<HealthCentreScreen> createState() => _HealthCentreScreenState();
}

class _HealthCentreScreenState extends State<HealthCentreScreen> {
  // Owned by the screen (not the sheet) so the exit animation can never touch
  // a disposed controller.
  final TextEditingController _reason = TextEditingController();

  bool _loading = true;
  String? _error;
  List<HealthService> _services = <HealthService>[];
  List<HealthAppointment> _appointments = <HealthAppointment>[];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context).state;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<HealthService> services = await state.deps.campus.healthServices();
      final List<HealthAppointment> mine = await state.deps.campus
          .myAppointments(state.user?.studentId ?? '');
      if (!mounted) return;
      setState(() {
        _services = services;
        _appointments = mine;
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
        _error = 'Unable to reach the health centre';
        _loading = false;
      });
    }
  }

  AVITStatusTone _toneFor(HealthAppointmentStatus status) => switch (status) {
    HealthAppointmentStatus.scheduled => AVITStatusTone.info,
    HealthAppointmentStatus.completed => AVITStatusTone.success,
    HealthAppointmentStatus.cancelled => AVITStatusTone.neutral,
  };

  Future<void> _book() async {
    _reason.clear();
    String serviceId = _services.isEmpty ? '' : _services.first.id;
    DateTime day = DateTime.now().add(const Duration(days: 1));
    TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);
    bool submitting = false;

    final bool? submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setLocal) {
          final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(ctx);
          final DateTime when = DateTime(
            day.year,
            day.month,
            day.day,
            time.hour,
            time.minute,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Book an appointment',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Free services can also be walked into — a booking just '
                    'guarantees your slot.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITDropdown<String>(
                    label: 'Service',
                    required: true,
                    value: serviceId.isEmpty ? null : serviceId,
                    items: <DropdownMenuItem<String>>[
                      for (final HealthService s in _services)
                        DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('${s.name} Â· ${s.feeLabel}'),
                        ),
                    ],
                    onChanged: (String? v) =>
                        setLocal(() => serviceId = v ?? serviceId),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AVITButton(
                          label: Formatters.dayShort.format(day),
                          icon: Icons.calendar_today_rounded,
                          variant: AVITButtonVariant.secondary,
                          compact: true,
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: ctx,
                              initialDate: day,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 180),
                              ),
                            );
                            if (picked != null) setLocal(() => day = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AVITButton(
                          label: time.format(ctx),
                          icon: Icons.schedule_rounded,
                          variant: AVITButtonVariant.secondary,
                          compact: true,
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: ctx,
                              initialTime: time,
                            );
                            if (picked != null) setLocal(() => time = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Reason for the visit',
                    required: true,
                    controller: _reason,
                    maxLines: 3,
                    maxLength: 300,
                    hint: 'Symptoms, duration, anything the doctor should know',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITButton(
                    label: 'Confirm booking',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final String? error = Validators.safeText(
                              _reason.text,
                              field: 'Reason',
                              minLength: 10,
                              maxLength: 300,
                            );
                            if (error != null) {
                              showAVITSnackBar(ctx,
                                  message: error, tone: AVITSnackTone.warning);
                              return;
                            }
                            setLocal(() => submitting = true);
                            try {
                              final AppState state = AppScope.of(ctx).state;
                              await state.deps.campus.bookAppointment(
                                serviceId: serviceId,
                                patientName: state.user?.fullName ?? 'Student',
                                studentId: state.user?.studentId ?? '',
                                scheduledFor: when,
                                reason: _reason.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setLocal(() => submitting = false);
                              if (ctx.mounted) {
                                showAVITSnackBar(
                                  ctx,
                                  message: e is AppException
                                      ? e.userMessage
                                      : 'Could not book. Please try again.',
                                  tone: AVITSnackTone.error,
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (submitted == true && mounted) {
      showAVITSnackBar(
        context,
        message: 'Appointment booked — it is listed below.',
        tone: AVITSnackTone.success,
      );
      await _load();
    }
  }

  Future<void> _cancel(HealthAppointment appointment) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          '“${appointment.serviceName}” on '
          '${Formatters.dayShort.format(appointment.scheduledFor)} at '
          '${Formatters.time.format(appointment.scheduledFor)} will be freed '
          'up for someone else.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final AppState state = AppScope.of(context).state;
    try {
      await state.deps.campus.cancelAppointment(appointment.id);
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Appointment cancelled',
        tone: AVITSnackTone.success,
      );
      await _load();
    } on AppException catch (e) {
      if (!mounted) return;
      showAVITSnackBar(context, message: e.userMessage, tone: AVITSnackTone.error);
    } catch (_) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Could not cancel. Please try again.',
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
        appBar: const AVITAppBar(title: 'Health Centre'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Health Centre',
        subtitle: '${_services.length} services Â· '
            '${_appointments.where((HealthAppointment a) => a.canCancel).length} upcoming',
      ),
      floatingActionButton: _services.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _book,
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Book'),
            ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITSectionHeader(
              title: 'My appointments',
              subtitle: 'Booked at the campus health centre',
            ),
            if (_appointments.isEmpty)
              AVITCard(
                color: AppColors.surfaceMuted,
                borderColor: Colors.transparent,
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No appointments yet. Tap “Book” to reserve a slot.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final HealthAppointment a in _appointments)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(a.serviceName, style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: a.status.label,
                              tone: _toneFor(a.status),
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            AVITStatusChip(
                              label: Formatters.dayShort.format(a.scheduledFor),
                              tone: AVITStatusTone.brand,
                              icon: Icons.calendar_today_rounded,
                              compact: true,
                            ),
                            AVITStatusChip(
                              label: Formatters.time.format(a.scheduledFor),
                              tone: AVITStatusTone.brand,
                              icon: Icons.schedule_rounded,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(a.reason, style: text.bodySmall),
                        if (a.note.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.infoSurface,
                              borderRadius: AppRadius.small,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Health centre note',
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(a.note, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                        if (a.canCancel) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          AVITButton(
                            label: 'Cancel appointment',
                            icon: Icons.event_busy_rounded,
                            variant: AVITButtonVariant.ghost,
                            compact: true,
                            expand: false,
                            onPressed: () => _cancel(a),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),

            AVITSectionHeader(
              title: 'Services',
              subtitle: 'Consultation, first aid and well-being',
            ),
            for (final HealthService s in _services)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AVITCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(s.name, style: text.titleSmall),
                          ),
                          AVITStatusChip(
                            label: s.feeLabel,
                            tone: s.fee == 0
                                ? AVITStatusTone.success
                                : AVITStatusTone.warning,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.description, style: text.bodySmall),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          AVITStatusChip(
                            label: s.location,
                            tone: AVITStatusTone.info,
                            icon: Icons.place_rounded,
                            compact: true,
                          ),
                          AVITStatusChip(
                            label: s.hours,
                            tone: AVITStatusTone.neutral,
                            icon: Icons.schedule_rounded,
                            compact: true,
                          ),
                          AVITStatusChip(
                            label: s.walkIn ? 'Walk-ins welcome' : 'By appointment',
                            tone: s.walkIn
                                ? AVITStatusTone.success
                                : AVITStatusTone.brand,
                            compact: true,
                          ),
                        ],
                      ),
                      if (s.phone.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text('Reception ${s.phone}', style: text.labelSmall),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
