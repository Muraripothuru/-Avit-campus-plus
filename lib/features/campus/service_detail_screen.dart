import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../navigation/service_catalog.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_inputs.dart';

/// Service Details — the second level of the Campus services flow.
///
/// The screen is built around [service], the exact catalogue entry the
/// student tapped on the previous route, so every item opens its own
/// location, hours, contact and description instead of one hard-coded copy.
///
/// Navigation contract:
/// * `Request information` pops with [resultRequested] so the Services list
///   can show confirmation feedback for the returned result.
/// * `Open <service>` pushes the service's own functional route by name.
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.service});

  /// The object passed in from the Services list route.
  final ServiceEntry service;

  /// Value returned to the awaiting route via `Navigator.pop(context, result)`.
  static const String resultRequested = 'requested';

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AVITAppBar(title: service.title, subtitle: 'Campus service'),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          AVITCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // Shares its tag with the campus list tile's icon so
                    // the tile morphs into this header on push (and back).
                    Hero(
                      tag: 'service-icon-${service.title}',
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.small,
                        ),
                        child: Icon(
                          service.icon,
                          size: 28,
                          color: AppColors.royalBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(service.title, style: text.titleLarge),
                          const SizedBox(height: 4),
                          AVITStatusChip(
                            label: service.status,
                            tone: service.tone,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(service.description, style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AVITCard(
            child: Column(
              children: <Widget>[
                _DetailRow(
                  icon: Icons.place_rounded,
                  label: 'Location',
                  value: service.location,
                ),
                const Divider(height: AppSpacing.lg),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Opening hours',
                  value: service.hours,
                ),
                const Divider(height: AppSpacing.lg),
                _DetailRow(
                  icon: Icons.mail_rounded,
                  label: 'Contact',
                  value: service.contact,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AVITButton(
            label: 'Open ${service.title}',
            icon: Icons.open_in_new_rounded,
            onPressed: () => Navigator.pushNamed(context, service.route),
          ),
          const SizedBox(height: AppSpacing.sm),
          AVITButton(
            label: 'Request information',
            icon: Icons.mail_outline_rounded,
            variant: AVITButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, resultRequested),
          ),
        ],
      ),
    );
  }
}

/// One label/value line of the detail card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.royalBlue),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
