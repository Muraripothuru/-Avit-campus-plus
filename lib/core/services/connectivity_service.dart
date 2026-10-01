import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Minimal online/offline signal.
///
/// Used only to degrade the UI gracefully (stale-data banners, disabled
/// submissions). Authorization is NEVER decided from cache — a stale offline
/// session can read cached content but cannot perform privileged actions.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  bool _online = true;
  bool _initialized = false;

  bool get isOnline => _online;
  bool get isInitialized => _initialized;

  Future<void> _init() async {
    try {
      await refresh();
      _connectivity.onConnectivityChanged.listen(_apply);
    } catch (_) {
      // Desktop/CI without the plugin: assume online, screens still handle
      // individual request failures.
      _online = true;
      _initialized = true;
      notifyListeners();
    }
  }

  /// Re-reads the platform connectivity and republishes only on a change.
  ///
  /// Returns the current online state so a "Try again" action can tell the
  /// user whether the retry helped without forcing a rebuild.
  Future<bool> refresh() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    _apply(results);
    return _online;
  }

  void _apply(List<ConnectivityResult> results) {
    final bool online = results.any(
      (ConnectivityResult r) => r != ConnectivityResult.none,
    );
    if (online != _online || !_initialized) {
      _online = online;
      _initialized = true;
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugSet(bool value) {
    _online = value;
    _initialized = true;
    notifyListeners();
  }
}
