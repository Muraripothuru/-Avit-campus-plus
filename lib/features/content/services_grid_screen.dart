import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../models/campus_content.dart';
import '../../navigation/service_catalog.dart';
import '../campus/service_detail_screen.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';

/// Campus Services grid: six service tiles that reflow by available width —
/// four columns on wide layouts, three on medium, two on phones — and open
/// the service detail route for the tapped tile.
class ServicesGridScreen extends StatelessWidget {
  const ServicesGridScreen({super.key});

  /// Columns at each responsive breakpoint.
  static int columnCountFor(double width) {
    if (width >= 700) return 4;
    if (width >= 420) return 3;
    return 2;
  }

  ServiceEntry _entryFor(CampusService service) => ServiceEntry(
    service.label,
    service.icon,
    service.route,
    'From the Services grid',
    AVITStatusTone.brand,
    description: service.description,
    location: service.location,
    hours: service.hours,
    contact: service.contact,
  );

  Future<void> _openService(
    BuildContext context,
    CampusService service,
  ) async {
    final Object? result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: Routes.serviceDetail),
        builder: (BuildContext _) =>
            ServiceDetailScreen(service: _entryFor(service)),
      ),
    );
    if (!context.mounted || result != ServiceDetailScreen.resultRequested) {
      return;
    }
    showAVITSnackBar(
      context,
      message:
          'Request sent — the ${service.label} team will contact you',
      tone: AVITSnackTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AVITAppBar(title: 'Services', subtitle: 'Campus services A–Z'),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = columnCountFor(constraints.maxWidth);
          return GridView.builder(
            padding: AppSpacing.screenPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 1.2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemCount: demoCampusServices.length,
            itemBuilder: (BuildContext context, int index) {
              final CampusService service = demoCampusServices[index];
              return _ServiceTile(
                service: service,
                onTap: () => _openService(context, service),
              );
            },
          );
        },
      ),
    );
  }
}

/// One grid tile: icon, label and a short caption, sized by the grid.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final CampusService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Material(
      key: ValueKey<String>(service.id),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Container(
          // The 1.2 aspect ratio leaves little height at two columns, so the
          // tile keeps a compact icon + label + one-line location stack.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.small,
                ),
                child: Icon(
                  service.icon,
                  size: 22,
                  color: AppColors.royalBlue,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                service.label,
                style: text.titleSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                service.location,
                style: text.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
