import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/snackbar.dart';
import '../../models/campus_services.dart';
import '../../navigation/service_catalog.dart';
import 'service_detail_screen.dart';
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
        _pendingPasses =
            deps.localStore.pendingGatePasses +
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

  /// Shared with the global search so both surfaces list identical services.
  static const Map<String, List<ServiceEntry>> _groups = ServiceCatalog.groups;

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
          for (final MapEntry<String, List<ServiceEntry>> entry
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
                  for (final ServiceEntry service in entry.value)
                    if (_matches(service))
                      AVITServiceCard(
                        title: service.title,
                        subtitle: service.subtitle,
                        icon: service.icon,
                        tone: service.tone,
                        heroTag: 'service-icon-${service.title}',
                        badge: service.badgeKey == 'gate'
                            ? _pendingGate
                            : service.badgeKey == 'visitor'
                            ? _pendingVisitor
                            : null,
                        onTap: () => _openService(service),
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

  /// Opens Service Details for the tapped [service] with a direct
  /// `Navigator.push` + `MaterialPageRoute`, passing the selected object so
  /// the detail route never hard-codes its content.
  ///
  /// The detail route returns `ServiceDetailScreen.resultRequested`, which is
  /// confirmed here with a SnackBar once it comes back.
  Future<void> _openService(ServiceEntry service) async {
    final Object? result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: Routes.serviceDetail),
        builder: (BuildContext _) => ServiceDetailScreen(service: service),
      ),
    );
    if (!mounted || result != ServiceDetailScreen.resultRequested) return;
    showAVITSnackBar(
      context,
      message: 'Request sent — the ${service.title} team will contact you',
      tone: AVITSnackTone.success,
    );
  }

  bool _matches(ServiceEntry service) => service.matches(_query);

  List<CampusLocation> get _matchingLocations =>
      _locations.where((CampusLocation p) => p.matches(_query)).toList();

  bool get _hasAnyResult {
    for (final MapEntry<String, List<ServiceEntry>> entry in _groups.entries) {
      if (_group != 'All' && _group != entry.key) continue;
      if (entry.value.any(_matches)) return true;
    }
    return _query.isEmpty ? true : _matchingLocations.isNotEmpty;
  }

  int get _pendingGate =>
      AppScope.of(context).state.deps.localStore.pendingGatePasses;
  int get _pendingVisitor =>
      AppScope.of(context).state.deps.localStore.pendingVisitorPasses;
}
