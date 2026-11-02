import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';
import '../../widgets/avit_motion.dart';

/// Pure query over stored service-request records — shared by the screen
/// and the unit tests so search, filter and sort behaviour stay identical.
abstract final class ServiceRecordQuery {
  /// Fields the free-text search matches against.
  static const List<String> searchFields = <String>[
    'ref',
    'subject',
    'category',
    'urgency',
    'name',
    'studentId',
    'description',
  ];

  /// Urgency filter options, in the order they are shown as chips.
  static const List<String> urgencyOptions = <String>[
    'All',
    'High',
    'Normal',
    'Low',
  ];

  /// Sort options offered by the sort dropdown.
  static const List<String> sortOptions = <String>[
    'Newest first',
    'Oldest first',
    'Urgency: High to Low',
    'Student: A to Z',
    'Preferred date',
  ];

  /// Filters [records] by [query], [urgency] and [service], then applies
  /// [sort]. Records missing a sort key keep a deterministic fallback so
  /// the list never shuffles arbitrarily.
  static List<Map<String, String>> apply(
    List<Map<String, String>> records, {
    String query = '',
    String urgency = 'All',
    String service = 'All',
    String sort = 'Newest first',
  }) {
    final String q = query.trim().toLowerCase();
    final List<Map<String, String>> matched = records.where((
      Map<String, String> r,
    ) {
      if (urgency != 'All' && (r['urgency'] ?? '') != urgency) return false;
      if (service != 'All' && (r['category'] ?? '') != service) return false;
      if (q.isEmpty) return true;
      return searchFields.any(
        (String field) => (r[field] ?? '').toLowerCase().contains(q),
      );
    }).toList();

    final int Function(Map<String, String>, Map<String, String>) compare =
        switch (sort) {
          'Oldest first' => (
            Map<String, String> a,
            Map<String, String> b,
          ) => _str(a, 'createdAt').compareTo(_str(b, 'createdAt')),
          'Urgency: High to Low' => (
            Map<String, String> a,
            Map<String, String> b,
          ) => _urgencyWeight(a).compareTo(_urgencyWeight(b)),
          'Student: A to Z' => (
            Map<String, String> a,
            Map<String, String> b,
          ) => _str(a, 'name')
              .toLowerCase()
              .compareTo(_str(b, 'name').toLowerCase()),
          'Preferred date' => (
            Map<String, String> a,
            Map<String, String> b,
          ) {
            final int presence =
                (_preferredDate(a).isEmpty ? 1 : 0) -
                (_preferredDate(b).isEmpty ? 1 : 0);
            if (presence != 0) return presence;
            return _preferredDate(a).compareTo(_preferredDate(b));
          },
          _ => (Map<String, String> a, Map<String, String> b) =>
              _str(b, 'createdAt').compareTo(_str(a, 'createdAt')),
        };
    return matched..sort(compare);
  }

  /// Unique service categories present in [records], sorted for the
  /// service filter dropdown.
  static List<String> servicesOf(List<Map<String, String>> records) {
    final List<String> services = <String>{
      for (final Map<String, String> r in records)
        if ((r['category'] ?? '').isNotEmpty) r['category']!,
    }.toList();
    services.sort();
    return services;
  }

  static String _str(Map<String, String> r, String key) => r[key] ?? '';

  static String _preferredDate(Map<String, String> r) =>
      r['preferredDate'] ?? '';

  static int _urgencyWeight(Map<String, String> r) => switch (r['urgency']) {
    'High' => 0,
    'Normal' => 1,
    'Low' => 2,
    _ => 3,
  };
}

/// Student "Request Records" screen: every submitted campus service
/// request with free-text search, urgency/service filters, sorting and a
/// per-record detail sheet — the AVIT counterpart of the reference app's
/// My Requests screen.
class ServiceRecordsScreen extends StatefulWidget {
  const ServiceRecordsScreen({super.key});

  @override
  State<ServiceRecordsScreen> createState() => _ServiceRecordsScreenState();
}

class _ServiceRecordsScreenState extends State<ServiceRecordsScreen> {
  bool _loaded = false;
  bool _loading = true;
  List<Map<String, String>> _records = const <Map<String, String>>[];

  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _urgency = 'All';
  String _service = 'All';
  String _sort = 'Newest first';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context).state;
    final List<Map<String, String>> records = await state
        .recentServiceRequests(limit: 50);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  List<Map<String, String>> get _results => ServiceRecordQuery.apply(
    _records,
    query: _query,
    urgency: _urgency,
    service: _service,
    sort: _sort,
  );

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _urgency != 'All' ||
      _service != 'All' ||
      _sort != 'Newest first';

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _urgency = 'All';
      _service = 'All';
      _sort = 'Newest first';
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Map<String, String>> results = _results;
    return Scaffold(
      appBar: const AVITAppBar(
        title: 'Request Records',
        subtitle: 'Your submitted requests',
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              _buildFilters(text),
              const SizedBox(height: AppSpacing.md),
              if (_records.isEmpty)
                AVITEmptyState(
                  title: 'No requests yet',
                  message:
                      'Submit a campus service request and every submission '
                      'is kept here for you.',
                  icon: Icons.receipt_long_rounded,
                  actionLabel: 'Start a request',
                  onAction: () => Navigator.pushNamed(
                    context,
                    Routes.serviceRequest,
                  ),
                )
              else if (results.isEmpty)
                AVITEmptyState(
                  title: 'No matching requests',
                  message:
                      'Try another search value or clear the active filters.',
                  icon: Icons.search_off_rounded,
                  actionLabel: 'Clear filters',
                  onAction: _clearFilters,
                )
              else
                for (final Map<String, String> r in results) ...<Widget>[
                  _RecordCard(record: r, onOpen: () => _showDetails(r)),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(TextTheme text) {
    final List<String> services = ServiceRecordQuery.servicesOf(_records);
    final int shown = _results.length;
    return AVITFadeUp(
      child: AVITCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AVITSearchField(
              controller: _search,
              hint: 'Search subject, service, reference or description',
              onChanged: (String v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Urgency', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String option in ServiceRecordQuery.urgencyOptions)
                  ChoiceChip(
                    key: ValueKey<String>('urgency-$option'),
                    label: Text(option),
                    selected: _urgency == option,
                    onSelected: (_) => setState(() => _urgency = option),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AVITDropdown<String>(
              key: const ValueKey<String>('service-filter'),
              label: 'Service',
              value: services.contains(_service) || _service == 'All'
                  ? _service
                  : 'All',
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: 'All',
                  child: Text('All services'),
                ),
                for (final String service in services)
                  DropdownMenuItem<String>(
                    value: service,
                    child: Text(service, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (String? v) {
                if (v == null) return;
                setState(() => _service = v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AVITDropdown<String>(
              key: const ValueKey<String>('sort-filter'),
              label: 'Sort by',
              value: _sort,
              items: <DropdownMenuItem<String>>[
                for (final String option in ServiceRecordQuery.sortOptions)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (String? v) {
                if (v == null) return;
                setState(() => _sort = v);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Showing $shown of ${_records.length} '
                    'request${_records.length == 1 ? '' : 's'}',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _hasActiveFilters ? _clearFilters : null,
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Full record breakdown shown when a card (or its action) is tapped.
  void _showDetails(Map<String, String> r) {
    final DateTime? preferred = DateTime.tryParse(r['preferredDate'] ?? '');
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('Reference', r['ref'] ?? '—'),
      MapEntry<String, String>('Status', r['status'] ?? 'Submitted'),
      MapEntry<String, String>('Student', r['name'] ?? '—'),
      MapEntry<String, String>('Student ID', r['studentId'] ?? '—'),
      MapEntry<String, String>('Service', r['category'] ?? '—'),
      MapEntry<String, String>('Subject', r['subject'] ?? '—'),
      MapEntry<String, String>('Urgency', r['urgency'] ?? '—'),
      MapEntry<String, String>(
        'Preferred date',
        preferred == null
            ? (r['preferredDate'] ?? '').isEmpty
                  ? '—'
                  : r['preferredDate']!
            : Formatters.dayShort.format(preferred),
      ),
      if ((r['description'] ?? '').isNotEmpty)
        MapEntry<String, String>('Description', r['description']!),
    ];
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogText = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.royalBlue,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Request details', style: dialogText.titleMedium)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final MapEntry<String, String> e in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 118,
                          child: Text(
                            e.key,
                            style: dialogText.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value.isEmpty ? '—' : e.value,
                            style: dialogText.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// One submitted request on the records list.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onOpen});

  final Map<String, String> record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String nameId = <String>[
      if ((record['name'] ?? '').isNotEmpty) record['name']!,
      if ((record['studentId'] ?? '').isNotEmpty) record['studentId']!,
    ].join(' • ');
    return AVITCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  record['subject'] ?? 'Request',
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AVITStatusChip(
                label: record['status'] ?? 'Submitted',
                tone: AVITStatusTone.info,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${record['category']} · ${record['urgency']} urgency',
            style: text.labelSmall,
          ),
          if ((record['description'] ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              record['description']!,
              style: text.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              if (nameId.isNotEmpty)
                Expanded(
                  child: Text(
                    nameId,
                    style: text.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              AVITStatusChip(
                label: record['ref'] ?? '',
                tone: AVITStatusTone.success,
                compact: true,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }
}
