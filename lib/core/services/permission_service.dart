/// Permission primitives requested lazily, with a pre-prompt explanation.
///
/// Rule: ask only when the feature that needs the permission is used, and
/// explain why before the OS dialog appears. Location is never polled in the
/// background.
enum AppPermission { location, camera, notifications, biometrics }

class PermissionResult {
  const PermissionResult(this.permission, this.granted, {this.deniedForever});
  final AppPermission permission;
  final bool granted;
  final bool? deniedForever;
}

/// Thin facade over the platform permission APIs.
///
/// Real platform calls are isolated behind [onRequest] so the rest of the app
/// depends on an interface and tests never hit a method channel. Production
/// builds inject the `permission_handler` implementation here.
class PermissionService {
  PermissionService({this.onRequest});

  final Future<bool> Function(AppPermission)? onRequest;

  final Map<AppPermission, bool> _status = <AppPermission, bool>{};

  bool isGranted(AppPermission permission) => _status[permission] ?? false;

  String rationale(AppPermission permission) => switch (permission) {
    AppPermission.location =>
      'AVIT Campus+ uses your location only while you raise an emergency or '
          'share your position on the campus map. It is never tracked in the '
          'background.',
    AppPermission.camera =>
      'The camera is used only to scan gate pass, visitor pass and event QR '
          'codes. Images are processed on-device.',
    AppPermission.notifications =>
      'Notifications keep you informed about announcements, gate pass '
          'approvals and emergency alerts.',
    AppPermission.biometrics =>
      'Biometric sign-in uses your device fingerprint or face data. Your '
          'biometric data never leaves your device.',
  };

  Future<PermissionResult> request(AppPermission permission) async {
    final Future<bool> Function(AppPermission)? handler = onRequest;
    // Without a platform handler, everything is granted except location so
    // the denial / rationale flow stays demonstrable.
    final bool granted = handler != null
        ? await handler(permission)
        : permission != AppPermission.location;
    _status[permission] = granted;
    return PermissionResult(permission, granted);
  }

  void reset() => _status.clear();
}
