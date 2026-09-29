import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';

/// Cafeteria: today's menu by meal, timings and outlet details.
class CafeteriaScreen extends StatefulWidget {
  const CafeteriaScreen({super.key});

  @override
  State<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends State<CafeteriaScreen> {
  bool _loading = true;
  String _meal = 'Lunch';
  final Map<String, List<_MenuItem>> _menu = <String, List<_MenuItem>>{
    'Breakfast': const <_MenuItem>[
      _MenuItem('Idli sambar', 'Veg', 30),
      _MenuItem('Masala dosa', 'Veg', 55),
      _MenuItem('Poori kizhangu', 'Veg', 45),
      _MenuItem('Filter coffee', 'Beverage', 20),
    ],
    'Lunch': const <_MenuItem>[
      _MenuItem('Veg meals', 'Veg', 70),
      _MenuItem('Curd rice pickle', 'Veg', 45),
      _MenuItem('Chicken biryani', 'Non-veg', 130),
      _MenuItem('Paneer butter masala', 'Veg', 110),
      _MenuItem('Sambar rice', 'Veg', 60),
    ],
    'Snacks': const <_MenuItem>[
      _MenuItem('Veg puff', 'Veg', 25),
      _MenuItem('Samosa (2 pc)', 'Veg', 20),
      _MenuItem('Chicken roll', 'Non-veg', 70),
      _MenuItem('Soda', 'Beverage', 25),
    ],
    'Dinner': const <_MenuItem>[
      _MenuItem('Chapati dal', 'Veg', 55),
      _MenuItem('Veg fried rice', 'Veg', 75),
      _MenuItem('Egg curry rice', 'Non-veg', 90),
      _MenuItem('Gulab jamun', 'Veg', 30),
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String get _currentMeal {
    final int hour = DateTime.now().hour;
    if (hour < 10) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 18) return 'Snacks';
    return 'Dinner';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Cafeteria',
        subtitle: 'Mess menu & outlets',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh menu',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF12924F), Color(0xFF1E63E8)],
              ),
              borderColor: Colors.transparent,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.restaurant_rounded,
                      color: AppColors.white, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Food Court & Mess',
                          style: text.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Serves till 9:30 PM • UPI and meal card accepted',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AVITStatusChip(
                    label: 'Open now',
                    tone: AVITStatusTone.success,
                    icon: Icons.check_circle_rounded,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final String meal in _menu.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(meal),
                        selected: _meal == meal,
                        onSelected: (_) => setState(() => _meal = meal),
                        selectedColor: AppColors.lightBlue,
                        labelStyle: text.labelMedium?.copyWith(
                          color: _meal == meal ? AppColors.primaryBlue : null,
                          fontWeight:
                              _meal == meal ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: _meal == meal
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
            const SizedBox(height: AppSpacing.sm),
            if (_meal == _currentMeal)
              AVITStatusChip(
                label: 'Serving $_meal now',
                tone: AVITStatusTone.success,
                icon: Icons.restaurant_menu_rounded,
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final _MenuItem item in _menu[_meal]!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AVITCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.tag == 'Non-veg'
                              ? AppColors.dangerSurface
                              : AppColors.successSurface,
                          borderRadius: AppRadius.small,
                        ),
                        child: Icon(
                          item.tag == 'Beverage'
                              ? Icons.local_cafe_rounded
                              : Icons.restaurant_rounded,
                          size: 18,
                          color: item.tag == 'Non-veg'
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.name, style: text.titleSmall),
                            Text(item.tag, style: text.labelSmall),
                          ],
                        ),
                      ),
                      Text(
                        '₹${item.price}',
                        style: text.titleSmall?.copyWith(
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(title: 'Outlets', subtitle: 'Around the campus'),
            AVITCard(
              child: Column(
                children: const <Widget>[
                  _OutletRow(
                    name: 'Main Food Court',
                    detail: 'Ground floor, Admin Block • 7 AM – 9:30 PM',
                    open: true,
                  ),
                  Divider(height: 1),
                  _OutletRow(
                    name: 'Juice & Snacks Stall',
                    detail: 'Near CSE block • 9 AM – 6 PM',
                    open: true,
                  ),
                  Divider(height: 1),
                  _OutletRow(
                    name: 'Night Canteen',
                    detail: 'Hostel Block A • 7 PM – 11 PM',
                    open: false,
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

class _MenuItem {
  const _MenuItem(this.name, this.tag, this.price);
  final String name;
  final String tag;
  final int price;
}

class _OutletRow extends StatelessWidget {
  const _OutletRow({
    required this.name,
    required this.detail,
    required this.open,
  });

  final String name;
  final String detail;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(detail, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          AVITStatusChip(
            label: open ? 'Open' : 'Closed',
            tone: open ? AVITStatusTone.success : AVITStatusTone.neutral,
            compact: true,
          ),
        ],
      ),
    );
  }
}
