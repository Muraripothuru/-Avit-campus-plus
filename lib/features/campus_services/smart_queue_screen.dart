import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/snackbar.dart';
import '../../models/campus_services.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Smart queue: live counters, token issuance and estimated wait times.
class SmartQueueScreen extends StatefulWidget {
  const SmartQueueScreen({super.key});

  @override
  State<SmartQueueScreen> createState() => _SmartQueueScreenState();
}

class _SmartQueueScreenState extends State<SmartQueueScreen> {
  bool _loading = true;
  String? _error;
  List<QueueCounter> _counters = <QueueCounter>[];
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
      final List<QueueCounter> rows = await deps.campus.queueCounters();
      if (!mounted) return;
      setState(() {
        _counters = rows;
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
        _error = 'Unable to load the queue status';
        _loading = false;
      });
    }
  }

  Future<void> _takeToken(QueueCounter counter) async {
    final AppUser? me = AppScope.of(context).state.user;
    setState(() => _busyId = counter.id);
    final AppDependencies deps = AppScope.of(context).state.deps;
    try {
      final QueueCounter updated = await deps.campus.takeToken(
        counter.id,
        me?.studentId ?? '',
      );
      if (!mounted) return;
      setState(() {
        final int i = _counters
            .indexWhere((QueueCounter c) => c.id == counter.id);
        if (i >= 0) _counters[i] = updated;
        _busyId = null;
      });
      showAVITSnackBar(
        context,
        message: 'Token T${updated.yourToken} issued for ${updated.name}',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showAVITSnackBar(context, message: e.userMessage, tone: AVITSnackTone.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showAVITSnackBar(
        context,
        message: 'Unable to issue a token right now',
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
        appBar: const AVITAppBar(title: 'Smart Queue'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Smart Queue',
        subtitle: 'Live counter status',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITSectionHeader(
              title: 'Counters',
              subtitle: 'Take a token and wait from your phone',
            ),
            if (_counters.isEmpty)
              const AVITEmptyState(
                title: 'No counters open',
                message: 'Counter availability will appear here.',
                icon: Icons.hourglass_top_rounded,
              )
            else
              for (final QueueCounter counter in _counters)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: counter.open
                                    ? AppColors.lightBlue
                                    : AppColors.surfaceMuted,
                                borderRadius: AppRadius.small,
                              ),
                              child: Icon(
                                Icons.support_agent_rounded,
                                color: counter.open
                                    ? AppColors.royalBlue
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(counter.name, style: text.titleSmall),
                                  Text(
                                    counter.location,
                                    style: text.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            AVITStatusChip(
                              label: counter.open ? 'Open' : 'Closed',
                              tone: counter.open
                                  ? AVITStatusTone.success
                                  : AVITStatusTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _MiniStat(
                                label: 'Now serving',
                                value: 'T${counter.currentToken}',
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'Your token',
                                value: counter.yourToken == 0
                                    ? '—'
                                    : 'T${counter.yourToken}',
                                highlight: counter.yourToken > 0,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'People ahead',
                                value: '${counter.peopleAhead}',
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: 'Est. wait',
                                value: counter.yourToken == 0
                                    ? '—'
                                    : '${counter.estimatedWaitMinutes} min',
                              ),
                            ),
                          ],
                        ),
                        if (counter.yourToken > 0) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          ProgressRing(
                            value: counter.peopleAhead == 0
                                ? 1
                                : 1 / (counter.peopleAhead + 1),
                            size: 64,
                            strokeWidth: 7,
                            label: '${counter.peopleAhead}',
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        AVITButton(
                          label: counter.yourToken > 0
                              ? 'Token issued'
                              : 'Take a token',
                          icon: counter.yourToken > 0
                              ? Icons.check_circle_rounded
                              : Icons.confirmation_number_rounded,
                          loading: _busyId == counter.id,
                          onPressed: !counter.open || counter.yourToken > 0
                              ? null
                              : () => _takeToken(counter),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.primaryBlue : null,
          ),
        ),
        Text(
          label,
          style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
