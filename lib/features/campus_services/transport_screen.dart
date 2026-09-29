import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/snackbar.dart';
import '../../models/campus_services.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_charts.dart';
import '../../widgets/avit_feedback.dart';

/// College transport: route list, occupancy and seat requests.
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _loading = true;
  String? _error;
  List<BusRoute> _routes = <BusRoute>[];
  final Map<String, TransportRequest> _myRequests = <String, TransportRequest>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<BusRoute> rows = await deps.campus.busRoutes();
      if (!mounted) return;
      setState(() {
        _routes = rows;
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
        _error = 'Unable to load transport routes';
        _loading = false;
      });
    }
  }

  Future<void> _requestSeat(BusRoute route) async {
    final AppUser? me = AppScope.of(context).state.user;
    final String pickup = route.pickupPoints.isEmpty
        ? 'Main Gate'
        : route.pickupPoints.first;
    final AppDependencies deps = AppScope.of(context).state.deps;
    try {
      final TransportRequest req = await deps.campus.requestSeat(
        routeId: route.id,
        studentId: me?.studentId ?? '',
        pickupPoint: pickup,
      );
      if (!mounted) return;
      setState(() => _myRequests[route.id] = req);
      showAVITSnackBar(
        context,
        message: 'Seat confirmed on ${route.routeName} (pickup: $pickup)',
        tone: AVITSnackTone.success,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      showAVITSnackBar(context, message: e.userMessage, tone: AVITSnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Transport'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Transport',
        subtitle: '${_routes.length} routes in service',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              gradient: AppColors.primaryGradient,
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: AppColors.white,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Campus shuttle network',
                          style: text.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Live seat counts, driver contact and pickup points.',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Routes',
              subtitle: 'Tap a route to reserve a seat',
            ),
            if (_routes.isEmpty)
              const AVITEmptyState(
                title: 'No routes available',
                message: 'Transport schedules will appear here.',
                icon: Icons.directions_bus_rounded,
              )
            else
              for (final BusRoute route in _routes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AVITCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(route.routeName,
                                  style: text.titleSmall),
                            ),
                            AVITStatusChip(
                              label: route.status,
                              tone: route.status.toLowerCase().contains('delay')
                                  ? AVITStatusTone.warning
                                  : AVITStatusTone.success,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bus ${route.busNumber} • ${route.ac ? 'AC' : 'Non-AC'} • '
                          '${route.departure} → ${route.arrival}',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Icon(Icons.person_pin_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${route.driverName} • ${route.driverPhone}',
                                style: text.labelSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: BarRow(
                                label: 'Seats filled',
                                value: route.occupancy,
                                caption:
                                    '${route.bookedSeats}/${route.totalSeats}',
                                color: route.hasSeats
                                    ? AppColors.royalBlue
                                    : AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                AVITStatusChip(
                                  label: '${route.availableSeats} free',
                                  tone: route.hasSeats
                                      ? AVITStatusTone.success
                                      : AVITStatusTone.danger,
                                  compact: true,
                                ),
                                const SizedBox(height: 6),
                                if (_myRequests.containsKey(route.id))
                                  const AVITStatusChip(
                                    label: 'Seat booked',
                                    tone: AVITStatusTone.brand,
                                    icon: Icons.check_circle_rounded,
                                    compact: true,
                                  )
                                else
                                  TextButton(
                                    onPressed: route.hasSeats
                                        ? () => _requestSeat(route)
                                        : null,
                                    child: Text(
                                      route.hasSeats ? 'Reserve seat' : 'Full',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (route.pickupPoints.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final String p in route.pickupPoints)
                                AVITStatusChip(
                                  label: p,
                                  tone: AVITStatusTone.neutral,
                                  compact: true,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
