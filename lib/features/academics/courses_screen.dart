import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../models/academics.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Course catalogue with credit totals and category filtering.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _loading = true;
  String? _error;
  List<Course> _courses = <Course>[];
  String _category = 'All';
  final TextEditingController _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Course> rows = await deps.content.courses();
      if (!mounted) return;
      setState(() {
        _courses = rows;
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
        _error = 'Unable to load courses';
        _loading = false;
      });
    }
  }

  List<String> get _categories => <String>{
        'All',
        for (final Course c in _courses) c.category,
      }.toList();

  List<Course> get _visible {
    final String q = _search.text.trim().toLowerCase();
    return _courses.where((Course c) {
      final bool okCategory = _category == 'All' || c.category == _category;
      final bool okQuery = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.faculty.toLowerCase().contains(q);
      return okCategory && okQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int credits =
        _courses.fold<int>(0, (int sum, Course c) => sum + c.credits);

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Courses'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(title: 'Courses', subtitle: '${_courses.length} subjects'),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Subjects this semester',
                    value: '${_courses.length}',
                    icon: Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Total credits',
                    value: '$credits',
                    icon: Icons.stars_rounded,
                    tone: AVITStatusTone.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AVITSearchField(
              controller: _search,
              hint: 'Search by subject, code or faculty',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final bool selected = _categories[index] == _category;
                  return ChoiceChip(
                    label: Text(_categories[index]),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _category = _categories[index]),
                    selectedColor: AppColors.lightBlue,
                    labelStyle: text.labelMedium?.copyWith(
                      color: selected ? AppColors.primaryBlue : null,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color:
                          selected ? AppColors.primaryBlue : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillShape,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_visible.isEmpty)
              const AVITEmptyState(
                title: 'No matching courses',
                message: 'Try a different keyword or clear the filter.',
                icon: Icons.search_off_rounded,
              )
            else
              for (final Course c in _visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: AppRadius.small,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.code.length > 4 ? c.code.substring(0, 4) : c.code,
                            style: text.labelSmall?.copyWith(
                              color: AppColors.royalBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(c.name, style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                '${c.code} • ${c.faculty}',
                                style: text.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: <Widget>[
                                  AVITStatusChip(
                                    label: c.category,
                                    tone: AVITStatusTone.brand,
                                    compact: true,
                                  ),
                                  const SizedBox(width: 6),
                                  AVITStatusChip(
                                    label: '${c.credits} credits',
                                    tone: AVITStatusTone.neutral,
                                    compact: true,
                                  ),
                                ],
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
}
