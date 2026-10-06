import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../models/academics.dart';

/// Weekly timetable grouped by day with a live "happening now" marker.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const List<String> _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  bool _loading = true;
  String? _error;
  List<TimetableEntry> _entries = <TimetableEntry>[];
  int _day = DateTime.now().weekday.clamp(1, 6) - 1;

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
      final List<TimetableEntry> all = await deps.content.timetable();
      if (!mounted) return;
      setState(() {
        _entries = all;
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
        _error = 'Unable to load your timetable';
        _loading = false;
      });
    }
  }

  List<TimetableEntry> get _dayEntries {
    final int weekday = _day + 1;
    return _entries
        .where((TimetableEntry e) => e.weekday == weekday)
        .toList()
      ..sort(
        (TimetableEntry a, TimetableEntry b) =>
            a.startMinutes.compareTo(b.startMinutes),
      );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<TimetableEntry> list = _dayEntries;

    return Scaffold(
      appBar: const AVITAppBar(title: 'Timetable', subtitle: 'Weekly schedule'),
      body: _loading
          ? const LoadingList(itemCount: 5)
          : _error != null
              ? AVITErrorState(message: _error!, onRetry: _load)
              : AVITRefresh(
                  onRefresh: _load,
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: <Widget>[
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _days.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int index) {
                            final bool selected = index == _day;
                            return ChoiceChip(
                              label: Text(_days[index].substring(0, 3)),
                              selected: selected,
                              onSelected: (_) => setState(() => _day = index),
                              selectedColor: AppColors.lightBlue,
                              labelStyle: text.labelMedium?.copyWith(
                                color: selected
                                    ? AppColors.primaryBlue
                                    : null,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primaryBlue
                                    : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.pillShape,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (list.isEmpty)
                        AVITEmptyState(
                          title: 'No classes on ${_days[_day]}',
                          message: 'Enjoy the break — or check another day.',
                          icon: Icons.free_breakfast_rounded,
                          actionLabel: 'Reload',
                          onAction: _load,
                        )
                      else
                        for (final TimetableEntry e in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _TimetableTile(entry: e),
                          ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}

class _TimetableTile extends StatelessWidget {
  const _TimetableTile({required this.entry});

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool now = entry.overlaps(DateTime.now());

    return AVITCard(
      color: now ? AppColors.lightBlue : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: now
                  ? AppColors.success
                  : entry.lab
                      ? AppColors.info
                      : AppColors.royalBlue,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.startTime, style: text.titleSmall),
                Text(entry.endTime, style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.subject,
                        style: text.titleSmall?.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (now)
                      const AVITStatusChip(
                        label: 'Now',
                        tone: AVITStatusTone.success,
                        icon: Icons.play_circle_rounded,
                        compact: true,
                      )
                    else if (entry.lab)
                      const AVITStatusChip(
                        label: 'Lab',
                        tone: AVITStatusTone.info,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.room} • ${entry.faculty} • ${entry.code}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
