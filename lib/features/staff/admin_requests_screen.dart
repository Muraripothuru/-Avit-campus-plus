import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../models/facility_booking.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';
import '../../widgets/avit_motion.dart';
import '../campus_services/service_records_screen.dart';

/// Admin operations view: every service request from every student with
/// search, urgency and status filters plus triage status updates, and
/// every confirmed facility booking with cancellation — the staff
/// counterpart of the student Request Records screen.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  bool _loaded = false;
  bool _loading = true;
  List<Map<String, String>> _records = const <Map<String, String>>[];

  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _urgency = 'All';
  String _status = 'All';
  bool _showBookings = false;

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
    final List<Map<String, String>> records = await state.allServiceRequests();
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
    status: _status,
  );

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty || _urgency != 'All' || _status != 'All';

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _urgency = 'All';
      _status = 'All';
    });
  }

  AVITStatusTone statusTone(String status) => switch (status) {
    'Resolved' => AVITStatusTone.success,
    'In progress' => AVITStatusTone.warning,
    'Submitted' => AVITStatusTone.info,
    _ => AVITStatusTone.neutral,
  };

  AVITStatusTone urgencyTone(String urgency) => switch (urgency) {
    'High' => AVITStatusTone.danger,
    'Low' => AVITStatusTone.info,
    _ => AVITStatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Booking> bookings = AppScope.of(context).state.facilityBookings;
    final List<Map<String, String>> results = _results;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Requests & Bookings',
        subtitle: 'Every student, every submission',
        onRefresh: _load,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            _buildSwitcher(bookings.length),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_showBookings) ...<Widget>[
              _buildRequestFilters(text),
              const SizedBox(height: AppSpacing.md),
              if (_records.isEmpty)
                AVITEmptyState(
                  title: 'No requests yet',
                  message:
                      'Service requests submitted by students land here the '
                      'moment they are sent.',
                  icon: Icons.inbox_rounded,
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
                  _AdminRecordCard(
                    record: r,
                    statusTone: statusTone(r['status'] ?? 'Submitted'),
                    onOpen: () => _showRequestDetails(r),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ] else ...<Widget>[
              if (bookings.isEmpty)
                AVITEmptyState(
                  title: 'No bookings yet',
                  message:
                      'Facility bookings from every student appear here the '
                      'moment they are confirmed.',
                  icon: Icons.event_available_rounded,
                )
              else
                for (final Booking b in bookings) ...<Widget>[
                  _BookingCard(
                    booking: b,
                    onOpen: () => _showBookingDetails(b),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcher(int bookingCount) {
    return AVITFadeUp(
      child: AVITCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: ChoiceChip(
                key: const ValueKey<String>('view-requests'),
                avatar: Icon(
                  Icons.inbox_rounded,
                  size: 18,
                  color: _showBookings
                      ? AppColors.textSecondary
                      : AppColors.primaryBlue,
                ),
                label: Text('Requests (${_records.length})'),
                selected: !_showBookings,
                onSelected: (_) => setState(() => _showBookings = false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ChoiceChip(
                key: const ValueKey<String>('view-bookings'),
                avatar: Icon(
                  Icons.event_available_rounded,
                  size: 18,
                  color: _showBookings
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                ),
                label: Text('Bookings ($bookingCount)'),
                selected: _showBookings,
                onSelected: (_) => setState(() => _showBookings = true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestFilters(TextTheme text) {
    final int shown = _results.length;
    return AVITFadeUp(
      child: AVITCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AVITSearchField(
              controller: _search,
              hint: 'Search subject, student, reference or description',
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
            Text('Status', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String option in ServiceRecordQuery.statusOptions)
                  ChoiceChip(
                    key: ValueKey<String>('status-$option'),
                    label: Text(option),
                    selected: _status == option,
                    onSelected: (_) => setState(() => _status = option),
                  ),
              ],
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

  /// Full request breakdown with the triage controls: pick a new status
  /// and commit it, or just read the record and close.
  Future<void> _showRequestDetails(Map<String, String> r) async {
    final String current = r['status'] ?? 'Submitted';
    String chosen = current;
    final DateTime? preferred = DateTime.tryParse(r['preferredDate'] ?? '');
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('Reference', r['ref'] ?? '—'),
      MapEntry<String, String>('Status', current),
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

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogText = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (
            BuildContext dlg,
            void Function(void Function()) setDialogState,
          ) {
            return AlertDialog(
              title: Row(
                children: <Widget>[
                  const Icon(
                    Icons.inbox_rounded,
                    color: AppColors.royalBlue,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Request details', style: dialogText.titleMedium),
                  ),
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
                    const Divider(height: AppSpacing.lg),
                    Text('Update status', style: dialogText.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final String option
                            in const <String>[
                              'Submitted',
                              'In progress',
                              'Resolved',
                            ])
                          ChoiceChip(
                            key: ValueKey<String>('dialog-status-$option'),
                            label: Text(option),
                            selected: chosen == option,
                            onSelected: (_) =>
                                setDialogState(() => chosen = option),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dlg, false),
                  child: const Text('Close'),
                ),
                TextButton(
                  key: const ValueKey<String>('update-status'),
                  onPressed: chosen == current
                      ? null
                      : () => Navigator.pop(dlg, true),
                  child: const Text('Update status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != true || !mounted) return;
    final AppState state = AppScope.of(context).state;
    await state.setServiceRequestStatus(r['ref'] ?? '', chosen);
    await _load();
    if (!mounted) return;
    showAVITSnackBar(
      context,
      message: 'Status updated to $chosen',
      tone: AVITSnackTone.success,
    );
  }

  /// Booking breakdown with a deliberate two-step cancellation.
  Future<void> _showBookingDetails(Booking b) async {
    final Facility facility = facilityById(b.facilityId);
    final int minutes = b.end.difference(b.start).inMinutes;
    final String owner = <String>[
      if (b.studentName.isNotEmpty) b.studentName,
      if (b.studentId.isNotEmpty) b.studentId,
    ].join(' • ');
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('Facility', facility.name),
      MapEntry<String, String>('Location', facility.location),
      MapEntry<String, String>('Date', Formatters.dayLong.format(b.start)),
      MapEntry<String, String>(
        'Time',
        '${Formatters.time.format(b.start)} – '
        '${Formatters.time.format(b.end)}',
      ),
      MapEntry<String, String>('Duration', '$minutes minutes'),
      MapEntry<String, String>('Purpose', b.purpose),
      MapEntry<String, String>('Student', owner.isEmpty ? '—' : owner),
    ];

    final bool? detailsClosed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme dialogText = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(facility.icon, color: AppColors.royalBlue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Booking details', style: dialogText.titleMedium),
              ),
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
              key: const ValueKey<String>('close-booking'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close'),
            ),
            TextButton(
              key: const ValueKey<String>('cancel-booking'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );
    if (detailsClosed != true || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          '${facility.name} on ${Formatters.dayShort.format(b.start)} at '
          '${Formatters.time.format(b.start)} will be freed for others.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            key: const ValueKey<String>('confirm-cancel-booking'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AppScope.of(context).state.cancelFacilityBooking(b);
    showAVITSnackBar(
      context,
      message: 'Booking cancelled',
      tone: AVITSnackTone.neutral,
    );
  }
}

/// One submitted request on the admin list.
class _AdminRecordCard extends StatelessWidget {
  const _AdminRecordCard({
    required this.record,
    required this.statusTone,
    required this.onOpen,
  });

  final Map<String, String> record;
  final AVITStatusTone statusTone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String nameId = <String>[
      if ((record['name'] ?? '').isNotEmpty) record['name']!,
      if ((record['studentId'] ?? '').isNotEmpty) record['studentId']!,
    ].join(' • ');
    return AVITCard(
      key: ValueKey<String>('record-${record['ref'] ?? ''}'),
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
                tone: statusTone,
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
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
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

/// One confirmed facility booking on the admin list.
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onOpen});

  final Booking booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Facility facility = facilityById(booking.facilityId);
    final String nameId = <String>[
      if (booking.studentName.isNotEmpty) booking.studentName,
      if (booking.studentId.isNotEmpty) booking.studentId,
    ].join(' • ');
    return AVITCard(
      key: ValueKey<String>(
        'booking-${booking.facilityId}-${booking.start.millisecondsSinceEpoch}',
      ),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(facility.icon, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(facility.name, style: text.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AVITStatusChip(
                label: 'Confirmed',
                tone: AVITStatusTone.success,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.dayShort.format(booking.start)} · '
            '${Formatters.time.format(booking.start)} – '
            '${Formatters.time.format(booking.end)}',
            style: text.labelSmall,
          ),
          if (booking.purpose.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              booking.purpose,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                Expanded(
                  child: Text(
                    'Student not recorded',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded, size: 20),
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
