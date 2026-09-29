import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/announcement.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Admin composer for campus-wide announcements plus a published log.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _loading = true;
  bool _publishing = false;
  String? _error;
  AnnouncementCategory _category = AnnouncementCategory.campus;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  List<Announcement> _items = <Announcement>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Announcement> rows =
          await AppScope.of(context).state.deps.content.announcements();
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
        _error = 'Unable to load announcements';
        _loading = false;
      });
    }
  }

  Future<void> _publish() async {
    final String? titleError = Validators.safeText(
      _title.text,
      field: 'Title',
      minLength: 5,
      maxLength: 90,
    );
    if (titleError != null) {
      showAVITSnackBar(context,
          message: titleError, tone: AVITSnackTone.warning);
      return;
    }
    final String? bodyError = Validators.safeText(
      _body.text,
      field: 'Message',
      minLength: 10,
      maxLength: 600,
    );
    if (bodyError != null) {
      showAVITSnackBar(context, message: bodyError, tone: AVITSnackTone.warning);
      return;
    }

    setState(() => _publishing = true);
    try {
      await AppScope.of(context).state.deps.admin.publishAnnouncement(
            title: _title.text.trim(),
            body: _body.text.trim(),
            category: _category,
          );
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _title.clear();
        _body.clear();
      });
      showAVITSnackBar(
        context,
        message: 'Announcement published to all users',
        tone: AVITSnackTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      showAVITSnackBar(context,
          message: 'Publishing failed. Please retry.',
          tone: AVITSnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 5);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Announcements'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Announcements',
        subtitle: 'Publish campus updates',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('New announcement', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Title',
                    required: true,
                    controller: _title,
                    maxLength: 90,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITDropdown<AnnouncementCategory>(
                    label: 'Category',
                    required: true,
                    value: _category,
                    items: <DropdownMenuItem<AnnouncementCategory>>[
                      for (final AnnouncementCategory c
                          in AnnouncementCategory.values)
                        DropdownMenuItem<AnnouncementCategory>(
                          value: c,
                          child: Text(c.label),
                        ),
                    ],
                    onChanged: (AnnouncementCategory? c) => setState(
                      () => _category = c ?? _category,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITTextField(
                    label: 'Message',
                    required: true,
                    controller: _body,
                    maxLines: 5,
                    maxLength: 600,
                    hint: 'What should the campus know?',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AVITButton(
                    label: 'Publish now',
                    icon: Icons.campaign_rounded,
                    loading: _publishing,
                    onPressed: _publishing ? null : _publish,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Published',
              subtitle: '${_items.length} announcements',
              actionLabel: 'Refresh',
              onAction: _load,
            ),
            if (_items.isEmpty)
              const AVITEmptyState(
                title: 'Nothing published yet',
                message: 'Published announcements appear here for everyone.',
                icon: Icons.campaign_outlined,
              )
            else
              for (final Announcement a in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITAnnouncementCard(
                    announcement: a,
                    onTap: () => _showDetail(a),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showDetail(Announcement a) {
    final TextTheme text = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
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
            AVITStatusChip(
              label: a.category.label,
              tone: AVITStatusTone.brand,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(a.title, style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${a.author} • ${Formatters.dayLong.format(a.publishedAt)}',
              style: text.labelSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(a.body, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: 'Close',
              variant: AVITButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
