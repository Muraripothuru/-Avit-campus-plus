import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/media/avatar_photo.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/user.dart';

export '../core/media/avatar_photo.dart'
    show kAvatarDataPrefix, kMaxAvatarPhotoBytes, isAvatarPhoto;

/// Marker scheme for a locally chosen profile picture.
///
/// A preset is stored as `avit://avatar/<index>` so no image bytes ever have
/// to travel through `avatarUrl`, and the account stays serialisable.
const String kAvatarScheme = 'avit://avatar/';

/// The only preset offered: the generic person silhouette drawn by
/// [AvatarSilhouette]. Order is part of the contract — the index is what gets
/// persisted, so the single preset stays at index 0.
const int kAvatarPresetCount = 1;

/// Pale disc and mid-grey person of the "no picture yet" avatar.
const Color kSilhouetteDisc = Color(0xFFE4E4E4);
const Color kSilhouetteFigure = Color(0xFFA6A6A6);

/// The silhouette preset, drawn to scale rather than picked from an icon font
/// so it matches the reference artwork at any diameter.
class AvatarSilhouette extends StatelessWidget {
  const AvatarSilhouette({super.key, required this.size, this.ring});

  /// Diameter of the disc.
  final double size;

  /// Selection ring, painted over the disc when a screen needs one.
  final Border? ring;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SilhouettePainter(ring: ring),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter({this.ring});

  final Border? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.shortestSide / 2;
    final Offset c = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(c, r, Paint()..color = kSilhouetteDisc);

    // The shoulders are a wide circle sitting mostly below the disc, so only
    // its dome shows — and only where the disc allows.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
      c.translate(0, 1.044 * r),
      0.654 * r,
      Paint()..color = kSilhouetteFigure,
    );
    canvas.drawCircle(
      c.translate(0, -0.05 * r),
      0.35 * r,
      Paint()..color = kSilhouetteFigure,
    );
    canvas.restore();

    ring?.paint(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(_SilhouettePainter oldDelegate) =>
      oldDelegate.ring != ring;
}

/// Preset index encoded in [avatarUrl], or null when it is not a preset.
int? avatarPresetIndex(String? avatarUrl) {
  if (avatarUrl == null || !avatarUrl.startsWith(kAvatarScheme)) return null;
  final int? index = int.tryParse(
    avatarUrl.substring(kAvatarScheme.length).trim(),
  );
  if (index == null || index < 0 || index >= kAvatarPresetCount) return null;
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
      return AvatarSilhouette(size: diameter);
    }

    final String url = user.avatarUrl ?? '';
    if (isAvatarPhoto(url)) {
      return Container(
        width: diameter,
        height: diameter,
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
        clipBehavior: Clip.antiAlias,
        child: AvatarPhotoImage(
          dataUri: url,
          size: diameter,
          fallback: _InitialsText(
            radius: radius,
            name: user.fullName,
            onDark: onDark,
          ),
        ),
      );
    }

    if (url.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _Initials(radius: radius, name: user.fullName, onDark: onDark),
        ),
      );
    }

    return _Initials(radius: radius, name: user.fullName, onDark: onDark);
  }
}

/// An uploaded picture, decoded once per distinct value and cached for the
/// life of the app so rebuilds stay cheap.
class AvatarPhotoImage extends StatelessWidget {
  const AvatarPhotoImage({
    super.key,
    required this.dataUri,
    required this.size,
    required this.fallback,
  });

  final String dataUri;
  final double size;

  /// What to show while, or if, the picture cannot be read.
  final Widget fallback;

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Uint8List? _bytesOf(String uri) {
    final Uint8List? cached = _cache[uri];
    if (cached != null) return cached;
    final int comma = uri.indexOf(',');
    if (comma < 0) return null;
    try {
      final Uint8List bytes = base64Decode(uri.substring(comma + 1));
      if (_cache.length >= 8) _cache.remove(_cache.keys.first);
      _cache[uri] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytesOf(dataUri);
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Just the letters, for surfaces that paint their own disc.
class _InitialsText extends StatelessWidget {
  const _InitialsText({
    required this.radius,
    required this.name,
    required this.onDark,
  });

  final double radius;
  final String name;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      Formatters.initials(name),
      style: TextStyle(
        color: onDark ? AppColors.white : AppColors.royalBlue,
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w700,
      ),
    );
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
      child: _InitialsText(radius: radius, name: name, onDark: onDark),
    );
  }
}
