import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Library service screen: hours, borrowing summary, dues and catalogue.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  static const List<_Book> _books = <_Book>[
    _Book('Clean Code', 'Robert C. Martin', 'QA 76.76', false),
    _Book('Introduction to Algorithms', 'Cormen et al.', 'QA 76.9', true),
    _Book('Operating System Concepts', 'Silberschatz', 'QA 76.73', false),
    _Book('Database System Concepts', 'Silberschatz', 'QA 76.9', true),
    _Book('Computer Networks', 'Andrew S. Tanenbaum', 'TK 5105', false),
    _Book('Artificial Intelligence', 'Stuart Russell', 'Q 335', false),
    _Book('Strength of Materials', 'R.K. Bansal', 'TA 405', true),
    _Book('Thermodynamics', 'P.K. Nag', 'QC 311', false),
    _Book('Signals and Systems', 'Oppenheim', 'TK 5102', false),
    _Book('Engineering Drawing', 'N.D. Bhatt', 'T 345', false),
  ];

  List<_Book> get _visible => _query.isEmpty
      ? _books
      : _books
          .where((_Book b) =>
              b.title.toLowerCase().contains(_query.toLowerCase()) ||
              b.author.toLowerCase().contains(_query.toLowerCase()) ||
              b.call.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 4);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Library'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(title: 'Library', subtitle: 'Central library'),
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
                  const Icon(Icons.local_library_rounded,
                      color: AppColors.white, size: 34),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Central Library',
                          style: text.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Mon–Sat 8:00 AM – 8:00 PM • Closed Sundays',
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: AVITMetricTile(
                    label: 'Books borrowed',
                    value: '3',
                    icon: Icons.book_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Due in 4 days',
                    value: '1',
                    icon: Icons.schedule_rounded,
                    tone: AVITStatusTone.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AVITMetricTile(
                    label: 'Dues',
                    value: '₹0',
                    icon: Icons.receipt_long_rounded,
                    tone: AVITStatusTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'My loans',
              subtitle: 'Bring your student ID for issue and return',
            ),
            AVITCard(
              child: Column(
                children: <Widget>[
                  const _LoanRow(
                    title: 'Design Patterns',
                    dueIn: 'Due in 4 days',
                    tone: AVITStatusTone.warning,
                  ),
                  const Divider(height: 1),
                  const _LoanRow(
                    title: 'Engineering Mathematics III',
                    dueIn: 'Due in 12 days',
                    tone: AVITStatusTone.success,
                  ),
                  const Divider(height: 1),
                  const _LoanRow(
                    title: 'Python Crash Course',
                    dueIn: 'Due in 20 days',
                    tone: AVITStatusTone.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AVITSectionHeader(
              title: 'Catalogue',
              subtitle: '${_visible.length} of ${_books.length} titles',
            ),
            AVITSearchField(
              controller: _search,
              hint: 'Search title, author or call number',
              onChanged: (String v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_visible.isEmpty)
              const AVITEmptyState(
                title: 'No titles found',
                message: 'Try another keyword or ask a librarian.',
                icon: Icons.menu_book_rounded,
              )
            else
              for (final _Book b in _visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AVITCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.book_outlined,
                            color: AppColors.royalBlue),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(b.title, style: text.titleSmall),
                              Text(
                                '${b.author} • ${b.call}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AVITStatusChip(
                          label: b.available ? 'Available' : 'Issued',
                          tone: b.available
                              ? AVITStatusTone.success
                              : AVITStatusTone.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _Book {
  const _Book(this.title, this.author, this.call, this.issued)
      : available = !issued;

  final String title;
  final String author;
  final String call;
  final bool issued;
  final bool available;
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({
    required this.title,
    required this.dueIn,
    required this.tone,
  });

  final String title;
  final String dueIn;
  final AVITStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          AVITStatusChip(label: dueIn, tone: tone, compact: true),
        ],
      ),
    );
  }
}
