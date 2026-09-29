import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
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

/// Warden console: approve gate/visitor requests and track hostel matters.
class WardenDashboardScreen extends StatefulWidget {
  const WardenDashboardScreen({super.key});

  @override
  State<WardenDashboardScreen> createState() => _WardenDashboardScreenState();
}

class _WardenDashboardScreenState extends State<WardenDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<GatePass> _gateRequests = <GatePass>[];
  List<VisitorPass> _visitorRequests = <VisitorPass>[];
  List<Complaint> _complaints = <Complaint>[];
  List<GateMovement> _lateReturns = <GateMovement>[];
  String? _busyId;

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
      final List<GatePass> gates = await deps.warden.gatePassRequests();
      final List<VisitorPass> visitors = await deps.warden.visitorRequests();
      final List<Complaint> complaints = await deps.warden.hostelComplaints();
      final List<GateMovement> late = await deps.warden.lateReturns();
      if (!mounted) return;
      setState(() {
        _gateRequests = gates;
        _visitorRequests = visitors;
        _complaints = complaints;
        _lateReturns = late;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to reach the warden service';
        _loading = false;
      });
    }
  }

  Future<void> _decide({
    required String id,
    required bool approve,
    required bool gate,
  }) async {
    final AppState state = AppScope.of(context).state;
    final String reviewer = state.user?.fullName ?? 'Warden';
    setState(() => _busyId = id);
    try {
      if (gate) {
        await state.deps.gatePasses.decide(
          passId: id,
          approve: approve,
          reviewer: reviewer,
          comment: approve ? 'Approved by warden' : 'Not permitted at this time',
        );
      } else {
        await state.deps.visitorPasses.decide(
          passId: id,
          approve: approve,
          reviewer: reviewer,
          comment: approve ? 'Approved by warden' : 'Visitor not allowed',
        );
      }
      if (!mounted) return;
      setState(() => _busyId = null);
      showAVITSnackBar(
        context,
        message: approve ? 'Request approved' : 'Request declined',
        tone: approve ? AVITSnackTone.success : AVITSnackTone.warning,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showAVITSnackBar(context,
          message: 'Could not update the request',
          tone: AVITSnackTone.error);
    }
  }

  Future<void> _showStudent(String studentId) async {
    final AppUser? profile =
        await AppScope.of(context).state.deps.warden.studentProfile(studentId);
    if (!mounted) return;
    final TextTheme text = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
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
        child: profile == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('No profile found for $studentId',
                      style: text.titleSmall),
                  const SizedBox(height: AppSpacing.md),
                  AVITButton(
                    label: 'Close',
                    variant: AVITButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(profile.fullName, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.displayId} • ${profile.programmeShort}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      AVITStatusChip(
                        label: profile.hostel == null || profile.hostel!.isEmpty
                            ? 'Day scholar'
                            : profile.hostel!,
                        tone: AVITStatusTone.brand,
                        icon: Icons.apartment_rounded,
                        compact: true,
                      ),
                      AVITStatusChip(
                        label:
                            'Sem ${profile.semester ?? '—'}',
                        tone: AVITStatusTone.info,
                        compact: true,
                      ),
                      if (profile.phone.isNotEmpty)
                        AVITStatusChip(
                          label: profile.phone,
                          tone: AVITStatusTone.neutral,
                          icon: Icons.phone_rounded,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITButton(
                    label: 'Done',
                    variant: AVITButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 6);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Warden Console'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Warden Console',
        subtitle: 'Hostel approvals & welfare',
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
                    label: 'Gate requests',
                    value: '${_gateRequests.length}',
                    icon: Icons.meeting_room_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Visitor requests',
                    value: '${_visitorRequests.length}',
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
                    label: 'Late returns',
                    value: '${_lateReturns.length}',
                    icon: Icons.nightlight_round,
                    tone: AVITStatusTone.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Hostel complaints',
                    value: '${_complaints.length}',
                    icon: Icons.support_agent_rounded,
                    tone: AVITStatusTone.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Gate pass requests',
              subtitle: 'Approve or decline student leave',
              actionLabel: 'All passes',
              onAction: () => Navigator.pushNamed(context, Routes.gatePass),
            ),
            if (_gateRequests.isEmpty)
              const AVITEmptyState(
                title: 'Inbox clear',
                message: 'No pending gate pass requests.',
                icon: Icons.inbox_rounded,
              )
            else
              for (final GatePass pass in _gateRequests)
                _ApprovalCard(
                  title: pass.studentName,
                  meta: '${pass.studentId} • ${pass.destination}',
                  reason: pass.reason,
                  window: '${Formatters.monthDay.format(pass.outAt)} '
                      '${Formatters.time.format(pass.outAt)} – '
                      '${Formatters.time.format(pass.inBy)}',
                  busy: _busyId == pass.id,
                  onApprove: () =>
                      _decide(id: pass.id, approve: true, gate: true),
                  onReject: () =>
                      _decide(id: pass.id, approve: false, gate: true),
                  onOpen: () => _showStudent(pass.studentId),
                ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Visitor requests',
              subtitle: 'Campus entry for external guests',
              actionLabel: 'All visitors',
              onAction: () => Navigator.pushNamed(context, Routes.visitorPass),
            ),
            if (_visitorRequests.isEmpty)
              const AVITEmptyState(
                title: 'Inbox clear',
                message: 'No pending visitor requests.',
                icon: Icons.person_add_alt_rounded,
              )
            else
              for (final VisitorPass pass in _visitorRequests)
                _ApprovalCard(
                  title: pass.visitorName,
                  meta: '${pass.idType} • hosted by ${pass.hostStudentName}',
                  reason: pass.purpose,
                  window:
                      '${Formatters.monthDay.format(pass.visitDate)} • '
                      '${pass.visitorPhone}',
                  busy: _busyId == pass.id,
                  onApprove: () =>
                      _decide(id: pass.id, approve: true, gate: false),
                  onReject: () =>
                      _decide(id: pass.id, approve: false, gate: false),
                  onOpen: () => _showStudent(pass.hostStudentId),
                ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Late returns',
              subtitle: 'Students yet to return to campus',
            ),
            if (_lateReturns.isEmpty)
              const AVITEmptyState(
                title: 'Everyone is back',
                message: 'No late returns recorded for this shift.',
                icon: Icons.bedtime_rounded,
              )
            else
              AVITCard(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _lateReturns.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_rounded),
                        title: Text(_lateReturns[i].personName,
                            style: text.titleSmall),
                        subtitle: Text(
                          '${_lateReturns[i].personId} • due back by '
                          '${Formatters.time.format(_lateReturns[i].time)}',
                          style: text.labelSmall,
                        ),
                        trailing: AVITStatusChip(
                          label: 'Overdue',
                          tone: AVITStatusTone.warning,
                          compact: true,
                        ),
                        onTap: () => _showStudent(_lateReturns[i].personId),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Hostel complaints',
              subtitle: '${_complaints.length} awaiting action',
              actionLabel: 'Open list',
              onAction: () => Navigator.pushNamed(context, Routes.complaints),
            ),
            if (_complaints.isEmpty)
              const AVITEmptyState(
                title: 'All quiet',
                message: 'No hostel complaints pending.',
                icon: Icons.emoji_food_beverage_rounded,
              )
            else
              for (final Complaint c in _complaints)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(c.subject, style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: c.status,
                              tone: c.status.toLowerCase() == 'resolved'
                                  ? AVITStatusTone.success
                                  : AVITStatusTone.warning,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.category} • ${c.raisedBy} • '
                          '${Formatters.monthDay.format(c.createdAt)}',
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(c.description, style: text.bodySmall),
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

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.meta,
    required this.reason,
    required this.window,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  final String title;
  final String meta;
  final String reason;
  final String window;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AVITCard(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title, style: text.titleSmall),
                ),
                AVITStatusChip(
                  label: 'Pending',
                  tone: AVITStatusTone.warning,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(meta, style: text.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(reason, style: text.bodySmall),
            const SizedBox(height: 4),
            Text(window, style: text.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITButton(
                    label: 'Approve',
                    compact: true,
                    expand: false,
                    variant: AVITButtonVariant.success,
                    loading: busy,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITButton(
                    label: 'Decline',
                    compact: true,
                    expand: false,
                    variant: AVITButtonVariant.ghost,
                    onPressed: busy ? null : onReject,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
