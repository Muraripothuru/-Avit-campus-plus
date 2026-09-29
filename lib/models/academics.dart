/// Weekly timetable entry.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.subject,
    required this.code,
    required this.faculty,
    required this.room,
    required this.weekday, // 1 = Monday
    required this.startMinutes,
    required this.endMinutes,
    this.lab = false,
  });

  final String id;
  final String subject;
  final String code;
  final String faculty;
  final String room;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final bool lab;

  static int _mins(String hhmm) {
    final List<String> parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  factory TimetableEntry.fromSlot({
    required String id,
    required String subject,
    required String code,
    required String faculty,
    required String room,
    required int weekday,
    required String start,
    required String end,
    bool lab = false,
  }) => TimetableEntry(
    id: id,
    subject: subject,
    code: code,
    faculty: faculty,
    room: room,
    weekday: weekday,
    startMinutes: _mins(start),
    endMinutes: _mins(end),
    lab: lab,
  );

  String get startTime => _fmt(startMinutes);
  String get endTime => _fmt(endMinutes);

  static String _fmt(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    final String suffix = h >= 12 ? 'PM' : 'AM';
    final int hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  bool occursOn(int day) => weekday == day;

  bool overlaps(DateTime time) {
    final int now = time.hour * 60 + time.minute;
    return now >= startMinutes && now < endMinutes;
  }
}

/// Per-subject attendance record.
class AttendanceRecord {
  const AttendanceRecord({
    required this.subject,
    required this.code,
    required this.attended,
    required this.total,
    this.requiredPercent = 75,
  });

  final String subject;
  final String code;
  final int attended;
  final int total;
  final int requiredPercent;

  double get percentage => total == 0 ? 0 : (attended / total) * 100;
  int get missed => total - attended;

  /// Classes still needed to reach the required percentage.
  int get classesToReachRequired {
    if (total == 0) return requiredPercent;
    int needed = 0;
    while (needed < 200) {
      final double pct = ((attended + needed) / (total + needed)) * 100;
      if (pct >= requiredPercent) return needed;
      needed++;
    }
    return needed;
  }

  AttendanceStatus get status {
    final double p = percentage;
    if (p >= 85) return AttendanceStatus.healthy;
    if (p >= requiredPercent) return AttendanceStatus.warning;
    if (p >= requiredPercent - 10) return AttendanceStatus.risk;
    return AttendanceStatus.critical;
  }
}

enum AttendanceStatus {
  healthy('On track'),
  warning('Watch closely'),
  risk('At risk'),
  critical('Below requirement');

  const AttendanceStatus(this.label);
  final String label;
}

/// A course offering shown in the Academics tab.
class Course {
  const Course({
    required this.code,
    required this.name,
    required this.faculty,
    required this.credits,
    this.category = 'Core',
  });

  final String code;
  final String name;
  final String faculty;
  final int credits;
  final String category;
}

/// A scheduled examination.
class ExamSchedule {
  const ExamSchedule({
    required this.subject,
    required this.code,
    required this.date,
    required this.start,
    required this.end,
    required this.room,
    this.type = 'End Semester',
  });

  final String subject;
  final String code;
  final DateTime date;
  final String start;
  final String end;
  final String room;
  final String type;

  bool get isUpcoming => date.isAfter(DateTime.now());
}

/// Important academic calendar date.
class AcademicDate {
  const AcademicDate({
    required this.title,
    required this.date,
    this.detail = '',
    this.kind = 'info',
  });

  final String title;
  final DateTime date;
  final String detail;
  final String kind; // exam | holiday | event | info

  bool get isPast => date.isBefore(DateTime.now());
}
