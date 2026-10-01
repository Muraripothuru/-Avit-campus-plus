import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/campus_services.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Lost & found desk: report something you lost or found, claim what is yours.
class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _contact = TextEditingController();

  bool _loading = true;
  String? _error;
  String _filter = 'All';
  LostFoundKind _kind = LostFoundKind.lost;
  String _category = 'Electronics';
  String _location = 'Central Library';
  List<LostFoundItem> _items = <LostFoundItem>[];

  static const List<String> _categories = <String>[
    'Electronics',
    'Documents & ID',
    'Bag',
    'Clothing',
    'Keys',
    'Books & Stationery',
    'Other',
  ];

  static const List<String> _locations = <String>[
    'Central Library',
    'Food Court, Block A',
    'Main Gate',
    'Sports Complex',
    'Classroom Block',
    'Boys Hostel',
    'Girls Hostel',
    'Bus',
    'Laboratory',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context).state;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<LostFoundItem> rows = await state.deps.campus.lostFoundItems();
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
        _error = 'Unable to load lost & found reports';
        _loading = false;
      });
    }
  }

  String get _myId => AppScope.of(context).state.user?.studentId ?? '';

  List<LostFoundItem> get _visible => _items.where((LostFoundItem item) {
        switch (_filter) {
          case 'Lost':
            return item.kind == LostFoundKind.lost;
          case 'Found':
            return item.kind == LostFoundKind.found;
          case 'Mine':
            return item.ownedBy(_myId);
          default:
            return true;
        }
      }).toList();

  AVITStatusTone _toneFor(LostFoundStatus status) => switch (status) {
    LostFoundStatus.open => AVITStatusTone.warning,
    LostFoundStatus.claimed => AVITStatusTone.success,
    LostFoundStatus.closed => AVITStatusTone.neutral,
  };

  Future<void> _openComposer() async {
    final TextEditingController title = _title;
    final TextEditingController description = _description;
    final TextEditingController contact = _contact;
    title.clear();
    description.clear();
    contact.clear();
    _kind = LostFoundKind.lost;
    _category = _categories.first;
    _location = _locations.first;
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
                    'Report an item',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The help desk cross-checks every report before releasing '
                    'an item.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final LostFoundKind kind in LostFoundKind.values)
                        ChoiceChip(
                          label: Text(kind.label),
                          selected: _kind == kind,
                          onSelected: (_) => setLocal(() => _kind = kind),
                          selectedColor: AppColors.lightBlue,
                          labelStyle: Theme.of(ctx).textTheme.labelMedium,
                          side: BorderSide(
                            color: _kind == kind
                                ? AppColors.primaryBlue
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.pillShape,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITDropdown<String>(
                    label: 'Category',
                    required: true,
                    value: _category,
                    items: <DropdownMenuItem<String>>[
                      for (final String c in _categories)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? v) =>
                        setLocal(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITDropdown<String>(
                    label: _kind == LostFoundKind.lost
                        ? 'Where did you lose it?'
                        : 'Where did you find it?',
                    required: true,
                    value: _location,
                    items: <DropdownMenuItem<String>>[
                      for (final String l in _locations)
                        DropdownMenuItem<String>(value: l, child: Text(l)),
                    ],
                    onChanged: (String? v) =>
                        setLocal(() => _location = v ?? _location),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Item',
                    required: true,
                    controller: title,
                    maxLength: 80,
                    hint: 'Black wireless earbuds in a grey case',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Details',
                    required: true,
                    controller: description,
                    maxLines: 4,
                    maxLength: 400,
                    hint: 'Colour, markings, contents — anything to identify it',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'How to reach you',
                    controller: contact,
                    maxLength: 60,
                    hint: 'Phone number, email or hostel room (optional)',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AVITButton(
                    label: _kind == LostFoundKind.lost
                        ? 'Report as lost'
                        : 'Report as found',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final String? titleError = Validators.safeText(
                              title.text,
                              field: 'Item',
                              minLength: 5,
                              maxLength: 80,
                            );
                            if (titleError != null) {
                              showAVITSnackBar(ctx,
                                  message: titleError,
                                  tone: AVITSnackTone.warning);
                              return;
                            }
                            final String? descError = Validators.safeText(
                              description.text,
                              field: 'Details',
                              minLength: 15,
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
                              final AppState state = AppScope.of(ctx).state;
                              final AppUser? me = state.user;
                              await state.deps.campus.reportLostFound(
                                kind: _kind,
                                title: title.text.trim(),
                                category: _category,
                                description: description.text.trim(),
                                location: _location,
                                reportedBy: me?.fullName ?? 'Student',
                                reportedById: me?.studentId ?? '',
                                contact: contact.text.trim(),
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
        message: 'Report filed — the help desk will follow up.',
        tone: AVITSnackTone.success,
      );
      await _load();
    }
  }

  Future<void> _claim(LostFoundItem item) async {
    final AppUser? me = AppScope.of(context).state.user;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(item.kind == LostFoundKind.lost ? 'Claim this item?' : 'Is this yours?'),
        content: Text(
          'Confirming marks “${item.title}” as claimed by '
          '${me?.fullName ?? 'you'}. Bring ${me?.isStudent == true ? 'your student ID' : 'your ID'} '
          'to the help desk to collect it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, claim it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final AppState state = AppScope.of(context).state;
    try {
      await state.deps.campus.claimLostFound(
        itemId: item.id,
        claimedBy: me?.fullName ?? 'Student',
        claimedById: me?.studentId ?? '',
      );
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Claimed — show your ID at the help desk to collect it.',
        tone: AVITSnackTone.success,
      );
      await _load();
    } on AppException catch (e) {
      if (!mounted) return;
      showAVITSnackBar(context, message: e.userMessage, tone: AVITSnackTone.error);
    } catch (_) {
      if (!mounted) return;
      showAVITSnackBar(
        context,
        message: 'Could not claim this item. Please try again.',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Lost & Found'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Lost & Found',
        subtitle: '${_items.length} reports',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Report item'),
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final String f in <String>['All', 'Lost', 'Found', 'Mine'])
                  ChoiceChip(
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
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_visible.isEmpty)
              AVITEmptyState(
                title: _filter == 'All' ? 'No reports yet' : 'Nothing here',
                message: 'Tap “Report item” to log something you lost or found '
                    'on campus.',
                icon: Icons.search_rounded,
                actionLabel: 'Report item',
                onAction: _openComposer,
              )
            else
              for (final LostFoundItem item in _visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(item.title, style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: item.status.label,
                              tone: _toneFor(item.status),
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            AVITStatusChip(
                              label: item.kind.label,
                              tone: item.kind == LostFoundKind.lost
                                  ? AVITStatusTone.danger
                                  : AVITStatusTone.success,
                              compact: true,
                            ),
                            AVITStatusChip(
                              label: item.category,
                              tone: AVITStatusTone.brand,
                              compact: true,
                            ),
                            AVITStatusChip(
                              label: item.location,
                              tone: AVITStatusTone.info,
                              icon: Icons.place_rounded,
                              compact: true,
                            ),
                            AVITStatusChip(
                              label: Formatters.monthDay.format(item.createdAt),
                              tone: AVITStatusTone.neutral,
                              icon: Icons.schedule_rounded,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(item.description, style: text.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          'Reported by ${item.reportedBy}',
                          style: text.labelSmall,
                        ),
                        if (item.status == LostFoundStatus.claimed &&
                            item.claimedBy.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.successSurface,
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              'Claimed by ${item.claimedBy} on '
                              '${Formatters.monthDay.format(item.claimedAt ?? item.createdAt)}',
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                        if (item.isClaimable && !item.ownedBy(_myId)) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          AVITButton(
                            label: 'This is mine — claim it',
                            icon: Icons.gesture_rounded,
                            variant: AVITButtonVariant.secondary,
                            compact: true,
                            expand: false,
                            onPressed: () => _claim(item),
                          ),
                        ],
                        if (item.ownedBy(_myId)) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'You reported this item.',
                            style: text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
