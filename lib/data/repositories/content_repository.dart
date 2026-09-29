import '../../core/utils/app_exception.dart';
import '../../models/academics.dart';
import '../../models/announcement.dart';
import '../../models/app_notification.dart';
import '../../models/campus_event.dart';
import '../datasources/api_client.dart';
import '../datasources/demo_catalog.dart';
import '../datasources/local_store.dart';

/// Announcements + academic records.
abstract class ContentRepository {
  Future<List<Announcement>> announcements();
  Future<List<Course>> courses();
  Future<List<TimetableEntry>> timetable();
  Future<List<AttendanceRecord>> attendance();
  Future<List<ExamSchedule>> exams();
  Future<List<AcademicDate>> academicCalendar();
  Future<double> overallAttendance();
}

class DemoContentRepository implements ContentRepository {
  DemoContentRepository(this.store);

  final LocalStore store;

  static Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 220));

  @override
  Future<List<Announcement>> announcements() async {
    await _delay();
    final List<Announcement> list = List<Announcement>.of(store.announcements);
    list.sort((Announcement a, Announcement b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return list;
  }

  @override
  Future<List<Course>> courses() async {
    await _delay();
    return DemoCatalog.courses();
  }

  @override
  Future<List<TimetableEntry>> timetable() async {
    await _delay();
    return DemoCatalog.timetable();
  }

  @override
  Future<List<AttendanceRecord>> attendance() async {
    await _delay();
    return DemoCatalog.attendance();
  }

  @override
  Future<List<ExamSchedule>> exams() async {
    await _delay();
    return DemoCatalog.exams();
  }

  @override
  Future<List<AcademicDate>> academicCalendar() async {
    await _delay();
    return DemoCatalog.academicCalendar();
  }

  @override
  Future<double> overallAttendance() async {
    await _delay();
    return DemoCatalog.overallAttendance();
  }
}

class RemoteContentRepository implements ContentRepository {
  RemoteContentRepository(this.api);

  final ApiClient api;

  static List<T> _items<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items.whereType<Map<String, Object?>>().map(map).toList();
  }

  @override
  Future<List<Announcement>> announcements() async {
    try {
      final Map<String, Object?> res = await api.get('/announcements');
      return _items(
        res,
        (Map<String, Object?> j) => Announcement.fromJson(j),
      );
    } catch (e) {
      if (e is AppException && e.kind == 'offline') rethrow;
      rethrow;
    }
  }

  @override
  Future<List<Course>> courses() async => _items(
    await api.get('/academics/courses'),
    (Map<String, Object?> j) => Course(
      code: j['code'] as String? ?? '',
      name: j['name'] as String? ?? '',
      faculty: j['faculty'] as String? ?? '',
      credits: (j['credits'] as num?)?.toInt() ?? 0,
      category: j['category'] as String? ?? 'Core',
    ),
  );

  @override
  Future<List<TimetableEntry>> timetable() async => _items(
    await api.get('/academics/timetable'),
    (Map<String, Object?> j) => TimetableEntry.fromSlot(
      id: j['id'] as String? ?? '',
      subject: j['subject'] as String? ?? '',
      code: j['code'] as String? ?? '',
      faculty: j['faculty'] as String? ?? '',
      room: j['room'] as String? ?? '',
      weekday: (j['weekday'] as num?)?.toInt() ?? 1,
      start: j['start'] as String? ?? '09:00',
      end: j['end'] as String? ?? '10:00',
      lab: j['lab'] as bool? ?? false,
    ),
  );

  @override
  Future<List<AttendanceRecord>> attendance() async => _items(
    await api.get('/academics/attendance'),
    (Map<String, Object?> j) => AttendanceRecord(
      subject: j['subject'] as String? ?? '',
      code: j['code'] as String? ?? '',
      attended: (j['attended'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      requiredPercent: (j['requiredPercent'] as num?)?.toInt() ?? 75,
    ),
  );

  @override
  Future<List<ExamSchedule>> exams() async => _items(
    await api.get('/academics/exams'),
    (Map<String, Object?> j) => ExamSchedule(
      subject: j['subject'] as String? ?? '',
      code: j['code'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      start: j['start'] as String? ?? '',
      end: j['end'] as String? ?? '',
      room: j['room'] as String? ?? '',
      type: j['type'] as String? ?? 'End Semester',
    ),
  );

  @override
  Future<List<AcademicDate>> academicCalendar() async => _items(
    await api.get('/academics/calendar'),
    (Map<String, Object?> j) => AcademicDate(
      title: j['title'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      detail: j['detail'] as String? ?? '',
      kind: j['kind'] as String? ?? 'info',
    ),
  );

  @override
  Future<double> overallAttendance() async {
    final Map<String, Object?> res = await api.get('/academics/attendance');
    return (res['overall'] as num?)?.toDouble() ?? 0;
  }
}

/// Events, clubs and push notifications.
abstract class ActivityRepository {
  Future<List<CampusEvent>> events();
  Future<CampusEvent> register({required String eventId});
  Future<CampusEvent> unregister({required String eventId});
  Future<void> toggleFavourite({required String eventId});
  Future<List<Club>> clubs();
  Future<void> toggleFollow({required String clubId});
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
}

class DemoActivityRepository implements ActivityRepository {
  DemoActivityRepository(this.store);

  final LocalStore store;

  static Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<CampusEvent>> events() async {
    await _delay();
    final List<CampusEvent> list = List<CampusEvent>.of(store.events)
      ..sort((CampusEvent a, CampusEvent b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  @override
  Future<CampusEvent> register({required String eventId}) async {
    await _delay();
    final int index = store.events.indexWhere((CampusEvent e) => e.id == eventId);
    if (index < 0) throw AppException.notFound;
    final CampusEvent event = store.events[index];
    if (event.registered) {
      throw const AppException(
        'You are already registered for this event',
        kind: 'validation',
      );
    }
    if (event.isFull) {
      throw const AppException(
        'This event is fully booked',
        kind: 'validation',
      );
    }
    final CampusEvent updated = event.copyWith(
      registered: true,
      registeredCount: event.registeredCount + 1,
    );
    store.events[index] = updated;
    return updated;
  }

  @override
  Future<CampusEvent> unregister({required String eventId}) async {
    await _delay();
    final int index = store.events.indexWhere((CampusEvent e) => e.id == eventId);
    if (index < 0) throw AppException.notFound;
    final CampusEvent event = store.events[index];
    if (!event.registered) return event;
    final CampusEvent updated = event.copyWith(
      registered: false,
      registeredCount: (event.registeredCount - 1).clamp(0, event.capacity),
    );
    store.events[index] = updated;
    return updated;
  }

  @override
  Future<void> toggleFavourite({required String eventId}) async {
    await _delay();
    final int index = store.events.indexWhere((CampusEvent e) => e.id == eventId);
    if (index < 0) return;
    final CampusEvent event = store.events[index];
    store.events[index] = event.copyWith(favourite: !event.favourite);
  }

  @override
  Future<List<Club>> clubs() async {
    await _delay();
    return List<Club>.of(store.clubs);
  }

  @override
  Future<void> toggleFollow({required String clubId}) async {
    await _delay();
    final int index = store.clubs.indexWhere((Club c) => c.id == clubId);
    if (index < 0) return;
    final Club club = store.clubs[index];
    store.clubs[index] = club.copyWith(following: !club.following);
  }

  @override
  Future<List<AppNotification>> notifications() async {
    await _delay();
    return List<AppNotification>.of(store.notifications)
      ..sort(
        (AppNotification a, AppNotification b) =>
            b.receivedAt.compareTo(a.receivedAt),
      );
  }

  @override
  Future<void> markRead(String id) async {
    final int index = store.notifications
        .indexWhere((AppNotification n) => n.id == id);
    if (index < 0) return;
    store.notifications[index] = store.notifications[index].copyWith(read: true);
  }

  @override
  Future<void> markAllRead() async {
    for (int i = 0; i < store.notifications.length; i++) {
      store.notifications[i] = store.notifications[i].copyWith(read: true);
    }
  }

  @override
  Future<void> delete(String id) async {
    store.notifications.removeWhere((AppNotification n) => n.id == id);
  }
}

class RemoteActivityRepository implements ActivityRepository {
  RemoteActivityRepository(this.api);

  final ApiClient api;

  static List<T> _items<T>(
    Map<String, Object?> res,
    T Function(Map<String, Object?>) map,
  ) {
    final Object? items = res['items'];
    if (items is! List) return <T>[];
    return items.whereType<Map<String, Object?>>().map(map).toList();
  }

  @override
  Future<List<CampusEvent>> events() async => _items(
    await api.get('/events'),
    (Map<String, Object?> j) => CampusEvent.fromJson(j),
  );

  @override
  Future<CampusEvent> register({required String eventId}) async {
    final Map<String, Object?> res = await api.post('/events/$eventId/register');
    return CampusEvent.fromJson(
      res['item'] as Map<String, Object?>? ?? res,
    );
  }

  @override
  Future<CampusEvent> unregister({required String eventId}) async {
    final Map<String, Object?> res = await api.delete(
      '/events/$eventId/register',
    );
    return CampusEvent.fromJson(
      res['item'] as Map<String, Object?>? ?? res,
    );
  }

  @override
  Future<void> toggleFavourite({required String eventId}) =>
      api.post('/events/$eventId/favourite');

  @override
  Future<List<Club>> clubs() async => _items(
    await api.get('/clubs'),
    (Map<String, Object?> j) => Club(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      icon: j['icon'] as String? ?? 'people',
      memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
      following: j['following'] as bool? ?? false,
      nextEvent: j['nextEvent'] as String?,
    ),
  );

  @override
  Future<void> toggleFollow({required String clubId}) =>
      api.post('/clubs/$clubId/follow');

  @override
  Future<List<AppNotification>> notifications() async => _items(
    await api.get('/notifications'),
    (Map<String, Object?> j) => AppNotification(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      category: NotificationCategory.fromApi(j['category'] as String? ?? 'system'),
      receivedAt:
          DateTime.tryParse(j['receivedAt'] as String? ?? '') ?? DateTime.now(),
      read: j['read'] as bool? ?? false,
      actionRoute: j['actionRoute'] as String?,
    ),
  );

  @override
  Future<void> markRead(String id) => api.post('/notifications/$id/read');

  @override
  Future<void> markAllRead() => api.post('/notifications/read-all');

  @override
  Future<void> delete(String id) => api.delete('/notifications/$id');
}
