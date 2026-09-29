/// A campus event the student can register for.
class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.location,
    required this.organizer,
    required this.capacity,
    required this.registeredCount,
    this.imageAsset = '',
    this.category = 'Technical',
    this.fee = 0,
    this.registered = false,
    this.favourite = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final String location;
  final String organizer;
  final int capacity;
  final int registeredCount;
  final String imageAsset;
  final String category;
  final int fee;
  final bool registered;
  final bool favourite;

  int get seatsLeft => (capacity - registeredCount).clamp(0, capacity);
  bool get isFull => seatsLeft <= 0;
  bool get isPast => startsAt.isBefore(DateTime.now());

  CampusEvent copyWith({
    int? registeredCount,
    bool? registered,
    bool? favourite,
  }) => CampusEvent(
    id: id,
    title: title,
    description: description,
    startsAt: startsAt,
    location: location,
    organizer: organizer,
    capacity: capacity,
    registeredCount: registeredCount ?? this.registeredCount,
    imageAsset: imageAsset,
    category: category,
    fee: fee,
    registered: registered ?? this.registered,
    favourite: favourite ?? this.favourite,
  );

  factory CampusEvent.fromJson(Map<String, Object?> json) => CampusEvent(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    startsAt: DateTime.parse(json['startsAt'] as String),
    location: json['location'] as String? ?? '',
    organizer: json['organizer'] as String? ?? '',
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    registeredCount: (json['registeredCount'] as num?)?.toInt() ?? 0,
    imageAsset: json['imageAsset'] as String? ?? '',
    category: json['category'] as String? ?? 'Technical',
    fee: (json['fee'] as num?)?.toInt() ?? 0,
    registered: json['registered'] as bool? ?? false,
    favourite: json['favourite'] as bool? ?? false,
  );
}

/// Student clubs the user can follow.
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.memberCount,
    this.following = false,
    this.nextEvent,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int memberCount;
  final bool following;
  final String? nextEvent;

  Club copyWith({bool? following}) => Club(
    id: id,
    name: name,
    description: description,
    icon: icon,
    memberCount: memberCount,
    following: following ?? this.following,
    nextEvent: nextEvent,
  );
}
