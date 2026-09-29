import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Help centre: searchable FAQs plus escalation contacts.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  static const List<({String q, String a, String tag})> _faqs =
      <({String q, String a, String tag})>[
    (
      q: 'How do I request a gate pass?',
      a: 'Open Campus → Gate Pass → New request, fill in your reason, '
          'destination and timings, then submit. Your warden approves it and '
          'a QR code appears in the pass once approved.',
      tag: 'Gate pass',
    ),
    (
      q: 'My QR code does not scan at the gate.',
      a: 'Pull to refresh the pass screen to regenerate the token. Passes '
          'expire after their return time — create a new request if the '
          'window has passed.',
      tag: 'Gate pass',
    ),
    (
      q: 'How is attendance calculated?',
      a: 'Attendance counts attended periods over total periods for each '
          'course, weighted by credits for the overall percentage. The '
          'minimum required is 75%.',
      tag: 'Academics',
    ),
    (
      q: 'Can I book a bus seat for one day?',
      a: 'Yes. Open Campus → Transport, pick your route and pickup point, '
          'and confirm. Seats are released at 9 PM the previous day.',
      tag: 'Transport',
    ),
    (
      q: 'How do I report something urgent?',
      a: 'For immediate danger use the Emergency screen — security is '
          'notified instantly. For non-urgent issues use Complaints.',
      tag: 'Safety',
    ),
    (
      q: 'Where do I see my hostel notices?',
      a: 'Campus → Hostel shows mess timings, notices and lets you raise '
          'housekeeping or repair requests.',
      tag: 'Hostel',
    ),
    (
      q: 'Someone is using my account.',
      a: 'Go to Profile → Settings → Login activity and revoke every '
          'session you do not recognise, then change your password.',
      tag: 'Account',
    ),
    (
      q: 'How do I switch between dark and light mode?',
      a: 'Settings → Appearance lets you follow the system theme or pin '
          'light / dark manually.',
      tag: 'Account',
    ),
  ];

  List<({String q, String a, String tag})> get _visible {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _faqs;
    return _faqs
        .where((f) =>
            f.q.toLowerCase().contains(q) ||
            f.a.toLowerCase().contains(q) ||
            f.tag.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _contact(String channel, String target) {
    showAVITSnackBar(
      context,
      message: 'Contact $channel: $target',
      tone: AVITSnackTone.neutral,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(title: 'Help & FAQs', subtitle: 'We are here to help'),
      body: AVITRefresh(
        onRefresh: () async {},
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITSearchField(
              controller: _search,
              hint: 'Search help articles',
              onChanged: (String v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Popular questions',
              subtitle: '${_visible.length} articles',
            ),
            if (_visible.isEmpty)
              const AVITEmptyState(
                title: 'No articles found',
                message: 'Try a simpler keyword, or contact support below.',
                icon: Icons.search_off_rounded,
              )
            else
              AVITCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _visible.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        title: Text(
                          _visible[i].q,
                          style: text.titleSmall?.copyWith(fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: AVITStatusChip(
                            label: _visible[i].tag,
                            tone: AVITStatusTone.brand,
                            compact: true,
                          ),
                        ),
                        children: <Widget>[
                          Text(_visible[i].a, style: text.bodyMedium),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Still stuck?',
              subtitle: 'Reach the right team directly',
            ),
            AVITCard(
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.royalBlue,
                    ),
                    title: Text('Campus+ support', style: text.titleSmall),
                    subtitle: Text(
                      AppConstants.supportEmail,
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.mail_rounded, size: 20),
                    onTap: () =>
                        _contact('Email', AppConstants.supportEmail),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.local_police_rounded,
                      color: AppColors.info,
                    ),
                    title: Text('Security desk', style: text.titleSmall),
                    subtitle: Text(
                      AppConstants.securityDesk,
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.phone_rounded, size: 20),
                    onTap: () =>
                        _contact('Call', AppConstants.securityDesk),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.emergency_rounded,
                      color: AppColors.danger,
                    ),
                    title: Text('Emergency helpline', style: text.titleSmall),
                    subtitle: Text(
                      AppConstants.emergencyNumber,
                      style: text.labelSmall,
                    ),
                    trailing: const Icon(Icons.phone_rounded, size: 20),
                    onTap: () =>
                        _contact('Call', AppConstants.emergencyNumber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AVITButton(
              label: 'Raise a complaint instead',
              variant: AVITButtonVariant.secondary,
              icon: Icons.support_agent_rounded,
              onPressed: () => Navigator.pushNamed(context, Routes.complaints),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
