import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/user.dart';

/// Marker scheme for a locally chosen profile picture.
///
/// A preset is stored as `avit://avatar/<index>` so no image bytes ever have
/// to travel through `avatarUrl`, and the account stays serialisable.
const String kAvatarScheme = 'avit://avatar/';

/// One selectable profile picture: an icon on a tinted disc.
class AvatarPreset {
  const AvatarPreset(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// The presets offered on the edit-profile screen. Order is part of the
/// contract: the index is what gets persisted.
const List<AvatarPreset> kAvatarPresets = <AvatarPreset>[
  AvatarPreset(Icons.auto_awesome_rounded, Color(0xFF1E4FD8)),
  AvatarPreset(Icons.pets_rounded, Color(0xFF12924F)),
  AvatarPreset(Icons.music_note_rounded, Color(0xFF7C3AED)),
  AvatarPreset(Icons.sports_basketball_rounded, Color(0xFFF0A11A)),
  AvatarPreset(Icons.local_fire_department_rounded, Color(0xFFD92D3F)),
  AvatarPreset(Icons.camera_alt_rounded, Color(0xFF2E7BE5)),
  AvatarPreset(Icons.brush_rounded, Color(0xFFDB2777)),
  AvatarPreset(Icons.code_rounded, Color(0xFF0F766E)),
];

/// Preset index encoded in [avatarUrl], or null when it is not a preset.
int? avatarPresetIndex(String? avatarUrl) {
  if (avatarUrl == null || !avatarUrl.startsWith(kAvatarScheme)) return null;
  final int? index = int.tryParse(
    avatarUrl.substring(kAvatarScheme.length).trim(),
  );
  if (index == null || index < 0 || index >= kAvatarPresets.length) return null;
  return index;
}

/// Persisted value for a preset choice.
String avatarValueFor(int index) => '$kAvatarScheme$index';

/// Round profile picture shared by the profile header and the edit screen.
///
/// Falls back to a network image for API-supplied avatars, and to the
/// account initials when there is nothing to show.
class AVITAvatar extends StatelessWidget {
  const AVITAvatar({
    super.key,
    required this.user,
    this.radius = 34,
    this.onDark = false,
  });

  final AppUser user;
  final double radius;

  /// Renders against a coloured/hero surface: the disc uses a translucent
  /// white fill so it reads on the gradient.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final int? preset = avatarPresetIndex(user.avatarUrl);
    final double diameter = radius * 2;

    if (preset != null) {
      final AvatarPreset spec = kAvatarPresets[preset];
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onDark
              ? AppColors.white.withValues(alpha: 0.18)
              : spec.color.withValues(alpha: 0.16),
          border: onDark
              ? Border.all(
                  color: AppColors.white.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : Border.all(color: spec.color.withValues(alpha: 0.45)),
        ),
        alignment: Alignment.center,
        child: Icon(
          spec.icon,
          size: radius,
          color: onDark ? AppColors.white : spec.color,
        ),
      );
    }

    final String url = user.avatarUrl ?? '';
    if (url.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Initials(
            radius: radius,
            name: user.fullName,
            onDark: onDark,
          ),
        ),
      );
    }

    return _Initials(radius: radius, name: user.fullName, onDark: onDark);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.radius,
    required this.name,
    required this.onDark,
  });

  final double radius;
  final String name;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark
            ? AppColors.white.withValues(alpha: 0.16)
            : AppColors.lightBlue,
        border: Border.all(
          color: onDark
              ? AppColors.white.withValues(alpha: 0.5)
              : AppColors.royalBlue.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        Formatters.initials(name),
        style: TextStyle(
          color: onDark ? AppColors.white : AppColors.royalBlue,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
