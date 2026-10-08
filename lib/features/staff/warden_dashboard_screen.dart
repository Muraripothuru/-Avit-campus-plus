import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/pass.dart';
import '../../models/safety.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/student_profile_sheet.dart';

/// Warden console: approve gate/visitor requests and track hostel matters.
class WardenDashboardScreen extends StatefulWidget {
  const WardenDashboardScreen({super.key, this.embedded = false});

  /// When true the shell supplies the scaffold chrome and this screen only
  /// renders its body.
  final bool embedded;

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
      // The console is an approval inbox â€” only requests awaiting a decision
      // belong here (already-reviewed rows live on their own screens).
      final List<GatePass> gates = (await deps.warden.gatePassRequests())
          .where((GatePass p) => p.status == PassStatus.pending)
          .toList();
      final List<VisitorPass> visitors = (await deps.warden.visitorRequests())
          .where((VisitorPass v) => v.status == PassStatus.pending)
          .toList();
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
          comment: approve
              ? 'Approved by warden'
              : 'Not permitted at this time',
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
      showAVITSnackBar(
        context,
        message: 'Could not update the request',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 6);
    if (_error != null) {
      return Scaffold(
        appBar: widget.embedded
            ? null
            : const AVITAppBar(title: 'Warden Console'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AVITAppBar(
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
              actionLabel: 'Review',
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
                AVITApprovalCard(
                  title: pass.studentName,
                  meta: '${pass.studentId} â€¢ ${pass.destination}',
                  reason: pass.reason,
                  window:
                      '${Formatters.monthDay.format(pass.outAt)} '
                      '${Formatters.time.format(pass.outAt)} â€“ '
                      '${Formatters.time.format(pass.inBy)}',
                  busy: _busyId == pass.id,
                  onApprove: () =>
                      _decide(id: pass.id, approve: true, gate: true),
                  onReject: () =>
                      _decide(id: pass.id, approve: false, gate: true),
                  onOpen: () =>
                      showStudentProfileSheet(context, pass.studentId),
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
                AVITApprovalCard(
                  title: pass.visitorName,
                  meta: '${pass.idType} â€¢ hosted by ${pass.hostStudentName}',
                  reason: pass.purpose,
                  window:
                      '${Formatters.monthDay.format(pass.visitDate)} â€¢ '
                      '${pass.visitorPhone}',
                  busy: _busyId == pass.id,
                  onApprove: () =>
                      _decide(id: pass.id, approve: true, gate: false),
                  onReject: () =>
                      _decide(id: pass.id, approve: false, gate: false),
                  onOpen: () =>
                      showStudentProfileSheet(context, pass.hostStudentId),
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
                        title: Text(
                          _lateReturns[i].personName,
                          style: text.titleSmall,
                        ),
                        subtitle: Text(
                          '${_lateReturns[i].personId} â€¢ due back by '
                          '${Formatters.time.format(_lateReturns[i].time)}',
                          style: text.labelSmall,
                        ),
                        trailing: AVITStatusChip(
                          label: 'Overdue',
                          tone: AVITStatusTone.warning,
                          compact: true,
                        ),
                        onTap: () => showStudentProfileSheet(
                          context,
                          _lateReturns[i].personId,
                        ),
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
                          '${c.category} â€¢ ${c.raisedBy} â€¢ '
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
