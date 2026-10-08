import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/theme/app_spacing.dart';
import '../models/user.dart';
import 'avit_cards.dart';
import 'avit_inputs.dart';

/// Bottom sheet with the hostel profile behind an approval card — shared by
/// the warden console and the gate pass approval inbox.
Future<void> showStudentProfileSheet(
  BuildContext context,
  String studentId,
) async {
  final AppUser? profile = await AppScope.of(context).state.deps.warden
      .studentProfile(studentId);
  if (!context.mounted) return;
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
      child: profile == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('No profile found for $studentId', style: text.titleSmall),
                const SizedBox(height: AppSpacing.md),
                AVITButton(
                  label: 'Close',
                  variant: AVITButtonVariant.secondary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.fullName, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${profile.displayId} • ${profile.programmeShort}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    AVITStatusChip(
                      label: profile.hostel == null || profile.hostel!.isEmpty
                          ? 'Day scholar'
                          : profile.hostel!,
                      tone: AVITStatusTone.brand,
                      icon: Icons.apartment_rounded,
                      compact: true,
                    ),
                    AVITStatusChip(
                      label: 'Sem ${profile.semester ?? '—'}',
                      tone: AVITStatusTone.info,
                      compact: true,
                    ),
                    if (profile.phone.isNotEmpty)
                      AVITStatusChip(
                        label: profile.phone,
                        tone: AVITStatusTone.neutral,
                        icon: Icons.phone_rounded,
                        compact: true,
                      ),
                  ],
                ),
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
