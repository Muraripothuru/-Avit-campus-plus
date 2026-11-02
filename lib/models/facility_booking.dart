import 'package:flutter/material.dart';

/// Facility booking models for the campus booking lab.
///
/// A [Booking] stores exactly what the confirmation dialog reviews:
/// the facility, purpose and the computed start/end interval. IDs are
/// stable so conflict checks and cancellation never depend on list order.
class Booking {
  const Booking({
    required this.facilityId,
    required this.purpose,
    required this.start,
    required this.end,
  });

  /// Stable identifier of the booked facility.
  final String facilityId;

  /// What the student stated the booking is for.
  final String purpose;

  /// Inclusive interval start (bookings use half-open [start, end)).
  final DateTime start;

  /// Exclusive interval end.
  final DateTime end;
}

/// One of the four bookable campus facilities.
class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.location,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String location;
}

/// The four demonstration facilities offered by the booking form.
const List<Facility> demoFacilities = <Facility>[
  Facility(
    id: 'lib_discussion',
    name: 'Library Discussion Room',
    description: 'Quiet group-study room with a whiteboard and display.',
    icon: Icons.groups_rounded,
    location: 'Library Block, Level 2',
  ),
  Facility(
    id: 'sports_hall',
    name: 'Sports Hall',
    description: 'Indoor court for basketball, badminton and practice.',
    icon: Icons.sports_basketball_rounded,
    location: 'Sports Complex, South Campus',
  ),
  Facility(
    id: 'seminar_room',
    name: 'Seminar Room',
    description: 'Presentation room with projector and tiered seating.',
    icon: Icons.co_present_rounded,
    location: 'Academic Block A, Level 1',
  ),
  Facility(
    id: 'music_practice',
    name: 'Music Practice Room',
    description: 'Sound-treated room with piano and amplification.',
    icon: Icons.music_note_rounded,
    location: 'Student Centre, Level 2',
  ),
];

/// Looks up a facility by its stable ID for display in lists and dialogs.
Facility facilityById(String id) => demoFacilities.firstWhere(
  (Facility f) => f.id == id,
  orElse: () => demoFacilities.first,
);
