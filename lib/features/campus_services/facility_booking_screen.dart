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

/// Business rules for a facility booking — kept public so boundary tests
/// (past start, closing time, overlap, touching intervals) can exercise
/// every case without driving the picker UI.
abstract final class BookingRules {
  /// Facility operating window: bookings run 08:00–22:00.
  static const int openHour = 8;
  static const int closeHour = 22;

  /// Permitted booking window: today through the next 30 days.
  static const int maxDayOffset = 30;

  static const String missingFacility = 'Choose a facility';
  static const String missingPurpose = 'Say what the booking is for';
  static const String missingDay = 'Pick a date';
  static const String missingTime = 'Pick a start time';
  static const String pastTime = 'That time has already passed';
  static const String dayRange = 'Pick a date within the next 30 days';
  static const String outsideHours = 'Facilities run 08:00–22:00 only';
  static const String conflict = 'Facility already booked — pick another slot';

  static String? facility(String? value) =>
      (value == null || value.isEmpty) ? missingFacility : null;

  static String? purpose(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return missingPurpose;
    if (v.length < 5) return 'Add a little more detail (at least 5 characters)';
    return null;
  }

  /// Half-open intervals [start, end): a booking ending at 11:00 and a new
  /// one starting at 11:00 do not overlap, and only the same facility can
  /// ever conflict.
  static bool hasConflict(
    String facilityId,
    DateTime start,
    DateTime end,
    List<Booking> bookings,
  ) => bookings.any(
    (Booking booking) =>
        booking.facilityId == facilityId &&
        start.isBefore(booking.end) &&
        end.isAfter(booking.start),
  );

  /// The final gate run on submit and re-run immediately before committing,
  /// because time may have advanced while the confirmation dialog was open.
  static String? slot({
    required String facilityId,
    required DateTime start,
    required DateTime end,
    required List<Booking> bookings,
    DateTime? now,
  }) {
    final DateTime moment = now ?? DateTime.now();
    final DateTime today = DateTime(moment.year, moment.month, moment.day);
    final DateTime startDay = DateTime(start.year, start.month, start.day);

    if (start.isBefore(moment)) return pastTime;
    if (startDay.isAfter(today.add(const Duration(days: maxDayOffset)))) {
      return dayRange;
    }

    final DateTime close = DateTime(start.year, start.month, start.day, closeHour);
    if (start.hour < openHour || end.isAfter(close)) return outsideHours;

    if (hasConflict(facilityId, start, end, bookings)) return conflict;
    return null;
  }
}

/// Facility booking form: pick one of four facilities, a date within the
/// next 30 days, a start time, duration and purpose — then review the
/// computed interval in a confirmation dialog. Only Confirm saves the
/// booking to the shared in-memory list; Cancel or dismissal saves nothing.
class FacilityBookingScreen extends StatefulWidget {
  const FacilityBookingScreen({super.key});

  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen> {
  static const List<int> durations = <int>[30, 60, 90];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _purpose = TextEditingController();

  String? _facilityId;
  int _durationMinutes = 60;
  DateTime? _day;
  TimeOfDay? _startTime;

  // Inline validation state for the controls outside the Form.
  String? _dayError;
  String? _timeError;
  String? _slotError;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  DateTime get _start {
    final DateTime day = _day!;
    final TimeOfDay time = _startTime!;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  DateTime get _end => _start.add(Duration(minutes: _durationMinutes));

  /// Date picker bounded to today … today + 30 days. Dismissing the picker
  /// returns null and keeps the previously selected day untouched.
  Future<void> _pickDay() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: BookingRules.maxDayOffset)),
      initialDate: _day ?? today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _dayError = null;
      _slotError = null;
    });
  }

  /// Time picker in typing mode: keyboard entry is accessible and keeps
  /// boundary tests deterministic. Dismissal keeps the old value.
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startTime = picked;
      _timeError = null;
      _slotError = null;
    });
  }

  /// Validates every field, runs the slot rules, then asks for a deliberate
  /// confirmation. Re-validates after the dialog because the clock may have
  /// moved while it was open — only then is the booking committed once.
  Future<void> _reviewAndConfirm() async {
    setState(() {
      _dayError = _day == null ? BookingRules.missingDay : null;
      _timeError = _startTime == null ? BookingRules.missingTime : null;
      _slotError = null;
    });
    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    if (!fieldsValid || _dayError != null || _timeError != null) return;

    final AppState state = AppScope.of(context).state;
    String? problem = BookingRules.slot(
      facilityId: _facilityId!,
      start: _start,
      end: _end,
      bookings: state.facilityBookings,
    );
    if (problem != null) {
      setState(() => _slotError = problem);
      return;
    }

    final String summary = _summaryText();
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirm facility booking'),
        content: Text(summary),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;

    // Final validation immediately before committing (time may advance).
    problem = BookingRules.slot(
      facilityId: _facilityId!,
      start: _start,
      end: _end,
      bookings: state.facilityBookings,
    );
    if (problem != null) {
      setState(() => _slotError = problem);
      return;
    }

    final Booking booking = Booking(
      facilityId: _facilityId!,
      purpose: _purpose.text.trim(),
      start: _start,
      end: _end,
      studentName: state.user?.fullName ?? '',
      studentId: state.user?.studentId ?? '',
    );
    state.addFacilityBooking(booking);
    showAVITSnackBar(
      context,
      message:
          'Booking confirmed — ${facilityById(booking.facilityId).name}, '
          '${Formatters.dayShort.format(booking.start)} '
          '${Formatters.time.format(booking.start)}',
      tone: AVITSnackTone.success,
    );
    _resetForm();
  }

  /// Deliberate reset: form fields plus every non-Form selection state.
  void _resetForm() {
    _formKey.currentState?.reset();
    _purpose.clear();
    setState(() {
      _facilityId = null;
      _durationMinutes = 60;
      _day = null;
      _startTime = null;
      _dayError = null;
      _timeError = null;
      _slotError = null;
    });
  }

  /// Cancellation of an existing booking is a second, separate confirmation
  /// with its own SnackBar feedback.
  Future<void> _confirmCancel(Booking booking) async {
    final Facility facility = facilityById(booking.facilityId);
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          '${facility.name}\n'
          '${Formatters.dayShort.format(booking.start)} • '
          '${Formatters.time.format(booking.start)} – '
          '${Formatters.time.format(booking.end)}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    AppScope.of(context).state.cancelFacilityBooking(booking);
    showAVITSnackBar(
      context,
      message: 'Booking cancelled',
      tone: AVITSnackTone.neutral,
    );
  }

  String _summaryText() {
    final Facility facility = facilityById(_facilityId!);
    final DateTime start = _start;
    final DateTime end = _end;
    final String endLabel = end.day != start.day
        ? '${Formatters.dayShort.format(end)} ${Formatters.time.format(end)}'
        : Formatters.time.format(end);
    return '${facility.name}\n'
        '${Formatters.dayLong.format(start)}\n'
        '${Formatters.time.format(start)} – $endLabel\n'
        'Purpose: ${_purpose.text.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppState state = AppScope.of(context).state;
    final List<Booking> bookings = state.facilityBookings;

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Facility Booking',
        subtitle: 'Reserve a campus space',
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITFadeUp(
            child: AVITCard(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Book a facility', style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Choose a room, when you need it and what for. '
                      'Bookings run 08:00–22:00, up to 30 days ahead.',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITDropdown<String>(
                      label: 'Facility',
                      required: true,
                      value: _facilityId,
                      hint: 'Choose a facility',
                      validator: BookingRules.facility,
                      items: <DropdownMenuItem<String>>[
                        for (final Facility f in demoFacilities)
                          DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.name),
                          ),
                      ],
                      onChanged: (String? v) => setState(() {
                        _facilityId = v;
                        _slotError = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Purpose',
                      required: true,
                      controller: _purpose,
                      hint: 'e.g. Group study session',
                      maxLength: 120,
                      prefixIcon: Icons.edit_note_rounded,
                      textCapitalization: TextCapitalization.sentences,
                      validator: BookingRules.purpose,
                      onChanged: (_) {
                        if (_slotError != null) {
                          setState(() => _slotError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Duration', style: text.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        for (final int d in durations)
                          ButtonSegment<int>(value: d, label: Text('$d min')),
                      ],
                      selected: <int>{_durationMinutes},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<int> selection) =>
                          setState(() => _durationMinutes = selection.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.calendar_today_rounded,
                            label: _day == null
                                ? 'Select date'
                                : Formatters.dayShort.format(_day!),
                            onTap: _pickDay,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.schedule_rounded,
                            label: _startTime == null
                                ? 'Select time'
                                : _startTime!.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    if (_dayError != null || _timeError != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        <String?>[_dayError, _timeError]
                            .where((String? e) => e != null)
                            .join(' • '),
                        style: text.labelSmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    if (_slotError != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _slotError!,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    if (_day != null && _startTime != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Booking window',
                              style: text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Starts: ${Formatters.dayShort.format(_start)}, '
                              '${Formatters.time.format(_start)}',
                              style: text.bodyMedium,
                            ),
                            Text(
                              'Ends: ${_endLabel()}',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AVITButton(
            label: 'Review booking',
            icon: Icons.event_available_rounded,
            onPressed: _reviewAndConfirm,
          ),
          const SizedBox(height: AppSpacing.sm),
          AVITButton(
            label: 'Reset form',
            icon: Icons.refresh_rounded,
            variant: AVITButtonVariant.secondary,
            onPressed: _resetForm,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Confirmed bookings', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (bookings.isEmpty)
            const AVITEmptyState(
              title: 'No bookings yet',
              message: 'Confirmed reservations will appear here.',
              icon: Icons.event_busy_rounded,
            )
          else
            for (final Booking booking in bookings)
              _BookingRow(
                booking: booking,
                onCancel: () => _confirmCancel(booking),
              ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _endLabel() {
    final DateTime start = _start;
    final DateTime end = _end;
    return end.day != start.day
        ? '${Formatters.dayShort.format(end)} ${Formatters.time.format(end)}'
        : Formatters.time.format(end);
  }
}

/// One confirmed booking: facility, interval, purpose and a cancel action.
class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking, required this.onCancel});

  final Booking booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Facility facility = facilityById(booking.facilityId);

    return AVITCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: AppRadius.small,
            ),
            child: Icon(facility.icon, size: 20, color: AppColors.royalBlue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(facility.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.dayShort.format(booking.start)} • '
                  '${Formatters.time.format(booking.start)} – '
                  '${Formatters.time.format(booking.end)}',
                  style: text.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  booking.purpose,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Outlined button used for the date and time pickers.
class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}
