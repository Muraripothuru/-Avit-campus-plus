import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';
import '../../widgets/avit_motion.dart';

/// Validation rules for the campus service request form.
///
/// Kept public so unit tests can exercise every edge case (empty, too
/// short, past dates, wrong formats) without driving the whole widget tree.
abstract final class ServiceRequestRules {
  static String? fullName(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Tell us your full name';
    if (v.split(RegExp(r'\s+')).length < 2) {
      return 'Enter your first and last name';
    }
    return null;
  }

  static String? campusEmail(String? value) {
    final String? basic = Validators.email(value);
    if (basic != null) return basic;
    if (!Validators.isSafeQuery((value ?? '').trim())) {
      return 'Enter a valid campus email';
    }
    final String v = (value ?? '').trim().toLowerCase();
    if (!v.endsWith('@avit.ac.in')) {
      return 'Use your campus email (@avit.ac.in)';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    final String v = (value ?? '').trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (v.isEmpty) return null; // Phone is optional by design.
    final String digits = v.startsWith('+91') ? v.substring(3) : v;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a 10-digit mobile number (6-9 first digit)';
    }
    return null;
  }

  /// Phone becomes compulsory once "Phone call" is the preferred contact.
  static String? phoneWhenContactIsCall(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Add a phone number for the Phone call contact';
    return optionalPhone(v);
  }

  static String? category(String? value) {
    if (value == null || value.isEmpty) return 'Choose a service category';
    return null;
  }

  static String? subject(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Add a short subject for your request';
    if (v.length < 8) return 'Give at least 8 characters so we can route it';
    if (v.length > 80) return 'Keep the subject under 80 characters';
    return null;
  }

  static String? details(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Describe what you need (20-500 characters)';
    if (v.length < 20) {
      return 'Add a little more detail (at least 20 characters)';
    }
    if (v.length > 500) return 'Keep the description under 500 characters';
    return null;
  }

  static String? blockRoom(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Tell us the block and room so the team can reach you';
    }
    return null;
  }

  static String? otherDetails(String? value) {
    if ((value ?? '').trim().length < 10) {
      return 'Describe the issue in at least 10 characters';
    }
    return null;
  }

  static String? urgency(String? value) =>
      value == null ? 'Select how urgent this request is' : null;

  static String? contact(String? value) =>
      value == null ? 'Choose how the team should reach you' : null;

  static String? preferredDate(DateTime? value) {
    if (value == null) return 'Pick a preferred response date';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (value.isBefore(today)) {
      return 'The preferred date cannot be in the past';
    }
    return null;
  }

  static String? declaration(bool? value) =>
      (value ?? false) ? null : 'Accept the declaration before submitting';

  /// Cheap completion check used by the progress meter (not the validator).
  static bool studentIdOk(String? value) => Validators.studentId(value) == null;
}

/// Two-step campus service request form: collect, validate, review and
/// submit — tailored to AVIT Campus+ (student helpdesk style).
class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({super.key});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  static const List<String> categories = <String>[
    'IT Helpdesk',
    'Facilities & Maintenance',
    'Hostel & Mess',
    'Library & Learning Centre',
    'Transport & Mobility',
    'Accounts & Fees',
    'Health & Counselling',
    'Lost Student ID Card',
    'Wi-Fi / Internet',
    'Dormitory Issue',
    'Library Access',
    'Academic Documents',
    'Payment Question',
    'Student Account / Login',
    'Campus Facilities',
    'Security / Access',
    'Other',
  ];

  /// Shortcuts shown as chips under the category dropdown.
  static const List<String> popularCategories = <String>[
    'Wi-Fi / Internet',
    'Lost Student ID Card',
    'Academic Documents',
    'Other',
  ];
  static const List<String> urgencies = <String>['Low', 'Normal', 'High'];
  static const List<String> contacts = <String>[
    'Email',
    'Phone call',
    'In person',
  ];
  static const List<String> attachments = <String>[
    'wifi-screenshot.png',
    'fee-receipt.pdf',
    'room-photo.jpg',
    'lab-report.docx',
  ];

  static const String facilitiesCategory = 'Facilities & Maintenance';
  static const String otherCategory = 'Other';

  GlobalKey<FormState> _detailsKey = GlobalKey<FormState>();
  GlobalKey<FormState> _reviewKey = GlobalKey<FormState>();
  final Random _random = Random();

  /// Bumped on every reset so all fields remount with fresh initial values.
  int _epoch = 0;
  int _step = 0; // 0 = details, 1 = review
  bool _submitting = false;
  bool _submitted = false;
  bool _draftRestored = false;
  String? _reference;
  String? _category;
  String? _urgency;
  String? _contact;
  DateTime? _date;
  TimeOfDay? _time;
  String? _attach;
  bool _agreed = false;

  final Map<String, String> _values = <String, String>{};
  final Map<String, String> _prefill = <String, String>{};
  final List<Map<String, String>> _recent = <Map<String, String>>[];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _restoreDraft();
  }

  /// Prefills the signed-in student and overlays any locally saved draft.
  void _restoreDraft() {
    final AppState state = AppScope.of(context).state;
    final AppUser? user = state.user;
    _prefill
      ..clear()
      ..addAll(<String, String>{
        'name': user?.fullName ?? '',
        'studentId': user?.studentId ?? '',
        'email': user?.email ?? '',
      });
    _values.addAll(_prefill);
    _initials = Map<String, String>.of(_prefill);

    final Map<String, Object?>? draft = state.serviceRequestDraft;
    if (draft == null) return;
    for (final String key in <String>[
      'name',
      'studentId',
      'email',
      'phone',
      'subject',
      'details',
      'block',
      'other',
    ]) {
      final Object? v = draft[key];
      if (v is String && v.isNotEmpty) {
        _initials[key] = v;
        _values[key] = v;
      }
    }
    final Object? cat = draft['category'];
    final Object? urg = draft['urgency'];
    final Object? con = draft['contact'];
    final Object? day = draft['date'];
    final Object? hour = draft['time'];
    final Object? file = draft['attach'];
    _category = cat is String && cat.isNotEmpty ? cat : null;
    _urgency = urg is String && urg.isNotEmpty ? urg : null;
    _contact = con is String && con.isNotEmpty ? con : null;
    if (day is String && day.isNotEmpty) _date = DateTime.tryParse(day);
    if (hour is String && hour.isNotEmpty) {
      final List<String> parts = hour.split(':');
      if (parts.length == 2) {
        _time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    _attach = file is String && file.isNotEmpty ? file : null;
    _draftRestored = true;
  }

  Map<String, String> _initials = <String, String>{};

  /// Live seed for a text field: the user's typed value always wins over the
  /// stored initial value, so leaving the details step and coming back (or
  /// rotating the form key) never silently reverts what was typed.
  String _seed(String key) => _values[key] ?? _initials[key] ?? '';

  double get _progress {
    int done = 0;
    if (ServiceRequestRules.fullName(_values['name']) == null) done++;
    if (ServiceRequestRules.studentIdOk(_values['studentId'])) done++;
    if (ServiceRequestRules.campusEmail(_values['email']) == null) done++;
    if (_category != null) done++;
    if (ServiceRequestRules.subject(_values['subject']) == null) done++;
    if (ServiceRequestRules.details(_values['details']) == null) done++;
    if (_urgency != null) done++;
    if (_contact != null) done++;
    if (_date != null) done++;
    assert(done <= 9);
    return done / 9;
  }

  String get _slotLabel {
    if (_date == null) return 'Not chosen yet';
    final String day = Formatters.dayShort.format(_date!);
    if (_time == null) return day;
    final DateTime withTime = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    return '$day • ${Formatters.time.format(withTime)}';
  }

  String get _referenceId {
    final int n = _random.nextInt(9000) + 1000;
    return 'SR-${DateTime.now().year}-$n';
  }

  /// Step 1 gate: validate everything first, then run onSaved callbacks so
  /// the review step only ever shows data that passed validation.
  void _continueToReview() {
    final FormState? form = _detailsKey.currentState;
    if (form == null || !form.validate()) {
      showAVITSnackBar(
        context,
        message: 'Fix the highlighted fields to continue',
        tone: AVITSnackTone.warning,
      );
      return;
    }
    form.save();
    setState(() {
      _detailsKey = GlobalKey<FormState>();
      _reviewKey = GlobalKey<FormState>();
      _step = 1;
    });
  }

  /// Persists the unfinished form locally so students can resume later.
  ///
  /// `save()` is only run once the details step validates, so an incomplete
  /// draft never writes invalid input back through the onSaved callbacks.
  /// The live `_values` map (fed by every onChanged) still carries whatever
  /// has been typed, so a partial draft is never lost.
  void _saveDraft() {
    final FormState? form = _detailsKey.currentState;
    if (form != null && form.validate()) form.save();
    final AppState state = AppScope.of(context).state;
    state.saveServiceRequestDraft(<String, Object?>{
      ..._values,
      'category': _category,
      'urgency': _urgency,
      'contact': _contact,
      'date': _date?.toIso8601String(),
      'time': _time == null ? null : '${_time!.hour}:${_time!.minute}',
      'attach': _attach,
    });
    showAVITSnackBar(
      context,
      message: 'Draft saved — reopen the form to continue where you left off.',
      tone: AVITSnackTone.success,
    );
  }

  /// Final gate: validate the declaration, save, then confirm with a
  /// summary dialog that carries a request reference.
  Future<void> _submit() async {
    final FormState? form = _reviewKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final String ref = _referenceId;
    final String routeLabel = _category == otherCategory
        ? 'Other: ${(_values['other'] ?? '').trim()}'
        : (_category ?? '');
    final Map<String, String> record = <String, String>{
      'ref': ref,
      'subject': (_values['subject'] ?? '').trim(),
      'category': routeLabel,
      'urgency': _urgency ?? '',
    };
    setState(() {
      _submitting = false;
      _submitted = true;
      _reference = ref;
      _recent.insert(0, record);
      if (_recent.length > 4) _recent.removeLast();
    });
    final AppState state = AppScope.of(context).state;
    state.clearServiceRequestDraft();
    _draftRestored = false;
    await _showSummaryDialog(ref);
  }

  Future<void> _showSummaryDialog(String ref) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final TextTheme text = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Row(
            children: <Widget>[
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Request submitted', style: text.titleMedium),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ..._summaryRows(text),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Text('Reference', style: text.labelSmall),
                Text(
                  ref,
                  style: text.titleMedium?.copyWith(
                    color: AppColors.royalBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetAll();
              },
              child: const Text('New request'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  /// Returns the form and every related selection to its initial condition.
  void _resetAll() {
    final AppState state = AppScope.of(context).state;
    state.clearServiceRequestDraft();
    if (!mounted) return;
    // Required reset behaviour: run FormState.reset() on both steps first,
    // then rotate the keys below so every control remounts cleared.
    _detailsKey.currentState?.reset();
    _reviewKey.currentState?.reset();
    setState(() {
      _epoch++;
      _detailsKey = GlobalKey<FormState>();
      _reviewKey = GlobalKey<FormState>();
      _step = 0;
      _submitted = false;
      _submitting = false;
      _reference = null;
      _agreed = false;
      _category = null;
      _urgency = null;
      _contact = null;
      _date = null;
      _time = null;
      _attach = null;
      _draftRestored = false;
      _initials = Map<String, String>.of(_prefill);
      _values
        ..clear()
        ..addAll(_prefill);
    });
    showAVITSnackBar(
      context,
      message: 'Form cleared — ready for a new request.',
      tone: AVITSnackTone.neutral,
    );
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      helpText: 'PREFERRED RESPONSE DATE',
    );
    if (picked == null || !mounted || !field.mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'PREFERRED RESPONSE TIME',
    );
    if (!mounted || !field.mounted) return;
    field.didChange(picked);
    setState(() {
      _date = picked;
      if (time != null) _time = time;
    });
  }

  void _openAttachmentPicker() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Attach a file (demo)'),
        children: <Widget>[
          for (final String file in attachments)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _attach = file);
              },
              child: Row(
                children: <Widget>[
                  const Icon(Icons.attach_file_rounded, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(file),
                ],
              ),
            ),
          if (_attach != null)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _attach = null);
              },
              child: const Text('Remove attachment'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AVITAppBar(
        title: 'Service Request',
        subtitle: 'Campus support desk',
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          _buildIntro(text),
          const SizedBox(height: AppSpacing.md),
          _buildStepper(text),
          if (_draftRestored && _step == 0 && !_submitted) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _buildDraftBanner(),
          ],
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (Widget child, Animation<double> anim) =>
                FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
            child: _submitted
                ? KeyedSubtree(
                    key: const ValueKey<String>('done'),
                    child: _buildSuccess(),
                  )
                : _step == 0
                ? KeyedSubtree(
                    key: ValueKey<String>('details$_epoch'),
                    child: _buildDetailsStep(text),
                  )
                : KeyedSubtree(
                    key: ValueKey<String>('review$_epoch'),
                    child: _buildReviewStep(text),
                  ),
          ),
          if (_recent.isNotEmpty && !_submitted) _buildRecent(text),
          // Hidden while reviewing so the step keeps its compact scroll range.
          if (_step == 0 || _submitted) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildSupportSection(text),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// IITU-style student support block shown above the form.
  Widget _buildSupportSection(TextTheme text) {
    final String status = _recent.isEmpty
        ? 'No active request yet.'
        : '${_recent.length} submitted this session';
    return AVITFadeUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'STUDENT SUPPORT',
            style: text.labelSmall?.copyWith(
              color: AppColors.royalBlue,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text('Help when you need it.', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Find the right campus service and submit a request without '
            'searching through departments.',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _SupportCard(
                    icon: Icons.bolt_rounded,
                    title: 'Quick Help',
                    body: 'Find the right campus service quickly.',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SupportCard(
                    icon: Icons.troubleshoot_rounded,
                    title: 'Common Issues',
                    body: 'Wi-Fi, ID card, dormitory, documents and more.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _SupportCard(
                    icon: Icons.pending_actions_rounded,
                    title: 'Request Status',
                    body: 'Check your latest submitted request.',
                    status: status,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SupportCard(
                    icon: Icons.post_add_rounded,
                    title: 'Service Request',
                    body: 'Submit an issue online in a few steps.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(TextTheme text) => AVITFadeUp(
    child: AVITCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('AVIT Campus+ Service Desk', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Tell any campus unit what you need. Two short steps: '
                  'details, then review and submit.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.pillShape,
                  border: Border.all(color: AppColors.primaryBlue),
                ),
                child: Text(
                  'NEW REQUEST',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_step + 1} / 2',
                style: text.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildStepper(TextTheme text) {
    return AVITFadeUp(
      delay: const Duration(milliseconds: 60),
      child: AVITCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => Row(
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (c.maxWidth * 0.32).clamp(48.0, 150.0),
                    ),
                    child: _stepBubble(text, 0, 'Details'),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: _step >= 1
                          ? AppColors.royalBlue
                          : AppColors.border,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (c.maxWidth * 0.32).clamp(48.0, 150.0),
                    ),
                    child: _stepBubble(text, 1, 'Review'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _progress),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double value, _) =>
                        ClipRRect(
                          borderRadius: AppRadius.pillShape,
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 7,
                            backgroundColor: AppColors.surfaceMuted,
                            color: AppColors.royalBlue,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${(_progress * 100).round()}% complete',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.royalBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBubble(TextTheme text, int index, String label) {
    final bool active = _step >= index;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.royalBlue : AppColors.surfaceMuted,
          ),
          child: Text(
            '${index + 1}',
            style: text.labelSmall?.copyWith(
              color: active ? AppColors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? AppColors.navy : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftBanner() => AVITCard(
    color: AppColors.warningSurface,
    borderColor: AppColors.warning,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.history_rounded, size: 18, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Draft restored — pick up where you left off.',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _draftRestored = false),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );

  Widget _buildDetailsStep(TextTheme text) {
    return Form(
      key: _detailsKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AVITFadeUp(
            delay: const Duration(milliseconds: 80),
            child: AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Student details', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Student name',
                    required: true,
                    initialValue: _seed('name'),
                    hint: 'Ananya Sharma',
                    textCapitalization: TextCapitalization.words,
                    validator: ServiceRequestRules.fullName,
                    onChanged: (String? v) => setState(() {
                      _values['name'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['name'] = v ?? '',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Student ID',
                    required: true,
                    initialValue: _seed('studentId'),
                    hint: 'AVIT2026CS042',
                    validator: Validators.studentId,
                    onChanged: (String? v) => setState(() {
                      _values['studentId'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['studentId'] = v ?? '',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Campus email',
                    required: true,
                    initialValue: _seed('email'),
                    hint: 'student@avit.ac.in',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: ServiceRequestRules.campusEmail,
                    onChanged: (String? v) => setState(() {
                      _values['email'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['email'] = v ?? '',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Phone number',
                    required: _contact == 'Phone call',
                    hint: _contact == 'Phone call'
                        ? 'Required — 10-digit mobile'
                        : 'Optional — 10-digit mobile',
                    initialValue: _seed('phone'),
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_rounded,
                    validator: _contact == 'Phone call'
                        ? ServiceRequestRules.phoneWhenContactIsCall
                        : ServiceRequestRules.optionalPhone,
                    onChanged: (String? v) => setState(() {
                      _values['phone'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['phone'] = v ?? '',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AVITFadeUp(
            delay: const Duration(milliseconds: 140),
            child: AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Request details', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  AVITDropdown<String>(
                    label: 'Service category',
                    required: true,
                    value: _category,
                    hint: 'Pick the unit you need',
                    validator: ServiceRequestRules.category,
                    items: <DropdownMenuItem<String>>[
                      for (final String c in categories)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Popular requests', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final String c in popularCategories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                          selectedColor: AppColors.lightBlue,
                          labelStyle: text.labelMedium?.copyWith(
                            color: _category == c
                                ? AppColors.primaryBlue
                                : null,
                            fontWeight: _category == c
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: _category == c
                                ? AppColors.primaryBlue
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillShape,
                          ),
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _category == otherCategory
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: AppSpacing.md),
                              AVITTextField(
                                label: 'Tell us what happened',
                                required: true,
                                initialValue: _seed('other'),
                                hint: 'Describe the issue that is not listed above...',
                                maxLines: 3,
                                maxLength: 180,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                validator: ServiceRequestRules.otherDetails,
                                onChanged: (String? v) =>
                                    setState(() => _values['other'] = v ?? ''),
                                onSaved: (String? v) =>
                                    _values['other'] = v ?? '',
                              ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Request subject',
                    required: true,
                    initialValue: _seed('subject'),
                    hint: 'e.g. Projector not working in AB-204',
                    maxLength: 80,
                    validator: ServiceRequestRules.subject,
                    onChanged: (String? v) => setState(() {
                      _values['subject'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['subject'] = v ?? '',
                  ),
                  AVITTextField(
                    label: 'Describe your request',
                    required: true,
                    initialValue: _seed('details'),
                    hint:
                        'What do you need? Include block, room, timings… '
                        '(20-500 characters)',
                    maxLines: 4,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    validator: ServiceRequestRules.details,
                    onChanged: (String? v) => setState(() {
                      _values['details'] = v ?? '';
                    }),
                    onSaved: (String? v) => _values['details'] = v ?? '',
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _category == facilitiesCategory
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const SizedBox(height: AppSpacing.md),
                              AVITTextField(
                                label: 'Block / room number',
                                required: true,
                                initialValue: _seed('block'),
                                hint: 'e.g. AB-204, Girls Hostel C-212',
                                validator: ServiceRequestRules.blockRoom,
                                onChanged: (String? v) => setState(() {
                                  _values['block'] = v ?? '';
                                }),
                                onSaved: (String? v) =>
                                    _values['block'] = v ?? '',
                              ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Urgency', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _choiceField(
                    value: _urgency,
                    validator: ServiceRequestRules.urgency,
                    values: urgencies,
                    onPicked: (String v) {
                      _urgency = v;
                    },
                    iconFor: (String v) => switch (v) {
                      'High' => Icons.priority_high_rounded,
                      'Normal' => Icons.trending_flat_rounded,
                      _ => Icons.arrow_downward_rounded,
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AVITFadeUp(
            delay: const Duration(milliseconds: 200),
            child: AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Preferences', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  Text('Preferred contact', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _choiceField(
                    value: _contact,
                    validator: ServiceRequestRules.contact,
                    values: contacts,
                    onPicked: (String v) {
                      _contact = v;
                    },
                    iconFor: (String v) => switch (v) {
                      'Email' => Icons.mail_rounded,
                      'Phone call' => Icons.call_rounded,
                      _ => Icons.groups_rounded,
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _dateField(text),
                  const SizedBox(height: AppSpacing.md),
                  Text('Attachment', style: text.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: AVITButton(
                          label: _attach == null
                              ? 'Attach a file'
                              : 'Change file',
                          icon: Icons.attach_file_rounded,
                          variant: AVITButtonVariant.secondary,
                          expand: false,
                          compact: true,
                          onPressed: _openAttachmentPicker,
                        ),
                      ),
                      if (_attach != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Chip(
                            avatar: const Icon(
                              Icons.description_rounded,
                              size: 16,
                            ),
                            label: Text(_attach!),
                            onDeleted: () => setState(() => _attach = null),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_progress >= 1) ...<Widget>[
            AVITCard(
              color: AppColors.successSurface,
              borderColor: AppColors.success,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'All required fields are complete',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.successText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AVITButton(
                  label: 'Save draft',
                  icon: Icons.save_rounded,
                  variant: AVITButtonVariant.secondary,
                  onPressed: _saveDraft,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AVITButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _continueToReview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chips group wrapped in a FormField so errors participate in validate().
  Widget _choiceField({
    required String? value,
    required String? Function(String?) validator,
    required List<String> values,
    required void Function(String) onPicked,
    required IconData Function(String) iconFor,
  }) {
    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String option in values)
                  ChoiceChip(
                    avatar: Icon(
                      iconFor(option),
                      size: 16,
                      color: field.value == option
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                    label: Text(option),
                    selected: field.value == option,
                    onSelected: (_) {
                      field.didChange(option);
                      setState(() => onPicked(option));
                    },
                    selectedColor: AppColors.lightBlue,
                    labelStyle: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(
                          color: field.value == option
                              ? AppColors.primaryBlue
                              : null,
                          fontWeight: field.value == option
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                    side: BorderSide(
                      color: field.value == option
                          ? AppColors.primaryBlue
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillShape,
                    ),
                  ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  field.errorText!,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dateField(TextTheme text) {
    return FormField<DateTime>(
      initialValue: _date,
      validator: ServiceRequestRules.preferredDate,
      builder: (FormFieldState<DateTime> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Preferred response date',
              style: text.labelLarge?.copyWith(
                color: _date == null ? null : AppColors.royalBlue,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _pickDate(field),
              borderRadius: AppRadius.small,
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.event_rounded, size: 20),
                  suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  errorText: field.errorText,
                  hintText: 'Choose a date and time',
                ),
                child: Text(
                  _slotLabel,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: _date == null
                        ? FontWeight.w400
                        : FontWeight.w700,
                    color: _date == null
                        ? AppColors.textSecondary
                        : AppColors.navy,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewStep(TextTheme text) {
    return Form(
      key: _reviewKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AVITFadeUp(
            child: AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Review your request', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Check the details below, then accept the declaration.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._summaryRows(text),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AVITFadeUp(
            delay: const Duration(milliseconds: 90),
            child: AVITCard(
              child: FormField<bool>(
                initialValue: _agreed,
                validator: ServiceRequestRules.declaration,
                builder: (FormFieldState<bool> field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        onTap: () {
                          final bool next = !(field.value ?? false);
                          field.didChange(next);
                          setState(() => _agreed = next);
                        },
                        borderRadius: AppRadius.small,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Checkbox(
                              value: field.value ?? false,
                              onChanged: (bool? v) {
                                final bool next = v ?? false;
                                field.didChange(next);
                                setState(() => _agreed = next);
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'I confirm that the information provided is '
                                  'correct, and agree that the campus unit may '
                                  'contact me about this request.',
                                  style: text.bodySmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            field.errorText!,
                            style: text.labelSmall?.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITButton(
            label: 'Back',
            icon: Icons.arrow_back_rounded,
            variant: AVITButtonVariant.secondary,
            expand: false,
            onPressed: () => setState(() {
              _detailsKey = GlobalKey<FormState>();
              _reviewKey = GlobalKey<FormState>();
              _step = 0;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AVITButton(
                  label: 'Submit request',
                  icon: Icons.send_rounded,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AVITButton(
                label: 'Reset',
                icon: Icons.restart_alt_rounded,
                variant: AVITButtonVariant.secondary,
                expand: false,
                onPressed: _resetAll,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _summaryRows(TextTheme text) {
    final List<MapEntry<String, String>> entries = <MapEntry<String, String>>[
      MapEntry<String, String>(
        'Student',
        '${(_values['name'] ?? '').trim()} (${(_values['studentId'] ?? '').trim()})',
      ),
      MapEntry<String, String>('Email', (_values['email'] ?? '').trim()),
      if ((_values['phone'] ?? '').trim().isNotEmpty)
        MapEntry<String, String>('Phone', (_values['phone'] ?? '').trim()),
      MapEntry<String, String>('Category', _category ?? '—'),
      if (_category == facilitiesCategory &&
          (_values['block'] ?? '').trim().isNotEmpty)
        MapEntry<String, String>(
          'Block / room',
          (_values['block'] ?? '').trim(),
        ),
      if (_category == otherCategory &&
          (_values['other'] ?? '').trim().isNotEmpty)
        MapEntry<String, String>(
          'Other details',
          (_values['other'] ?? '').trim(),
        ),
      MapEntry<String, String>('Subject', (_values['subject'] ?? '').trim()),
      MapEntry<String, String>('Details', (_values['details'] ?? '').trim()),
      MapEntry<String, String>('Urgency', _urgency ?? '—'),
      MapEntry<String, String>('Preferred contact', _contact ?? '—'),
      MapEntry<String, String>('Preferred slot', _slotLabel),
      if (_attach != null) MapEntry<String, String>('Attachment', _attach!),
    ];
    return <Widget>[
      for (final MapEntry<String, String> e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 118,
                child: Text(
                  e.key,
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  e.value.isEmpty ? '—' : e.value,
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildSuccess() => SuccessState(
    key: const ValueKey<String>('success-view'),
    title: 'Request $_reference sent',
    message: _category == null
        ? 'The campus team will get back to you within one working day.'
        : 'The ${_category == otherCategory ? 'campus' : _category} team '
              'will reach you via ${_contact ?? 'email'} within one working '
              'day.',
    doneLabel: 'Start a new request',
    onDone: _resetAll,
  );

  Widget _buildRecent(TextTheme text) {
    return AVITFadeUp(
      delay: const Duration(milliseconds: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          AVITSectionHeader(
            title: 'Your recent requests',
            subtitle: '${_recent.length} submitted this session',
          ),
          for (final Map<String, String> r in _recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AVITCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            r['subject'] ?? '',
                            style: text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r['category']} • ${r['urgency']} urgency',
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    AVITStatusChip(
                      label: r['ref'] ?? '',
                      tone: AVITStatusTone.success,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tile of the student support section (IITU layout).
class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.body,
    this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: AppColors.royalBlue),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(body, style: text.labelSmall, maxLines: 2),
          if (status != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              status!,
              style: text.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
