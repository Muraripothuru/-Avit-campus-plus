import '../utils/app_exception.dart';

/// Sliding-window brute-force protection shared by login and OTP flows.
///
/// The authoritative copy lives on the server; this in-process limiter keeps
/// the UI honest (and protects the offline demo path) between deploys.
class RateLimiter {
  RateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 15),
    this.cooldown = const Duration(seconds: 30),
  });

  final int maxAttempts;
  final Duration window;
  final Duration cooldown;

  final Map<String, List<DateTime>> _attempts = <String, List<DateTime>>{};
  final Map<String, DateTime> _cooldowns = <String, DateTime>{};

  /// Throws [AppException] (kind `locked`) when the key is temporarily blocked.
  void check(String key, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    final DateTime? until = _cooldowns[key];
    if (until != null && current.isBefore(until)) {
      final int seconds = until.difference(current).inSeconds + 1;
      throw AppException(
        'Too many attempts. Try again in ${_humanise(seconds)}.',
        kind: 'locked',
      );
    }
    final List<DateTime> hits = _prune(key, current);
    if (hits.length >= maxAttempts) {
      _cooldowns[key] = current.add(window);
      _attempts[key] = <DateTime>[];
      throw AppException(
        'Too many attempts. Try again in ${_humanise(window.inSeconds)}.',
        kind: 'locked',
      );
    }
  }

  void recordFailure(String key, {DateTime? now}) {
    _attempts.putIfAbsent(key, () => <DateTime>[]).add(now ?? DateTime.now());
  }

  void reset(String key) {
    _attempts.remove(key);
    _cooldowns.remove(key);
  }

  int remainingAttempts(String key, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    return (maxAttempts - _prune(key, current).length).clamp(0, maxAttempts);
  }

  List<DateTime> _prune(String key, DateTime now) {
    final List<DateTime> hits = _attempts.putIfAbsent(
      key,
      () => <DateTime>[],
    );
    hits.removeWhere((DateTime t) => now.difference(t) > window);
    return hits;
  }

  static String _humanise(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    final int minutes = (seconds / 60).ceil();
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
}
