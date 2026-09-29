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

/// Academic calendar: holidays, exam windows and campus events in order.
class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() =>
      _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  bool _loading = true;
  String? _error;
  List<AcademicDate> _dates = <AcademicDate>[];
  bool _showPast = false;

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
      final List<AcademicDate> rows = await deps.content.academicCalendar();
      rows.sort((AcademicDate a, AcademicDate b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _dates = rows;
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
        _error = 'Unable to load the academic calendar';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Academic Calendar'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    final List<AcademicDate> visible = _dates
        .where((AcademicDate d) => _showPast || !d.isPast)
        .toList();

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Academic Calendar',
        subtitle: '${visible.length} dates',
        actions: <Widget>[
          TextButton(
            onPressed: () => setState(() => _showPast = !_showPast),
            child: Text(_showPast ? 'Hide past' : 'Show past'),
          ),
        ],
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            if (visible.isEmpty)
              const AVITEmptyState(
                title: 'Nothing scheduled',
                message: 'Upcoming academic dates will appear here.',
                icon: Icons.calendar_month_rounded,
              )
            else
              for (final AcademicDate d in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 46,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceFor(d),
                            borderRadius: AppRadius.small,
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                '${d.date.day}',
                                style: text.titleLarge?.copyWith(
                                  color: _accentFor(d),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                Formatters.monthDay.format(d.date),
                                style: text.labelSmall?.copyWith(
                                  color: _accentFor(d),
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
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      d.title,
                                      style: text.titleSmall,
                                    ),
                                  ),
                                  AVITStatusChip(
                                    label: _labelFor(d),
                                    tone: _toneFor(d),
                                    compact: true,
                                  ),
                                ],
                              ),
                              if (d.detail.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(d.detail, style: text.bodySmall),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                d.isPast
                                    ? 'Completed'
                                    : Formatters.relativeDay(d.date),
                                style: text.labelSmall,
                              ),
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

  String _labelFor(AcademicDate d) => switch (d.kind) {
    'exam' => 'Examination',
    'holiday' => 'Holiday',
    'event' => 'Event',
    _ => 'Info',
  };

  AVITStatusTone _toneFor(AcademicDate d) => switch (d.kind) {
    'exam' => AVITStatusTone.warning,
    'holiday' => AVITStatusTone.success,
    'event' => AVITStatusTone.brand,
    _ => AVITStatusTone.info,
  };

  Color _accentFor(AcademicDate d) => switch (d.kind) {
    'exam' => AppColors.warning,
    'holiday' => AppColors.success,
    'event' => AppColors.royalBlue,
    _ => AppColors.info,
  };

  Color _surfaceFor(AcademicDate d) => switch (d.kind) {
    'exam' => AppColors.warningSurface,
    'holiday' => AppColors.successSurface,
    'event' => AppColors.lightBlue,
    _ => AppColors.infoSurface,
  };
}
