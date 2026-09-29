import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/staff_repository.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Immutable audit trail of every privileged action (admin only).
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  List<AuditRow> _rows = <AuditRow>[];
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
    try {
      final List<AuditRow> rows =
          await AppScope.of(context).state.deps.admin.auditLog();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
        _error = 'Unable to load the audit log';
        _loading = false;
      });
    }
  }

  List<AuditRow> get _visible {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((AuditRow r) {
      return r.action.toLowerCase().contains(q) ||
          r.actor.toLowerCase().contains(q) ||
          r.role.toLowerCase().contains(q) ||
          r.detail.toLowerCase().contains(q);
    }).toList();
  }

  IconData _iconFor(String action) {
    final String a = action.toLowerCase();
    if (a.contains('login') || a.contains('logout')) {
      return Icons.login_rounded;
    }
    if (a.contains('approve') || a.contains('reject')) {
      return Icons.gavel_rounded;
    }
    if (a.contains('role')) return Icons.admin_panel_settings_rounded;
    if (a.contains('scan') || a.contains('verify')) {
      return Icons.qr_code_scanner_rounded;
    }
    if (a.contains('emergency')) return Icons.emergency_rounded;
    if (a.contains('announce') || a.contains('publish')) {
      return Icons.campaign_rounded;
    }
    if (a.contains('delete') || a.contains('revoke')) {
      return Icons.delete_forever_rounded;
    }
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (_loading) return const LoadingList(itemCount: 8);
    if (_error != null) {
      return Scaffold(
        appBar: const AVITAppBar(title: 'Audit Log'),
        body: AVITErrorState(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AVITAppBar(
        title: 'Audit Log',
        subtitle: '${_rows.length} recorded actions',
      ),
      body: AVITRefresh(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            AVITSearchField(
              controller: _search,
              hint: 'Search action, actor or role',
              onChanged: (String v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: AppSpacing.sm),
            AVITStatusChip(
              label: 'Write-only trail • cannot be edited',
              tone: AVITStatusTone.info,
              icon: Icons.lock_rounded,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_visible.isEmpty)
              const AVITEmptyState(
                title: 'No matching actions',
                message: 'Try a different search term.',
                icon: Icons.manage_search_rounded,
              )
            else
              for (final AuditRow row in _visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AVITCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: AppRadius.small,
                          ),
                          child: Icon(
                            _iconFor(row.action),
                            size: 18,
                            color: AppColors.royalBlue,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(row.action, style: text.titleSmall),
                              Text(
                                '${row.actor} • ${row.role}',
                                style: text.labelSmall,
                              ),
                              if (row.detail.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(row.detail, style: text.bodySmall),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${Formatters.monthDay.format(row.time)} '
                          '${Formatters.time.format(row.time)}',
                          style: text.labelSmall,
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
