import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/academics.dart';
import '../../models/announcement.dart';
import '../../models/campus_event.dart';
import '../../models/campus_services.dart';
import '../../navigation/service_catalog.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// One hit from the cross-app index.
class _Hit {
  const _Hit({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String section;
  final VoidCallback onOpen;
}

/// Global search across services, events, announcements, courses and places.
///
/// The service list is the same [ServiceCatalog] the Campus tab renders, so
/// anything visible there is findable here by name.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();

  bool _loading = true;
  String? _error;
  String _text = '';

  List<CampusEvent> _events = <CampusEvent>[];
  List<Announcement> _announcements = <Announcement>[];
  List<Course> _courses = <Course>[];
  List<CampusLocation> _places = <CampusLocation>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context).state;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<CampusEvent> events = await state.deps.activities.events();
      final List<Announcement> announcements = await state.deps.content
          .announcements();
      final List<Course> courses = await state.deps.content.courses();
      final List<CampusLocation> places = await state.deps.campus.locations();
      if (!mounted) return;
      setState(() {
        _events = events;
        _announcements = announcements;
        _courses = courses;
        _places = places;
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
        _error = 'Unable to build the search index';
        _loading = false;
      });
    }
  }

  String get _normalised => _text.trim().toLowerCase();

  bool _has(String haystack) {
    if (_normalised.isEmpty) return true;
    return haystack.toLowerCase().contains(_normalised);
  }

  final List<_Hit> _results = <_Hit>[];

  void _buildHits() {
    _results.clear();

    for (final ServiceEntry s in ServiceCatalog.all) {
      if (_has('${s.title} ${s.subtitle}')) {
        _results.add(
          _Hit(
            title: s.title,
            subtitle: s.subtitle,
            icon: s.icon,
            section: 'Services',
            onOpen: () => Navigator.pushNamed(context, s.route),
          ),
        );
      }
    }

    for (final CampusEvent e in _events) {
      if (_has('${e.title} ${e.organizer} ${e.location}')) {
        _results.add(
          _Hit(
            title: e.title,
            subtitle:
                '${Formatters.dayShort.format(e.startsAt)} · ${e.organizer}',
            icon: Icons.event_rounded,
            section: 'Events',
            onOpen: () => Navigator.pushNamed(context, Routes.activities),
          ),
        );
      }
    }

    for (final Announcement a in _announcements) {
      if (_has('${a.title} ${a.body} ${a.category.label}')) {
        _results.add(
          _Hit(
            title: a.title,
            subtitle: a.category.label,
            icon: Icons.campaign_rounded,
            section: 'Announcements',
            onOpen: () => Navigator.pushNamed(context, Routes.alerts),
          ),
        );
      }
    }

    for (final Course c in _courses) {
      if (_has('${c.name} ${c.code} ${c.faculty}')) {
        _results.add(
          _Hit(
            title: c.name,
            subtitle: '${c.code} · ${c.credits} credits',
            icon: Icons.menu_book_rounded,
            section: 'Courses',
            onOpen: () => Navigator.pushNamed(context, Routes.courses),
          ),
        );
      }
    }

    for (final CampusLocation p in _places) {
      if (p.matches(_text.trim())) {
        _results.add(
          _Hit(
            title: p.name,
            subtitle: p.category,
            icon: Icons.place_rounded,
            section: 'Places',
            onOpen: () => Navigator.pushNamed(
              context,
              Routes.campusMap,
              arguments: p.id,
            ),
          ),
        );
      }
    }
  }

  List<String> get _sections {
    final List<String> seen = <String>[];
    for (final _Hit hit in _results) {
      if (!seen.contains(hit.section)) seen.add(hit.section);
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Search'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    _buildHits();
    final bool searching = _normalised.isNotEmpty;

    return Scaffold(
      appBar: const AVITAppBar(title: 'Search', subtitle: 'Everything on campus'),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITSearchField(
            controller: _query,
            hint: 'Services, events, announcements, courses, places',
            onChanged: (String v) => setState(() => _text = v),
            onClear: () => setState(() => _text = ''),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!searching) ...<Widget>[
            AVITSectionHeader(
              title: 'Browse',
              subtitle: 'Jump straight to a campus service',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ServiceEntry s in ServiceCatalog.all)
                  ActionChip(
                    avatar: Icon(s.icon, size: 16, color: AppColors.royalBlue),
                    label: Text(s.title),
                    onPressed: () => Navigator.pushNamed(context, s.route),
                    backgroundColor: AppColors.paleBlue,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillShape,
                    ),
                  ),
              ],
            ),
          ] else if (_results.isEmpty) ...<Widget>[
            AVITEmptyState(
              title: 'No matches for “${_text.trim()}”',
              message: 'Try a shorter word, or check the Campus tab for the '
                  'full service catalogue.',
              icon: Icons.search_off_rounded,
            ),
          ] else ...<Widget>[
            for (final String section in _sections) ...<Widget>[
              AVITSectionHeader(
                title: section,
                subtitle:
                    '${_results.where((_Hit h) => h.section == section).length} '
                    'result(s)',
              ),
              for (final _Hit hit in _results)
                if (hit.section == section)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AVITCard(
                      onTap: hit.onOpen,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: AppRadius.small,
                            ),
                            child: Icon(hit.icon, size: 20, color: AppColors.royalBlue),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(hit.title, style: text.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  hit.subtitle,
                                  style: text.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
