import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../models/campus_services.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Interactive campus map drawn on a custom canvas with searchable pins.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  bool _loading = true;
  String? _error;
  List<CampusLocation> _places = <CampusLocation>[];
  String _query = '';
  String _category = 'All';
  String? _selectedId;
  final TextEditingController _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _load();
      final Object? arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is String) _selectedId = arg;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppDependencies deps = AppScope.of(context).state.deps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<CampusLocation> rows = await deps.campus.locations();
      if (!mounted) return;
      setState(() {
        _places = rows;
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
        _error = 'Unable to load the campus map';
        _loading = false;
      });
    }
  }

  List<String> get _categories => <String>{
    'All',
    for (final CampusLocation p in _places) p.category,
  }.toList();

  List<CampusLocation> get _visible => _places.where((CampusLocation p) {
    final bool okCat = _category == 'All' || p.category == _category;
    return okCat && p.matches(_query);
  }).toList();

  CampusLocation? get _selected {
    for (final CampusLocation p in _places) {
      if (p.id == _selectedId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Campus Map'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Campus Map',
        subtitle: '${_visible.length} places shown',
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: <Widget>[
                AVITSearchField(
                  controller: _search,
                  hint: 'Search buildings, labs, blocks',
                  onChanged: (String v) => setState(() => _query = v),
                  onClear: () => setState(() => _query = ''),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final bool selected = _categories[index] == _category;
                      return ChoiceChip(
                        label: Text(_categories[index]),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _category = _categories[index]),
                        selectedColor: AppColors.lightBlue,
                        labelStyle: text.labelMedium?.copyWith(
                          color: selected ? AppColors.primaryBlue : null,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primaryBlue
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillShape,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ClipRRect(
                borderRadius: AppRadius.card,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return GestureDetector(
                      onTapUp: (TapUpDetails details) {
                        final double ux =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0, 1);
                        final double uy =
                            (details.localPosition.dy / constraints.maxHeight)
                                .clamp(0, 1);
                        CampusLocation? nearest;
                        double best = 0.06;
                        for (final CampusLocation p in _visible) {
                          final double d =
                              ((p.x - ux) * (p.x - ux) +
                                      (p.y - uy) * (p.y - uy))
                                  .abs();
                          if (d < best) {
                            best = d;
                            nearest = p;
                          }
                        }
                        if (nearest != null) {
                          setState(() => _selectedId = nearest!.id);
                          _showDetails(nearest);
                        }
                      },
                      child: CustomPaint(
                        painter: _CampusPainter(
                          places: _visible,
                          selectedId: _selectedId,
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: _LocationCard(
                place: _selected!,
                onClose: () => setState(() => _selectedId = null),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Text(
                'Tap a pin to see opening hours and contact details.',
                style: text.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  void _showDetails(CampusLocation place) {
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
            Text(place.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(place.category, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Text(place.description, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AVITButton(
              label: 'Done',
              variant: AVITButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.place, required this.onClose});

  final CampusLocation place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AVITCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: AppColors.royalBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(place.name, style: text.titleSmall),
                    Text(place.category, style: text.labelSmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(place.description, style: text.bodySmall),
          if (place.hours.isNotEmpty || place.phone.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (place.hours.isNotEmpty)
                  AVITStatusChip(
                    label: place.hours,
                    tone: AVITStatusTone.success,
                    icon: Icons.schedule_rounded,
                    compact: true,
                  ),
                if (place.phone.isNotEmpty)
                  AVITStatusChip(
                    label: place.phone,
                    tone: AVITStatusTone.info,
                    icon: Icons.phone_rounded,
                    compact: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CampusPainter extends CustomPainter {
  const _CampusPainter({
    required this.places,
    required this.selectedId,
    required this.isDark,
  });

  final List<CampusLocation> places;
  final String? selectedId;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Color base = isDark ? AppColors.darkCard : AppColors.paleBlue;
    final Color path = isDark ? AppColors.darkBorder : const Color(0xFFD6E1FB);
    final Color block = isDark ? AppColors.darkSurface : AppColors.white;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()..color = base,
    );

    // Lawn blocks.
    final Paint lawn = Paint()
      ..color = (isDark ? AppColors.success : AppColors.success).withValues(
        alpha: 0.14,
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.08,
          size.width * 0.3,
          size.height * 0.24,
        ),
        const Radius.circular(12),
      ),
      lawn,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.6,
          size.height * 0.6,
          size.width * 0.32,
          size.height * 0.3,
        ),
        const Radius.circular(12),
      ),
      lawn,
    );

    // Roads.
    final Paint road = Paint()
      ..color = path
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );

    // Building blocks.
    final Paint building = Paint()..color = block;
    final Paint buildingBorder = Paint()
      ..color = const Color(0xFFC4D2F1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < places.length; i++) {
      final CampusLocation p = places[i];
      final Rect r = Rect.fromCenter(
        center: Offset(p.x * size.width, p.y * size.height),
        width: 34,
        height: 26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        building,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        buildingBorder,
      );
    }

    // Pins.
    for (final CampusLocation p in places) {
      final bool selected = p.id == selectedId;
      final Offset centre = Offset(p.x * size.width, p.y * size.height);
      if (selected) {
        canvas.drawCircle(
          centre,
          18,
          Paint()..color = AppColors.primaryBlue.withValues(alpha: 0.2),
        );
      }
      final Paint pin = Paint()
        ..color = selected ? AppColors.primaryBlue : AppColors.royalBlue;
      final Path marker = Path()
        ..addOval(Rect.fromCircle(center: centre, radius: 8));
      canvas.drawPath(marker, pin);
      canvas.drawCircle(centre, 3.5, Paint()..color = AppColors.white);
    }
  }

  @override
  bool shouldRepaint(_CampusPainter old) =>
      old.selectedId != selectedId ||
      old.places.length != places.length ||
      old.isDark != isDark;
}
