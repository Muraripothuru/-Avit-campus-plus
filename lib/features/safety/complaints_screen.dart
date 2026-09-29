import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/safety.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Complaints & service requests: raise new ones and track existing ones.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  // Owned by the screen (not the composer) so the sheet's exit animation can
  // never touch a disposed controller.
  final TextEditingController _composerSubject = TextEditingController();
  final TextEditingController _composerDescription = TextEditingController();

  bool _loading = true;
  String? _error;
  String _filter = 'All';
  List<Complaint> _items = <Complaint>[];

  static const List<String> _categories = <String>[
    'Academics',
    'Facilities',
    'Hostel',
    'Transport',
    'Food',
    'IT Support',
    'Harassment',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context).state;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Complaint> rows = await state.deps.campus
          .myComplaints(state.user?.studentId ?? '');
      if (!mounted) return;
      setState(() {
        _items = rows;
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
        _error = 'Unable to load complaints';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _composerSubject.dispose();
    _composerDescription.dispose();
    super.dispose();
  }

  List<Complaint> get _visible => _items.where((Complaint c) {
        if (_filter == 'All') return true;
        if (_filter == 'Open') return c.status.toLowerCase() != 'resolved';
        return c.status.toLowerCase() == 'resolved';
      }).toList();

  AVITStatusTone _toneFor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return AVITStatusTone.success;
      case 'in progress':
        return AVITStatusTone.info;
      case 'rejected':
        return AVITStatusTone.danger;
      default:
        return AVITStatusTone.warning;
    }
  }

  Future<void> _openComposer() async {
    final TextEditingController subject = _composerSubject;
    final TextEditingController description = _composerDescription;
    subject.clear();
    description.clear();
    String category = _categories.first;
    bool submitting = false;

    final bool? submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setLocal) {
          final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Raise a complaint',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The concerned team will be notified immediately.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITDropdown<String>(
                    label: 'Category',
                    required: true,
                    value: category,
                    items: <DropdownMenuItem<String>>[
                      for (final String c in _categories)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? v) =>
                        setLocal(() => category = v ?? category),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Subject',
                    required: true,
                    controller: subject,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Describe the issue',
                    required: true,
                    controller: description,
                    maxLines: 4,
                    maxLength: 400,
                    hint: 'What happened, where and when?',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITButton(
                    label: 'Submit complaint',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final String? subjectError = Validators.safeText(
                              subject.text,
                              field: 'Subject',
                              maxLength: 80,
                            );
                            if (subjectError != null) {
                              showAVITSnackBar(ctx,
                                  message: subjectError,
                                  tone: AVITSnackTone.warning);
                              return;
                            }
                            final String? descError = Validators.safeText(
                              description.text,
                              field: 'Description',
                              minLength: 10,
                              maxLength: 400,
                            );
                            if (descError != null) {
                              showAVITSnackBar(ctx,
                                  message: descError,
                                  tone: AVITSnackTone.warning);
                              return;
                            }
                            setLocal(() => submitting = true);
                            try {
                              final AppState state =
                                  AppScope.of(ctx).state;
                              final AppUser? me = state.user;
                              await state.deps.campus.submitComplaint(
                                category: category,
                                subject: subject.text.trim(),
                                description: description.text.trim(),
                                raisedBy: me?.fullName ?? 'Student',
                                raisedById: me?.studentId ?? '',
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (_) {
                              setLocal(() => submitting = false);
                              if (ctx.mounted) {
                                showAVITSnackBar(ctx,
                                    message:
                                        'Could not submit. Please try again.',
                                    tone: AVITSnackTone.error);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (submitted == true && mounted) {
      showAVITSnackBar(
        context,
        message: 'Complaint submitted. Track it below.',
        tone: AVITSnackTone.success,
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Complaints'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Complaints',
        subtitle: '${_items.length} service requests',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New complaint'),
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final String f in <String>['All', 'Open', 'Resolved'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppColors.lightBlue,
                        labelStyle: text.labelMedium?.copyWith(
                          color: _filter == f ? AppColors.primaryBlue : null,
                          fontWeight:
                              _filter == f ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: _filter == f
                              ? AppColors.primaryBlue
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillShape,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_visible.isEmpty)
              AVITEmptyState(
                title: _filter == 'All' ? 'No complaints yet' : 'Nothing here',
                message:
                    'Tap “New complaint” to report an issue — facilities, '
                    'academics, transport or anything else.',
                icon: Icons.support_agent_rounded,
                actionLabel: 'Raise complaint',
                onAction: _openComposer,
              )
            else
              for (final Complaint c in _visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(c.subject, style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: c.status,
                              tone: _toneFor(c.status),
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: <Widget>[
                            AVITStatusChip(
                              label: c.category,
                              tone: AVITStatusTone.brand,
                              compact: true,
                            ),
                            AVITStatusChip(
                              label: Formatters.monthDay.format(c.createdAt),
                              tone: AVITStatusTone.neutral,
                              icon: Icons.schedule_rounded,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(c.description, style: text.bodySmall),
                        if (c.response.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.infoSurface,
                              borderRadius: AppRadius.small,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Team response',
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(c.response, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
