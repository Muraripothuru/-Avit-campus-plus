import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/media/avatar_photo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/snackbar.dart';
import '../../core/utils/validators.dart';
import '../../models/user.dart';
import '../../widgets/avit_app_bar.dart';
import '../../widgets/avit_avatar.dart';
import '../../widgets/avit_cards.dart';
import '../../widgets/avit_feedback.dart';
import '../../widgets/avit_inputs.dart';

/// Edit the fields a student is allowed to change about themselves.
///
/// The campus inbox is editable here so a student can correct or attach their
/// student email, but it must stay an institutional address. Student ID,
/// role, semester and verification state still come from the institution and
/// are shown read-only.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _programmes = <String>[
    'B.Tech Computer Science and Engineering',
    'B.Tech Computer Science and Cyber Security',
    'B.Tech Information Technology',
    'B.Tech Electronics and Communication',
    'B.Tech Electrical and Electronics',
    'B.Tech Mechanical Engineering',
    'B.Tech Civil Engineering',
    'M.Tech Computer Science and Engineering',
    'Master of Business Administration',
    'Master of Computer Applications',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _programme = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _hostel = TextEditingController();
  final TextEditingController _emergency = TextEditingController();

  bool _ready = false;
  bool _saving = false;

  /// What the avatar section will save: `''` for initials, `avit://avatar/<i>`
  /// for a preset, or a `data:image/…` URI for an uploaded picture.
  String _avatarValue = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final AppUser? user = AppScope.of(context).state.user;
    if (user == null) return;
    _ready = true;
    _name.text = user.fullName;
    _email.text = user.email;
    _phone.text = user.phone;
    _programme.text = user.programme;
    _department.text = user.department;
    _hostel.text = user.hostel ?? '';
    _emergency.text = user.emergencyContact;
    _avatarValue = user.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _programme.dispose();
    _department.dispose();
    _hostel.dispose();
    _emergency.dispose();
    super.dispose();
  }

  /// Empty means "not added" — the profile shows it as such.
  static String? _optionalPhone(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return Validators.phone(v);
  }

  static String _digits(String value) =>
      value.trim().replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AppState state = AppScope.of(context).state;
    final AppUser? user = state.user;
    if (user == null) return;

    setState(() => _saving = true);

    final AppUser updated = user.copyWith(
      fullName: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
      phone: _digits(_phone.text),
      programme: _programme.text.trim(),
      department: _department.text.trim(),
      hostel: _hostel.text.trim(),
      emergencyContact: _digits(_emergency.text),
      avatarUrl: _avatarValue,
    );

    final bool ok = await state.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      showAVITSnackBar(
        context,
        message: 'Profile updated',
        tone: AVITSnackTone.success,
      );
      Navigator.of(context).pop();
    } else {
      showAVITSnackBar(
        context,
        message: state.lastError ?? 'Could not save your changes',
        tone: AVITSnackTone.error,
      );
    }
  }

  /// Asks the platform for a picture and takes it as the pending avatar.
  Future<void> _pickPhoto() async {
    final AppState state = AppScope.of(context).state;
    final AvatarPhotoResult result = await state.deps.photos.pick();
    if (!mounted || result.wasCancelled) return;
    if (result.dataUri != null) {
      setState(() => _avatarValue = result.dataUri!);
      return;
    }
    showAVITSnackBar(
      context,
      message: result.error ?? 'We could not use that picture',
      tone: AVITSnackTone.warning,
    );
  }

  void _removePhoto() => setState(() => _avatarValue = '');

  @override
  Widget build(BuildContext context) {
    final AppUser? user = AppScope.of(context).state.user;

    if (!_ready || user == null) {
      return const Scaffold(body: LoadingList(itemCount: 5));
    }

    final TextTheme text = Theme.of(context).textTheme;
    final AppUser preview = user.copyWith(avatarUrl: _avatarValue);
    final int? preset = avatarPresetIndex(_avatarValue);
    final bool hasPhoto = isAvatarPhoto(_avatarValue);

    return Scaffold(
      appBar: const AVITAppBar(title: 'Edit profile', subtitle: 'Your details'),
      body: AVITRefresh(
        onRefresh: () async => AppScope.of(context).state.loadSessionUser(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: <Widget>[
              AVITSectionHeader(
                title: 'Profile picture',
                subtitle: 'Upload your own or pick a look — shown everywhere',
              ),
              AVITCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        AVITAvatar(user: preview, radius: 26),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            hasPhoto
                                ? 'Your photo, shown across the app'
                                : preset == null
                                ? 'Your initials until you pick a picture'
                                : 'This is how you appear across the app',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasPhoto) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _removePhoto,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Remove photo'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        _UploadPhotoChoice(
                          selected: hasPhoto,
                          onTap: _pickPhoto,
                        ),
                        _PresetChoice(
                          selected: !hasPhoto && preset != null,
                          onTap: () =>
                              setState(() => _avatarValue = avatarValueFor(0)),
                        ),
                        _InitialsChoice(
                          selected: !hasPhoto && preset == null,
                          label: user.fullName,
                          onTap: () => setState(() => _avatarValue = ''),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AVITSectionHeader(
                title: 'Personal details',
                subtitle: 'Only these fields can be changed by you',
              ),
              AVITCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AVITTextField(
                      label: 'Full name',
                      required: true,
                      controller: _name,
                      maxLength: 60,
                      prefixIcon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Student email',
                      required: true,
                      controller: _email,
                      maxLength: 120,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                      hint: 'Your campus inbox, e.g. student@avit.ac.in',
                      validator: Validators.institutionalEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Mobile number',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 14,
                      prefixIcon: Icons.phone_outlined,
                      hint: 'Leave empty if you would rather not add one',
                      validator: _optionalPhone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITDropdown<String>(
                      label: 'Programme',
                      required: true,
                      value: _programme.text.isEmpty ? null : _programme.text,
                      items: <DropdownMenuItem<String>>[
                        for (final String p in _options(
                          _programmes,
                          _programme.text,
                        ))
                          DropdownMenuItem<String>(value: p, child: Text(p)),
                      ],
                      onChanged: (String? v) => setState(
                        () => _programme.text = v ?? _programme.text,
                      ),
                      validator: (String? v) => Validators.safeText(
                        v,
                        field: 'Programme',
                        minLength: 3,
                        maxLength: 80,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Department',
                      required: true,
                      controller: _department,
                      maxLength: 80,
                      prefixIcon: Icons.account_tree_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (String? v) => Validators.safeText(
                        v,
                        field: 'Department',
                        minLength: 3,
                        maxLength: 80,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Hostel / residence',
                      controller: _hostel,
                      maxLength: 60,
                      prefixIcon: Icons.apartment_outlined,
                      hint: 'Block and room, or leave empty if a day scholar',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AVITTextField(
                      label: 'Emergency contact',
                      controller: _emergency,
                      keyboardType: TextInputType.phone,
                      maxLength: 14,
                      prefixIcon: Icons.emergency_outlined,
                      hint: 'Someone we can reach if you need help',
                      validator: _optionalPhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AVITSectionHeader(
                title: 'Managed by AVIT',
                subtitle: 'Raised with the registrar to change',
              ),
              AVITCard(
                color: AppColors.surfaceMuted,
                borderColor: Colors.transparent,
                child: Column(
                  children: <Widget>[
                    _LockedRow(
                      icon: Icons.badge_outlined,
                      label: user.isStudent ? 'Student ID' : 'Staff ID',
                      value: user.displayId,
                    ),
                    const Divider(height: 1),
                    _LockedRow(
                      icon: Icons.school_outlined,
                      label: 'Semester',
                      value: user.semester == null
                          ? 'Not applicable'
                          : 'Semester ${user.semester}',
                    ),
                    const Divider(height: 1),
                    _LockedRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Role',
                      value: user.role.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AVITButton(
                label: 'Save changes',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps an account whose programme is not in the canonical list selectable
  /// instead of silently dropping it from the dropdown.
  static List<String> _options(List<String> base, String current) {
    final String value = current.trim();
    if (value.isEmpty || base.contains(value)) return base;
    return <String>[value, ...base];
  }
}

class _PresetChoice extends StatelessWidget {
  const _PresetChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillShape,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          AvatarSilhouette(
            size: 56,
            ring: Border.all(
              color: selected
                  ? AppColors.royalBlue
                  : AppColors.royalBlue.withValues(alpha: 0.3),
              width: selected ? 2.5 : 1,
            ),
          ),
          if (selected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadPhotoChoice extends StatelessWidget {
  const _UploadPhotoChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Upload a photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillShape,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.info.withValues(alpha: 0.14),
                border: Border.all(
                  color: selected
                      ? AppColors.info
                      : AppColors.info.withValues(alpha: 0.35),
                  width: selected ? 2.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.info,
                size: 24,
              ),
            ),
            if (selected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InitialsChoice extends StatelessWidget {
  const _InitialsChoice({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillShape,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.lightBlue,
          border: Border.all(
            color: selected
                ? AppColors.royalBlue
                : AppColors.royalBlue.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(label),
          style: const TextStyle(
            color: AppColors.royalBlue,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: text.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.titleSmall?.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
