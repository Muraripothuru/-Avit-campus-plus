import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../models/campus_services.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Campus services hub: searchable, grouped catalogue of every facility the
/// student can reach from one place.
class CampusScreen extends StatefulWidget {
  const CampusScreen({super.key});

  @override
  State<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends State<CampusScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _group = 'All';
  bool _loading = true;
  String? _error;

  List<CampusLocation> _locations = <CampusLocation>[];
  int _pendingPasses = 0;

  @override
  bool get wantKeepAlive => true;

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
      final List<CampusLocation> places = await deps.campus.locations();
      if (!mounted) return;
      setState(() {
        _locations = places;
        _pendingPasses = deps.localStore.pendingGatePasses +
            deps.localStore.pendingVisitorPasses;
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
        _error = 'Unable to load campus services';
        _loading = false;
      });
    }
  }

  static const Map<String, List<_Service>> _groups =
      <String, List<_Service>>{
        'Academics': <_Service>[
          _Service('Timetable', Icons.schedule_rounded, Routes.timetable,
              'Week at a glance', AVITStatusTone.brand),
          _Service('Attendance', Icons.pie_chart_rounded, Routes.attendance,
              'Subject-wise tracking', AVITStatusTone.brand),
          _Service('Courses', Icons.menu_book_rounded, Routes.courses,
              'Syllabus & credits', AVITStatusTone.brand),
          _Service('Examinations', Icons.assignment_rounded, Routes.examinations,
              'Hall tickets & dates', AVITStatusTone.warning),
          _Service('Academic Calendar', Icons.calendar_month_rounded,
              Routes.academicCalendar, 'Important dates', AVITStatusTone.info),
        ],
        'Passes & Movement': <_Service>[
          _Service('Gate Pass', Icons.qr_code_rounded, Routes.gatePass,
              'Exit approval + QR', AVITStatusTone.brand, badgeKey: 'gate'),
          _Service('Visitor Pass', Icons.badge_rounded, Routes.visitorPass,
              'Invite someone on campus', AVITStatusTone.brand,
              badgeKey: 'visitor'),
          _Service('Transport', Icons.directions_bus_rounded, Routes.transport,
              'Bus routes & seats', AVITStatusTone.info),
          _Service('Scanner', Icons.qr_code_scanner_rounded, Routes.scanner,
              'Scan any AVIT pass', AVITStatusTone.info),
        ],
        'On Campus': <_Service>[
          _Service('Service Request', Icons.edit_note_rounded,
              Routes.serviceRequest, 'Ask any campus unit', AVITStatusTone.brand),
          _Service('Smart Queue', Icons.hourglass_top_rounded, Routes.smartQueue,
              'Skip the waiting line', AVITStatusTone.info),
          _Service('Campus Map', Icons.map_rounded, Routes.campusMap,
              'Find any building', AVITStatusTone.info),
          _Service('Library', Icons.local_library_rounded, Routes.library,
              'Hours, books, dues', AVITStatusTone.brand),
          _Service('Cafeteria', Icons.restaurant_rounded, Routes.cafeteria,
              'Menu & timings', AVITStatusTone.success),
          _Service('Hostel', Icons.apartment_rounded, Routes.hostel,
              'Rooms, mess, requests', AVITStatusTone.info),
        ],
        'Safety': <_Service>[
          _Service('Emergency', Icons.emergency_rounded, Routes.emergency,
              'One tap to alert security', AVITStatusTone.danger),
          _Service('Report Incident', Icons.report_problem_rounded,
              Routes.reportIncident, 'Confidential report', AVITStatusTone.danger),
          _Service('Complaints', Icons.support_agent_rounded, Routes.complaints,
              'Track your requests', AVITStatusTone.warning),
        ],
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return AVITErrorState(message: _error!, onRetry: _load);
    }

    final List<String> tabs = <String>['All', ..._groups.keys];

    return AVITRefresh(
      onRefresh: _load,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITSearchField(
            controller: _search,
            hint: 'Search services, buildings, facilities',
            onChanged: (String v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final bool selected = _group == tabs[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  child: ChoiceChip(
                    label: Text(tabs[index]),
                    selected: selected,
                    onSelected: (_) => setState(() => _group = tabs[index]),
                    selectedColor: AppColors.lightBlue,
                    labelStyle: text.labelMedium?.copyWith(
                      color: selected ? AppColors.primaryBlue : null,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryBlue
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillShape,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pendingPasses > 0) ...<Widget>[
            AVITCard(
              color: AppColors.warningSurface,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.pending_actions_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$_pendingPasses pass request${_pendingPasses == 1 ? '' : 's'} '
                      'waiting for approval',
                      style: text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.gatePass),
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final MapEntry<String, List<_Service>> entry
              in _groups.entries)
            if (_group == 'All' || _group == entry.key) ...<Widget>[
              AVITSectionHeader(
                title: entry.key,
                subtitle: '${entry.value.length} services',
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.86,
                children: <Widget>[
                  for (final _Service service in entry.value)
                    if (_matches(service))
                      AVITServiceCard(
                        title: service.title,
                        subtitle: service.subtitle,
                        icon: service.icon,
                        tone: service.tone,
                        badge: service.badgeKey == 'gate'
                            ? _pendingGate
                            : service.badgeKey == 'visitor'
                                ? _pendingVisitor
                                : null,
                        onTap: () =>
                            Navigator.pushNamed(context, service.route),
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (_locations.isNotEmpty && _query.isNotEmpty) ...<Widget>[
            AVITSectionHeader(
              title: 'Places matching "$_query"',
              subtitle: '${_matchingLocations.length} result(s)',
            ),
            for (final CampusLocation place in _matchingLocations)
              AVITCard(
                onTap: () => Navigator.pushNamed(
                  context,
                  Routes.campusMap,
                  arguments: place.id,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppRadius.small,
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: AppColors.royalBlue,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(place.name, style: text.titleSmall),
                          Text(
                            '${place.category} • ${place.hours.isEmpty ? 'Open now' : place.hours}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
          ],
          if (!_hasAnyResult)
            const AVITEmptyState(
              title: 'Nothing matches that search',
              message: 'Try a different word, or clear the filter chips.',
              icon: Icons.search_off_rounded,
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  bool _matches(_Service service) {
    if (_query.isEmpty) return true;
    final String q = _query.toLowerCase();
    return service.title.toLowerCase().contains(q) ||
        service.subtitle.toLowerCase().contains(q);
  }

  List<CampusLocation> get _matchingLocations => _locations
      .where((CampusLocation p) => p.matches(_query))
      .toList();

  bool get _hasAnyResult {
    for (final MapEntry<String, List<_Service>> entry in _groups.entries) {
      if (_group != 'All' && _group != entry.key) continue;
      if (entry.value.any(_matches)) return true;
    }
    return _query.isEmpty ? true : _matchingLocations.isNotEmpty;
  }

  int get _pendingGate => AppScope.of(context)
      .state
      .deps
      .localStore
      .pendingGatePasses;
  int get _pendingVisitor => AppScope.of(context)
      .state
      .deps
      .localStore
      .pendingVisitorPasses;
}

class _Service {
  const _Service(
    this.title,
    this.icon,
    this.route,
    this.subtitle,
    this.tone, {
    this.badgeKey,
  });

  final String title;
  final IconData icon;
  final String route;
  final String subtitle;
  final AVITStatusTone tone;
  final String? badgeKey;
}
