import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/academics.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Upcoming examinations grouped by date with hall-ticket guidance.
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  bool _loading = true;
  String? _error;
  List<ExamSchedule> _exams = <ExamSchedule>[];

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
      final List<ExamSchedule> rows = await deps.content.exams();
      rows.sort((ExamSchedule a, ExamSchedule b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _exams = rows;
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
        _error = 'Unable to load the exam schedule';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Examinations'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    final List<ExamSchedule> upcoming =
        _exams.where((ExamSchedule e) => e.isUpcoming).toList();
    final List<ExamSchedule> past = _exams.reversed
        .where((ExamSchedule e) => !e.isUpcoming)
        .toList();

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Examinations',
        subtitle: '${upcoming.length} upcoming',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              color: AppColors.warningSurface,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.badge_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Hall tickets are released 3 days before each exam. '
                      'Carry your student ID along.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Upcoming',
              subtitle: 'Plan your revision window',
            ),
            if (upcoming.isEmpty)
              const AVITEmptyState(
                title: 'No upcoming exams',
                message: 'The next timetable will appear here once published.',
                icon: Icons.assignment_turned_in_rounded,
              )
            else
              for (final ExamSchedule e in upcoming)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 58,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: AppRadius.small,
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                '${e.date.day}',
                                style: text.titleLarge?.copyWith(
                                  color: AppColors.royalBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                Formatters.monthDay.format(e.date),
                                style: text.labelSmall?.copyWith(
                                  color: AppColors.royalBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(e.subject, style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                '${e.code} • ${e.start} – ${e.end} • ${e.room}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AVITStatusChip(
                          label: e.type,
                          tone: AVITStatusTone.warning,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
            if (past.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AVITSectionHeader(
                title: 'Completed',
                subtitle: 'For your records',
              ),
              for (final ExamSchedule e in past)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AVITCard(
                    onTap: () => _showResult(e),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(e.subject, style: text.titleSmall),
                              Text(
                                '${Formatters.dayShort.format(e.date)} • '
                                '${e.type}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text('View', style: text.labelMedium),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showResult(ExamSchedule e) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(e.subject, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${e.code} • ${e.type}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Held on ${Formatters.dayLong.format(e.date)} in ${e.room}.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Results are published on the university portal within 15 '
              'working days.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
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
}
