import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../models/academics.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_feedback.dart';

/// Subject-wise attendance with an overall ring, shortfall guidance and
/// per-subject progress bars.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  String? _error;
  List<AttendanceRecord> _records = <AttendanceRecord>[];
  double _overall = 0;
  String _sortBy = 'Lowest first';

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
      final List<AttendanceRecord> rows = await deps.content.attendance();
      final double overall = await deps.content.overallAttendance();
      if (!mounted) return;
      setState(() {
        _records = rows;
        _overall = overall;
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
        _error = 'Unable to load attendance';
        _loading = false;
      });
    }
  }

  List<AttendanceRecord> get _sorted {
    final List<AttendanceRecord> rows = List<AttendanceRecord>.of(_records);
    if (_sortBy == 'Lowest first') {
      rows.sort((AttendanceRecord a, AttendanceRecord b) =>
          a.percentage.compareTo(b.percentage));
    } else if (_sortBy == 'Highest first') {
      rows.sort((AttendanceRecord a, AttendanceRecord b) =>
          b.percentage.compareTo(a.percentage));
    } else {
      rows.sort(
        (AttendanceRecord a, AttendanceRecord b) =>
            a.subject.compareTo(b.subject),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Attendance'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    final int risky = _records
        .where((AttendanceRecord r) => r.percentage < r.requiredPercent)
        .length;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Attendance',
        subtitle: 'Semester progress',
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (String v) => setState(() => _sortBy = v),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final String option in const <String>[
                'Lowest first',
                'Highest first',
                'Subject A-Z',
              ])
                PopupMenuItem<String>(value: option, child: Text(option)),
            ],
          ),
        ],
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              child: Row(
                children: <Widget>[
                  ProgressRing(
                    value: _overall / 100,
                    size: 104,
                    strokeWidth: 10,
                    label: '${_overall.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Overall attendance', style: text.titleMedium),
                        const SizedBox(height: 6),
                        AVITStatusChip(
                          label: _overall >= 75
                              ? 'Requirement met'
                              : 'Below 75% requirement',
                          tone: _overall >= 75
                              ? AVITStatusTone.success
                              : AVITStatusTone.danger,
                          icon: _overall >= 75
                              ? Icons.verified_rounded
                              : Icons.warning_rounded,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          risky == 0
                              ? 'All subjects are comfortably above the limit.'
                              : '$risky subject${risky == 1 ? '' : 's'} '
                                  'still below the required percentage.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'By subject',
              subtitle: 'Sorted by $_sortBy',
            ),
            for (final AttendanceRecord r in _sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AVITCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(r.subject, style: text.titleSmall),
                          ),
                          AVITStatusChip(
                            label: '${r.percentage.toStringAsFixed(0)}%',
                            tone: _toneFor(r),
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.code} • ${r.attended} of ${r.total} classes '
                        '• required ${r.requiredPercent}%',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      BarRow(
                        label: 'Completed',
                        value: r.percentage / 100,
                        caption: r.status.label,
                        color: r.percentage >= r.requiredPercent
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      if (r.percentage < r.requiredPercent) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Attend ${r.classesToReachRequired} more '
                          'consecutive class${r.classesToReachRequired == 1 ? '' : 'es'} '
                          'to reach ${r.requiredPercent}%.',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
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

  AVITStatusTone _toneFor(AttendanceRecord r) {
    if (r.percentage >= 85) return AVITStatusTone.success;
    if (r.percentage >= r.requiredPercent) return AVITStatusTone.warning;
    return AVITStatusTone.danger;
  }
}
