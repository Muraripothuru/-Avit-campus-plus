import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/campus_event.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Events, clubs and personal registrations.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  bool _loading = true;
  String? _error;
  List<CampusEvent> _events = <CampusEvent>[];
  List<Club> _clubs = <Club>[];
  String _filter = 'All';

  static const List<String> _filters = <String>[
    'All',
    'Upcoming',
    'Registered',
    'Favourites',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<CampusEvent> events = await deps.activities.events();
      final List<Club> clubs = await deps.activities.clubs();
      if (!mounted) return;
      setState(() {
        _events = events;
        _clubs = clubs;
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
        _error = 'Unable to load activities';
        _loading = false;
      });
    }
  }

  List<CampusEvent> get _visible {
    switch (_filter) {
      case 'Upcoming':
        return _events
            .where((CampusEvent e) => !e.isPast)
            .toList(growable: false);
      case 'Registered':
        return _events
            .where((CampusEvent e) => e.registered)
            .toList(growable: false);
      case 'Favourites':
        return _events
            .where((CampusEvent e) => e.favourite)
            .toList(growable: false);
      default:
        return _events;
    }
  }

  List<CampusEvent> get _mine =>
      _events.where((CampusEvent e) => e.registered).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _tab,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.tangerine,
            indicatorWeight: 3,
            labelStyle: text.titleSmall,
            tabs: const <Widget>[
              Tab(text: 'Events'),
              Tab(text: 'Clubs'),
              Tab(text: 'My events'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingList(itemCount: 4)
              : _error != null
              ? AVITErrorState(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tab,
                  children: <Widget>[
                    AVITRefresh(onRefresh: _load, child: _buildEvents()),
                    AVITRefresh(onRefresh: _load, child: _buildClubs()),
                    AVITRefresh(onRefresh: _load, child: _buildMine()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEvents() {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: <Widget>[
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final bool selected = _filter == _filters[index];
              return ChoiceChip(
                label: Text(_filters[index]),
                selected: selected,
                onSelected: (_) => setState(() => _filter = _filters[index]),
                selectedColor: AppColors.lightBlue,
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.primaryBlue : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? AppColors.primaryBlue : AppColors.border,
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
            title: 'No events here yet',
            message: 'Switch the filter or check back after the next notice.',
            icon: Icons.event_busy_rounded,
          )
        else
          for (final CampusEvent e in _visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AVITEventCard(
                event: e,
                onOpen: () => _showSheet(e),
                onRegister: () => _register(e),
                onFavourite: () => _favourite(e),
              ),
            ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildClubs() {
    if (_clubs.isEmpty) {
      return const AVITEmptyState(
        title: 'No clubs listed',
        message: 'Student clubs will appear here once they are announced.',
        icon: Icons.groups_rounded,
      );
    }
    return ListView(
      padding: AppSpacing.screenPadding,
      children: <Widget>[
        for (final Club club in _clubs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AVITCard(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: AppRadius.small,
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.royalBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          club.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${club.memberCount} members'
                          '${club.nextEvent == null ? '' : ' • ${club.nextEvent}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AVITStatusChip(
                    label: club.following ? 'Following' : 'Follow',
                    tone: club.following
                        ? AVITStatusTone.brand
                        : AVITStatusTone.neutral,
                    icon: club.following
                        ? Icons.check_circle_rounded
                        : Icons.add_rounded,
                    compact: true,
                  ),
                  IconButton(
                    tooltip: club.following ? 'Unfollow club' : 'Follow club',
                    onPressed: () => _follow(club),
                    icon: Icon(
                      club.following
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildMine() {
    if (_mine.isEmpty) {
      return const AVITEmptyState(
        title: 'You have not registered yet',
        message: 'Register for an event and it will show up here.',
        icon: Icons.confirmation_number_rounded,
      );
    }
    return ListView(
      padding: AppSpacing.screenPadding,
      children: <Widget>[
        AVITSectionHeader(
          title: 'Your registrations',
          subtitle:
              '${_mine.length} event${_mine.length == 1 ? '' : 's'} • '
              '${Formatters.dayLong.format(DateTime.now())}',
        ),
        for (final CampusEvent e in _mine)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AVITEventCard(
              event: e,
              onOpen: () => _showSheet(e),
              onRegister: () {},
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<void> _register(CampusEvent e) async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    try {
      final CampusEvent updated = await deps.activities.register(eventId: e.id);
      if (!mounted) return;
      setState(() {
        final int i = _events.indexWhere((CampusEvent x) => x.id == e.id);
        if (i >= 0) _events[i] = updated;
      });
      showAVITSnackBar(
        context,
        message: 'Event registration successful',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (err) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: err.userMessage,
        tone: AVITSnackTone.error,
      );
    }
  }

  Future<void> _favourite(CampusEvent e) async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    await deps.activities.toggleFavourite(eventId: e.id);
    if (!mounted) return;
    final AppScope scope = AppScope.of(context);
    scope.state.toggleEventFavourite(e.id);
    setState(() {
      final int i = _events.indexWhere((CampusEvent x) => x.id == e.id);
      if (i >= 0) {
        _events[i] = _events[i].copyWith(favourite: !_events[i].favourite);
      }
    });
    showAVITSnackBar(
      context,
      message: e.favourite ? 'Removed from favourites' : 'Added to favourites',
      tone: AVITSnackTone.success,
    );
  }

  Future<void> _follow(Club club) async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    await deps.activities.toggleFollow(clubId: club.id);
    if (!mounted) return;
    AppScope.of(context).state.toggleClubFollow(club.id);
    setState(() {
      final int i = _clubs.indexWhere((Club x) => x.id == club.id);
      if (i >= 0) {
        _clubs[i] = _clubs[i].copyWith(following: !_clubs[i].following);
      }
    });
    showAVITSnackBar(
      context,
      message: club.following
          ? 'You stopped following ${club.name}'
          : 'You are now following ${club.name}',
      tone: AVITSnackTone.success,
    );
  }

  void _showSheet(CampusEvent e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
            Row(
              children: <Widget>[
                AVITStatusChip(
                  label: e.category,
                  tone: AVITStatusTone.brand,
                  compact: true,
                ),
                const Spacer(),
                Text(
                  Formatters.relativeDay(e.startsAt),
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(e.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${Formatters.time.format(e.startsAt)} • ${e.location} • '
              'by ${e.organizer}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(e.description, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITButton(
                    label: e.registered ? 'Registered' : 'Register now',
                    onPressed: e.registered
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _register(e);
                          },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  tooltip: e.favourite ? 'Remove favourite' : 'Favourite',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _favourite(e);
                  },
                  icon: Icon(
                    e.favourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
