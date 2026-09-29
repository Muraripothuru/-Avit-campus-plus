import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/pass.dart';
import '../../models/safety.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Security desk: gate activity, pass verification and incident register.
class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() =>
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<GatePass> _gatePasses = <GatePass>[];
  List<VisitorPass> _visitors = <VisitorPass>[];
  List<GateMovement> _movements = <GateMovement>[];
  List<IncidentReport> _incidents = <IncidentReport>[];
  final TextEditingController _vehicle = TextEditingController();
  VehicleRecord? _vehicleRecord;
  bool _checkingVehicle = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<GatePass> gate = await deps.security.activeGatePasses();
      final List<VisitorPass> visitors = await deps.security.activeVisitorPasses();
      final List<GateMovement> moves = await deps.security.recentMovements();
      final List<IncidentReport> incidents = await deps.security.incidents();
      if (!mounted) return;
      setState(() {
        _gatePasses = gate;
        _visitors = visitors;
        _movements = moves;
        _incidents = incidents;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to reach the security service';
        _loading = false;
      });
    }
  }

  Future<void> _checkVehicle() async {
    final String number = _vehicle.text.trim().toUpperCase();
    if (number.length < 6) {
      showAVITSnackBar(context,
          message: 'Enter a valid vehicle number',
          tone: AVITSnackTone.warning);
      return;
    }
    setState(() => _checkingVehicle = true);
    try {
      final VehicleRecord? record =
          await AppScope.of(context).state.deps.security.verifyVehicle(number);
      if (!mounted) return;
      setState(() {
        _vehicleRecord = record;
        _checkingVehicle = false;
      });
      if (record == null) {
        showAVITSnackBar(context,
            message: 'No vehicle found for $number',
            tone: AVITSnackTone.error);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingVehicle = false);
      showAVITSnackBar(context,
          message: 'Vehicle lookup failed', tone: AVITSnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppUser? user = AppScope.of(context).state.user;
    final int openIncidents = _incidents
        .where((IncidentReport r) => r.status.toLowerCase() != 'resolved')
        .length;

    if (_loading) return const LoadingList(itemCount: 6);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Security Desk'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Security Desk',
        subtitle: 'Main gate • Shift Log',
        actions: <Widget>[
          IconButton(
            tooltip: 'Scan pass',
            onPressed: () =>
                Navigator.pushNamed(context, Routes.scanner, arguments: true),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.reportIncident),
        icon: const Icon(Icons.report_problem_rounded),
        label: const Text('Incident'),
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Active gate passes',
                    value: '${_gatePasses.length}',
                    icon: Icons.badge_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Visitors inside',
                    value: '${_visitors.length}',
                    icon: Icons.groups_rounded,
                    tone: AVITStatusTone.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Movements logged',
                    value: '${_movements.length}',
                    icon: Icons.logout_rounded,
                    tone: AVITStatusTone.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Open incidents',
                    value: '$openIncidents',
                    icon: Icons.warning_rounded,
                    tone: openIncidents == 0
                        ? AVITStatusTone.success
                        : AVITStatusTone.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Vehicle check',
              subtitle: 'Enter a registration number',
            ),
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AVITTextField(
                          label: 'Vehicle number',
                          hint: 'TN01AB1234',
                          controller: _vehicle,
                          required: true,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _checkVehicle(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: AVITButton(
                          label: 'Check',
                          compact: true,
                          expand: false,
                          loading: _checkingVehicle,
                          onPressed:
                              _checkingVehicle ? null : _checkVehicle,
                        ),
                      ),
                    ],
                  ),
                  if (_vehicleRecord != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    AVITStatusChip(
                      label: _vehicleRecord!.verified
                          ? 'Verified • ${_vehicleRecord!.owner} '
                              '(${_vehicleRecord!.type})'
                          : 'Unregistered vehicle',
                      tone: _vehicleRecord!.verified
                          ? AVITStatusTone.success
                          : AVITStatusTone.danger,
                      icon: _vehicleRecord!.verified
                          ? Icons.verified_rounded
                          : Icons.gpp_bad_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Recent gate movements',
              subtitle: 'Latest ${_movements.length} entries and exits',
              actionLabel: 'Scanner',
              onAction: () =>
                  Navigator.pushNamed(context, Routes.scanner, arguments: true),
            ),
            if (_movements.isEmpty)
              const AVITEmptyState(
                title: 'No movement yet',
                message: 'Scan a pass to log the first entry of the day.',
                icon: Icons.directions_walk_rounded,
              )
            else
              AVITCard(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _movements.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      _MovementRow(movement: _movements[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Passes valid right now',
              subtitle: '${_gatePasses.length} gate • '
                  '${_visitors.length} visitor',
            ),
            if (_gatePasses.isEmpty && _visitors.isEmpty)
              const AVITEmptyState(
                title: 'No active passes',
                message: 'Approved gate and visitor passes show up here.',
                icon: Icons.badge_outlined,
              )
            else ...<Widget>[
              for (final GatePass pass in _gatePasses)
                _PassCard(
                  title: pass.studentName,
                  subtitle: '${pass.destination} • until '
                      '${Formatters.time.format(pass.inBy)}',
                  qr: pass.qrToken ?? '',
                  tone: AVITStatusTone.success,
                  child: pass.status == PassStatus.approved
                      ? AVITButton(
                          label: 'Mark as used at gate',
                          compact: true,
                          variant: AVITButtonVariant.secondary,
                          onPressed: () async {
                            await AppScope.of(context)
                                .state
                                .deps
                                .gatePasses
                                .markUsed(
                                  passId: pass.id,
                                  guard: user?.fullName ?? 'Security',
                                );
                            if (!context.mounted) return;
                            showAVITSnackBar(context,
                                message: 'Gate pass closed',
                                tone: AVITSnackTone.success);
                            await _load();
                          },
                        )
                      : null,
                ),
              for (final VisitorPass pass in _visitors)
                _PassCard(
                  title: pass.visitorName,
                  subtitle: '${pass.purpose} • '
                      '${Formatters.monthDay.format(pass.visitDate)}',
                  qr: pass.qrToken ?? '',
                  tone: AVITStatusTone.info,
                  child: pass.status == PassStatus.approved
                      ? AVITButton(
                          label: 'Mark exit',
                          compact: true,
                          variant: AVITButtonVariant.secondary,
                          onPressed: () async {
                            await AppScope.of(context)
                                .state
                                .deps
                                .visitorPasses
                                .markUsed(
                                  passId: pass.id,
                                  guard: user?.fullName ?? 'Security',
                                );
                            if (!context.mounted) return;
                            showAVITSnackBar(context,
                                message: 'Visitor exit recorded',
                                tone: AVITSnackTone.success);
                            await _load();
                          },
                        )
                      : null,
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Incidents',
              subtitle: '${_incidents.length} on record',
              actionLabel: 'File new',
              onAction: () =>
                  Navigator.pushNamed(context, Routes.reportIncident),
            ),
            if (_incidents.isEmpty)
              const AVITEmptyState(
                title: 'Register clear',
                message: 'No incidents reported today.',
                icon: Icons.health_and_safety_rounded,
              )
            else
              for (final IncidentReport r in _incidents.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.report_rounded,
                          color: r.severity == 'high'
                              ? AppColors.danger
                              : r.severity == 'medium'
                                  ? AppColors.warning
                                  : AppColors.info,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(r.title, style: text.titleSmall),
                              Text(
                                '${r.location} • ${Formatters.time.format(r.reportedAt)}',
                                style: text.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        AVITStatusChip(
                          label: r.status,
                          tone: r.status.toLowerCase() == 'resolved'
                              ? AVITStatusTone.success
                              : AVITStatusTone.warning,
                          compact: true,
                        ),
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

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final GateMovement movement;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isEntry = movement.type.toLowerCase() == 'entry';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isEntry
                  ? AppColors.successSurface
                  : AppColors.warningSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEntry ? Icons.login_rounded : Icons.logout_rounded,
              size: 17,
              color: isEntry ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(movement.personName, style: text.titleSmall),
                Text(
                  '${movement.personId} • ${movement.method} • '
                  '${movement.gate}',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                Formatters.time.format(movement.time),
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isEntry ? 'Entry' : 'Exit',
                style: text.labelSmall?.copyWith(
                  color: isEntry ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({
    required this.title,
    required this.subtitle,
    required this.qr,
    required this.tone,
    this.child,
  });

  final String title;
  final String subtitle;
  final String qr;
  final AVITStatusTone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AVITCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title, style: text.titleSmall),
                ),
                if (qr.isNotEmpty)
                  AVITStatusChip(
                    label: 'QR active',
                    tone: tone,
                    icon: Icons.qr_code_rounded,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: text.bodySmall),
            if (child != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
