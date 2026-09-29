import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Academic hub: attendance summary plus shortcuts to every study screen.
class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> {
  bool _loading = true;
  double _attendance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    try {
      final double value =
          await AppScope.of(context).state.deps.content.overallAttendance();
      if (!mounted) return;
      setState(() {
        _attendance = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingList(itemCount: 4);

    return Scaffold(
      appBar: AVITAppBar(title: 'Academics', subtitle: 'Your study hub'),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              child: Row(
                children: <Widget>[
                  ProgressRing(
                    value: (_attendance / 100).clamp(0, 1),
                    size: 92,
                    label: '${_attendance.round()}%',
                    tone: _attendance >= 75
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Overall attendance',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _attendance >= 75
                              ? 'You are safely above the 75% requirement.'
                              : 'Below 75% — attend the next few classes.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AVITButton(
                          label: 'Subject-wise details',
                          compact: true,
                          expand: false,
                          variant: AVITButtonVariant.secondary,
                          onPressed: () =>
                              Navigator.pushNamed(context, Routes.attendance),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Study tools',
              subtitle: 'Everything for the semester',
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.35,
              children: <Widget>[
                AVITServiceCard(
                  title: 'Timetable',
                  subtitle: 'Today & week plan',
                  icon: Icons.schedule_rounded,
                  onTap: () => Navigator.pushNamed(context, Routes.timetable),
                ),
                AVITServiceCard(
                  title: 'Attendance',
                  subtitle: 'Subject wise %',
                  icon: Icons.pie_chart_rounded,
                  tone: AVITStatusTone.success,
                  onTap: () => Navigator.pushNamed(context, Routes.attendance),
                ),
                AVITServiceCard(
                  title: 'Courses',
                  subtitle: 'Syllabus & faculty',
                  icon: Icons.menu_book_rounded,
                  tone: AVITStatusTone.info,
                  onTap: () => Navigator.pushNamed(context, Routes.courses),
                ),
                AVITServiceCard(
                  title: 'Examinations',
                  subtitle: 'Dates & halls',
                  icon: Icons.assignment_rounded,
                  tone: AVITStatusTone.warning,
                  onTap: () =>
                      Navigator.pushNamed(context, Routes.examinations),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AVITServiceCard(
              title: 'Academic calendar',
              subtitle: 'Holidays, exam windows and events',
              icon: Icons.calendar_month_rounded,
              tone: AVITStatusTone.brand,
              onTap: () =>
                  Navigator.pushNamed(context, Routes.academicCalendar),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
