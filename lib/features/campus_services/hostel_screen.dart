import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_content_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Hostel service: room details, mess timings, notices and quick requests.
class HostelScreen extends StatefulWidget {
  const HostelScreen({super.key});

  @override
  State<HostelScreen> createState() => _HostelScreenState();
}

class _HostelScreenState extends State<HostelScreen> {
  final TextEditingController _request = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final String? error = Validators.safeText(
      _request.text,
      field: 'Request',
      maxLength: 200,
    );
    if (error != null) {
      showAVITSnackBar(context, message: error, tone: AVITSnackTone.warning);
      return;
    }
    setState(() => _submitting = true);
    final AppScope scope = AppScope.of(context);
    final AppUser? me = scope.state.user;
    try {
      await scope.state.deps.campus.submitComplaint(
        category: 'Hostel',
        subject: 'Hostel request',
        description: _request.text.trim(),
        raisedBy: me?.fullName ?? 'Student',
        raisedById: me?.studentId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _request.clear();
      });
      showAVITSnackBar(
        context,
        message: 'Request sent to the hostel office',
        tone: AVITSnackTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAVITSnackBar(
        context,
        message: 'Unable to send the request right now',
        tone: AVITSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppUser? user = AppScope.of(context).state.user;
    final String room = (user?.hostel == null || user!.hostel!.isEmpty)
        ? 'Not allotted'
        : user.hostel!;

    return Scaffold(
      appBar: AVITAppBar(title: 'Hostel', subtitle: 'Living on campus'),
      body: AVITRefresh(
        onRefresh: () async {},
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              gradient: AppColors.heroGradient,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Your room',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          room,
                          style: text.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AVITStatusChip(
                    label: 'Resident',
                    tone: AVITStatusTone.success,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Mess menu today',
                    value: 'Veg + Non-veg',
                    icon: Icons.restaurant_rounded,
                    onTap: () => Navigator.pushNamed(context, Routes.cafeteria),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Complaints open',
                    value: '1',
                    icon: Icons.support_agent_rounded,
                    tone: AVITStatusTone.warning,
                    onTap: () => Navigator.pushNamed(context, Routes.complaints),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Facilities',
              subtitle: 'Everything inside your block',
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.9,
              children: <Widget>[
                AVITServiceCard(
                  title: 'Laundry',
                  subtitle: 'Mon / Thu',
                  icon: Icons.local_laundry_service_rounded,
                  tone: AVITStatusTone.info,
                  onTap: () {},
                ),
                AVITServiceCard(
                  title: 'Gym',
                  subtitle: '6 AM – 9 PM',
                  icon: Icons.fitness_center_rounded,
                  tone: AVITStatusTone.success,
                  onTap: () {},
                ),
                AVITServiceCard(
                  title: 'Reading room',
                  subtitle: '24 hours',
                  icon: Icons.menu_book_rounded,
                  tone: AVITStatusTone.brand,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Notices',
              subtitle: 'From the hostel office',
            ),
            const AVITAnnouncementTile(
              title: 'Water maintenance on Saturday',
              body: 'Supply will be interrupted from 10 AM to 1 PM in Blocks A and B.',
              tag: 'Maintenance',
            ),
            const SizedBox(height: AppSpacing.xs),
            const AVITAnnouncementTile(
              title: 'Visitor hours extended',
              body: 'Parent visiting hours are now 9 AM – 8 PM on Sundays.',
              tag: 'Hostel',
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Raise a request',
              subtitle: 'Housekeeping, repairs or anything else',
            ),
            AVITCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AVITTextField(
                    label: 'What do you need?',
                    hint: 'AC not working in room 118…',
                    controller: _request,
                    maxLines: 3,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AVITButton(
                    label: 'Send to hostel office',
                    loading: _submitting,
                    onPressed: _submitting ? null : _submitRequest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class AVITAnnouncementTile extends StatelessWidget {
  const AVITAnnouncementTile({
    super.key,
    required this.title,
    required this.body,
    required this.tag,
  });

  final String title;
  final String body;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AVITStatusChip(label: tag, tone: AVITStatusTone.brand, compact: true),
              const Spacer(),
              const Icon(Icons.campaign_rounded, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(body, style: text.bodySmall),
        ],
      ),
    );
  }
}
