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

/// One-tap emergency raise with type selection, location note and history.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  bool _shareLocation = true;
  EmergencyType _type = EmergencyType.security;
  final TextEditingController _location = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  List<EmergencyRequest> _history = <EmergencyRequest>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<EmergencyRequest> rows = await deps.campus.myEmergencies();
      if (!mounted) return;
      setState(() {
        _history = rows;
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
        _error = 'Unable to load your emergency history';
        _loading = false;
      });
    }
  }

  AVITStatusTone _toneFor(EmergencyStatus status) => switch (status) {
        EmergencyStatus.raised => AVITStatusTone.warning,
        EmergencyStatus.dispatched => AVITStatusTone.info,
        EmergencyStatus.assigned => AVITStatusTone.brand,
        EmergencyStatus.resolved => AVITStatusTone.success,
      };

  IconData _iconFor(EmergencyType type) => switch (type) {
        EmergencyType.security => Icons.shield_rounded,
        EmergencyType.medical => Icons.medical_services_rounded,
        EmergencyType.fire => Icons.local_fire_department_rounded,
        EmergencyType.womenSafety => Icons.favorite_rounded,
        EmergencyType.hostel => Icons.apartment_rounded,
        EmergencyType.suspicious => Icons.report_rounded,
      };

  Future<void> _raise() async {
    final String? locationError = Validators.safeText(
      _location.text,
      field: 'Location',
      required: false,
      maxLength: 160,
    );
    if (locationError != null) {
      showAVITSnackBar(context,
          message: locationError, tone: AVITSnackTone.warning);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Raise ${_type.label}?'),
        content: const Text(
          'Campus security will be notified immediately with your details. '
          'Use this only for genuine emergencies.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Notify now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final AppState state = AppScope.of(context).state;
    final AppUser? me = state.user;
    setState(() => _submitting = true);
    try {
      await state.deps.campus.raiseEmergency(
        type: _type,
        raisedBy: me?.fullName ?? 'Student',
        locationNote: _location.text.trim(),
        locationShared: _shareLocation,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _location.clear();
        _notes.clear();
      });
      showAVITSnackBar(
        context,
        message: 'Security team notified. Stay where you are.',
        tone: AVITSnackTone.success,
        duration: const Duration(seconds: 5),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAVITSnackBar(
        context,
        message: 'Could not reach the control room. Call the helpline below.',
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
        appBar: const AVITAppBar(title: 'Emergency'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Emergency',
        subtitle: '24×7 campus control room',
        backgroundColor: AppColors.danger,
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFB3261E), Color(0xFF8E1611)],
                ),
                borderRadius: AppRadius.card,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Control room helpline',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          '0413 – 261 4000',
                          style: text.titleLarge?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.phone_rounded, color: AppColors.white),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'What is happening?',
              subtitle: 'Pick the closest option',
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.86,
              children: <Widget>[
                for (final EmergencyType type in EmergencyType.values)
                  _TypeTile(
                    type: type,
                    selected: _type == type,
                    icon: _iconFor(type),
                    onTap: () => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AVITTextField(
                    label: 'Where are you now?',
                    hint: 'Eg. Library 2nd floor, near stairwell',
                    controller: _location,
                    required: true,
                    maxLength: 160,
                    prefixIcon: Icons.place_rounded,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Share my live location',
                      style: text.titleSmall,
                    ),
                    subtitle: Text(
                      'Helps the response team reach you faster.',
                      style: text.labelSmall,
                    ),
                    value: _shareLocation,
                    onChanged: (bool v) => setState(() => _shareLocation = v),
                  ),
                  AVITTextField(
                    label: 'Anything else security should know?',
                    hint: 'Optional details',
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 240,
                    required: false,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AVITButton(
                    label: 'Raise ${_type.label}',
                    variant: AVITButtonVariant.danger,
                    icon: Icons.warning_amber_rounded,
                    loading: _submitting,
                    onPressed: _submitting ? null : _raise,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Your recent requests',
              subtitle: '${_history.length} on record',
            ),
            if (_history.isEmpty)
              const AVITEmptyState(
                title: 'No emergencies raised',
                message: 'Stay safe. Requests you raise appear here with '
                    'live status updates.',
                icon: Icons.verified_user_rounded,
              )
            else
              for (final EmergencyRequest req in _history)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          _iconFor(req.type),
                          color: req.status == EmergencyStatus.resolved
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      req.type.label,
                                      style: text.titleSmall,
                                    ),
                                  ),
                                  AVITStatusChip(
                                    label: req.status.label,
                                    tone: _toneFor(req.status),
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Formatters.dayLong.format(req.raisedAt)} • '
                                '${Formatters.time.format(req.raisedAt)}',
                                style: text.labelSmall,
                              ),
                              if (req.locationNote.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  req.locationNote,
                                  style: text.bodySmall,
                                ),
                              ],
                              if (req.responder.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  'Responder: ${req.responder}',
                                  style: text.labelSmall
                                      ?.copyWith(color: AppColors.info),
                                ),
                              ],
                            ],
                          ),
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

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final EmergencyType type;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITAnimatedCard(
      onTap: onTap,
      color: selected ? AppColors.dangerSurface : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 26,
            color: selected ? AppColors.danger : AppColors.royalBlue,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            type.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.danger : null,
            ),
          ),
        ],
      ),
    );
  }
}
