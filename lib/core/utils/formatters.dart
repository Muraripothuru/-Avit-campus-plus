import 'package:intl/intl.dart';

/// Date / time / display formatting helpers used across the app.
abstract final class Formatters {
  static final DateFormat dayLong = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat dayShort = DateFormat('d MMM yyyy');
  static final DateFormat time = DateFormat('hh:mm a');
  static final DateFormat time24 = DateFormat('HH:mm');
  static final DateFormat monthDay = DateFormat('d MMM');

  static String greeting(DateTime now) {
    final int hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  static String initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String relativeDay(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return 'In $diff days';
    return dayShort.format(date);
  }

  static String duration(Duration d) {
    if (d.inHours >= 1) {
      final int h = d.inHours;
      final int m = d.inMinutes.remainder(60);
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds}s';
  }

  static String percent(num value) => '${value.toStringAsFixed(0)}%';

  static String maskEmail(String email) {
    final int at = email.indexOf('@');
    if (at <= 2) return '***$email';
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  static String maskPhone(String phone) {
    if (phone.length < 6) return '****';
    return '******${phone.substring(phone.length - 4)}';
  }

  static String maskId(String id) {
    if (id.length <= 6) return id;
    return '${id.substring(0, 4)}${'*' * (id.length - 6)}${id.substring(id.length - 2)}';
  }
}
