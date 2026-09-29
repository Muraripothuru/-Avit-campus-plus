/// In-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.receivedAt,
    this.read = false,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime receivedAt;
  final bool read;
  final String? actionRoute;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    category: category,
    receivedAt: receivedAt,
    read: read ?? this.read,
    actionRoute: actionRoute,
  );
}

enum NotificationCategory {
  academic('Academic', 'academic'),
  events('Events', 'events'),
  security('Security', 'security'),
  hostel('Hostel', 'hostel'),
  transport('Transport', 'transport'),
  system('System', 'system');

  const NotificationCategory(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static NotificationCategory fromApi(String value) =>
      NotificationCategory.values.firstWhere(
        (NotificationCategory c) => c.apiValue == value,
        orElse: () => NotificationCategory.system,
      );
}

/// Push registration payload prepared for FCM / a push gateway.
class PushSubscription {
  const PushSubscription({
    required this.deviceToken,
    required this.platform,
    this.topics = const <String>[],
  });

  final String deviceToken;
  final String platform;
  final List<String> topics;

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceToken': deviceToken,
    'platform': platform,
    'topics': topics,
  };
}
