/// A campus bus route with timing and seat data.
class BusRoute {
  const BusRoute({
    required this.id,
    required this.routeName,
    required this.busNumber,
    required this.driverName,
    required this.driverPhone,
    required this.pickupPoints,
    required this.departure,
    required this.arrival,
    required this.totalSeats,
    required this.bookedSeats,
    this.status = 'On time',
    this.lastUpdated,
    this.ac = true,
  });

  final String id;
  final String routeName;
  final String busNumber;
  final String driverName;
  final String driverPhone;
  final List<String> pickupPoints;
  final String departure;
  final String arrival;
  final int totalSeats;
  final int bookedSeats;
  final String status;
  final DateTime? lastUpdated;
  final bool ac;

  int get availableSeats => (totalSeats - bookedSeats).clamp(0, totalSeats);
  bool get hasSeats => availableSeats > 0;
  double get occupancy => totalSeats == 0 ? 0 : bookedSeats / totalSeats;
}

/// A seat/request the student raised for a route.
class TransportRequest {
  const TransportRequest({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.studentId,
    required this.pickupPoint,
    required this.createdAt,
    this.status = 'Pending',
    this.seats = 1,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String studentId;
  final String pickupPoint;
  final DateTime createdAt;
  final String status;
  final int seats;
}

/// Smart Queue (token) system.
class QueueCounter {
  const QueueCounter({
    required this.id,
    required this.name,
    required this.icon,
    required this.currentToken,
    required this.yourToken,
    required this.avgServiceMinutes,
    this.location = 'Admin Block, Ground Floor',
    this.open = true,
  });

  final String id;
  final String name;
  final String icon;
  final int currentToken;
  final int yourToken;
  final int avgServiceMinutes;
  final String location;
  final bool open;

  int get peopleAhead => (yourToken - currentToken).clamp(0, 999);
  int get estimatedWaitMinutes => peopleAhead * avgServiceMinutes;

  double get progress {
    if (peopleAhead <= 0) return 1;
    final int total = yourToken - currentToken > 0
        ? yourToken - currentToken
        : 1;
    final int served = 0;
    return (served / total).clamp(0, 1);
  }
}

/// A campus location for the map / search.
class CampusLocation {
  const CampusLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.x, // normalised 0..1 coordinates on the campus canvas
    required this.y,
    this.hours = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double x;
  final double y;
  final String hours;
  final String phone;

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }
}
