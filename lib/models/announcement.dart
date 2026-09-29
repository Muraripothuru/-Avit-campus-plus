/// A campus-wide announcement shown on the dashboard and Alerts tab.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.publishedAt,
    this.pinned = false,
    this.author = 'AVIT Campus',
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementCategory category;
  final DateTime publishedAt;
  final bool pinned;
  final String author;

  factory Announcement.fromJson(Map<String, Object?> json) => Announcement(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: announcementCategoryFromApi(
      json['category'] as String? ?? 'campus',
    ),
    publishedAt: DateTime.parse(json['publishedAt'] as String),
    pinned: json['pinned'] as bool? ?? false,
    author: json['author'] as String? ?? 'AVIT Campus',
  );
}

enum AnnouncementCategory {
  academic('Academic', 'academic'),
  exam('Examination', 'exam'),
  events('Events', 'events'),
  hostel('Hostel', 'hostel'),
  transport('Transport', 'transport'),
  security('Security', 'security'),
  campus('Campus', 'campus'),
  emergency('Emergency', 'emergency');

  const AnnouncementCategory(this.label, this.apiValue);
  final String label;
  final String apiValue;
}

AnnouncementCategory announcementCategoryFromApi(String value) =>
    AnnouncementCategory.values.firstWhere(
      (AnnouncementCategory c) => c.apiValue == value,
      orElse: () => AnnouncementCategory.campus,
    );
