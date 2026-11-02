import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';

/// Campus content models for the student Announcements section and the
/// Services grid — the content lists of the campus app lab.
///
/// Both classes carry stable IDs so list state (bookmarks) and navigation
/// targets stay keyed to the content, not to its position on screen.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.preview,
    required this.detail,
  });

  /// Stable identifier.
  final String id;
  final String title;

  /// Category label shown as a chip on the card and detail screen.
  final String category;

  /// Publication date of the announcement.
  final DateTime date;

  /// One-line summary shown on the list card.
  final String preview;

  /// Full body shown on the detail screen.
  final String detail;
}

/// One tile of the Services grid. [route] is the functional destination the
/// service's detail screen opens ("Open <label>" button).
class CampusService {
  const CampusService({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.description,
    required this.location,
    required this.hours,
    required this.contact,
  });

  /// Stable identifier.
  final String id;

  /// Tile label.
  final String label;

  /// Tile icon.
  final IconData icon;

  /// Functional destination of this service.
  final String route;

  /// Long-form copy shown on the service's detail screen.
  final String description;
  final String location;
  final String hours;
  final String contact;
}

/// Demonstration announcements shown when the content repository returns
/// nothing — eight entries, clearly demo data. Dates are computed once when
/// the fallback list is first read.
final List<Announcement> demoAnnouncements = <Announcement>[
  Announcement(
    id: 'content_ann_1',
    title: 'Main Gate restricted entry 10 PM - 5 AM',
    category: 'Security',
    date: _hoursAgo(2),
    preview:
        'Overnight entry is allowed only through the Main Gate with a valid '
        'college ID card.',
    detail:
        'Overnight entry is allowed only through the Main Gate with a valid '
        'college ID card. All side gates stay closed during these hours '
        'until further notice.',
  ),
  Announcement(
    id: 'content_ann_2',
    title: 'Emergency preparedness drill on Friday',
    category: 'Emergency',
    date: _hoursAgo(8),
    preview:
        'A fire and evacuation drill will run across all blocks on Friday at '
        '3:30 PM.',
    detail:
        'A fire and evacuation drill will run across all blocks on Friday '
        'at 3:30 PM. Follow staff instructions and assemble at the marked '
        'assembly points.',
  ),
  Announcement(
    id: 'content_ann_3',
    title: 'End Semester Examination — Time Table Released',
    category: 'Examination',
    date: _hoursAgo(3),
    preview:
        'The B.Tech End Semester examination time table for Semester 5 is '
        'now published.',
    detail:
        'The B.Tech End Semester examination time table for Semester 5 is '
        'now published. Download your hall ticket from the student portal '
        'before 5 October. Candidates must carry a college ID card.',
  ),
  Announcement(
    id: 'content_ann_4',
    title: 'Cybersecurity Hackathon — Registrations Open',
    category: 'Events',
    date: _daysAgo(1),
    preview:
        'Cyfence Club is organising a 24-hour hackathon on 18 October.',
    detail:
        'Cyfence Club is organising a 24-hour hackathon on 18 October. '
        'Teams of up to 4 can register from the Activities tab. Top three '
        'teams receive internship interviews with our industry partners.',
  ),
  Announcement(
    id: 'content_ann_5',
    title: 'Hostel Water Maintenance — Block B',
    category: 'Hostel',
    date: _daysAgo(2),
    preview:
        'Water supply to Block B will be interrupted on Thursday between '
        '10:00 AM and 2:00 PM.',
    detail:
        'Water supply to Block B will be interrupted on Thursday between '
        '10:00 AM and 2:00 PM for tank cleaning. Please store water in '
        'advance.',
  ),
  Announcement(
    id: 'content_ann_6',
    title: 'Bus Route 7 — Temporary Detour',
    category: 'Transport',
    date: _daysAgo(3),
    preview:
        'Route 7 (Tambaram) will operate via Rajiv Gandhi Salai until '
        'further notice.',
    detail:
        'Route 7 (Tambaram) will operate via Rajiv Gandhi Salai until '
        'further notice due to road work at St. Thomas Mount.',
  ),
  Announcement(
    id: 'content_ann_7',
    title: 'Campus Wifi Upgrade Complete',
    category: 'Campus',
    date: _daysAgo(5),
    preview:
        'Eduroam coverage has been extended to the central library reading '
        'hall and the open-air auditorium.',
    detail:
        'Eduroam coverage has been extended to the central library reading '
        'hall and the open-air auditorium. Reconnect your device to pick up '
        'the new access points.',
  ),
  Announcement(
    id: 'content_ann_8',
    title: 'Guest Lecture: Zero Trust Architectures',
    category: 'Academic',
    date: _daysAgo(6),
    preview:
        'Industry experts from CERT-In empanelled firms will speak on Zero '
        'Trust design on Friday.',
    detail:
        'Industry experts from CERT-In empanelled firms will speak on Zero '
        'Trust design on Friday, 2:00 PM, Seminar Hall A. Open to all '
        'final-year students.',
  ),
];

/// The six services of the Services grid — clearly demonstration data.
/// Each tile opens its own detail destination on the service detail route.
const List<CampusService> demoCampusServices = <CampusService>[
  CampusService(
    id: 'svc_library',
    label: 'Library',
    icon: Icons.local_library_rounded,
    route: Routes.library,
    description:
        'Search the catalogue, renew issues and clear dues before they pile '
        'up.',
    location: 'Library Block, Level 2',
    hours: 'Mon–Sat 8:30 AM–6:00 PM',
    contact: 'library@avit.ac.in',
  ),
  CampusService(
    id: 'svc_counselling',
    label: 'Counselling',
    icon: Icons.psychology_rounded,
    route: Routes.healthCentre,
    description:
        'Confidential academic and personal counselling with the campus '
        'wellness team.',
    location: 'Health Centre, near Sports Ground',
    hours: 'Mon–Sat 9:00 AM–5:00 PM',
    contact: 'wellness@avit.ac.in',
  ),
  CampusService(
    id: 'svc_accommodation',
    label: 'Accommodation',
    icon: Icons.apartment_rounded,
    route: Routes.hostel,
    description:
        'Room allotment, mess menu, maintenance requests and warden '
        'contacts.',
    location: 'Hostel Block, East Campus',
    hours: 'Warden desk 8:00 AM–9:00 PM',
    contact: 'hostel@avit.ac.in',
  ),
  CampusService(
    id: 'svc_career',
    label: 'Career Services',
    icon: Icons.work_rounded,
    route: Routes.activities,
    description:
        'Placements, internships, resume reviews and upcoming recruitment '
        'drives.',
    location: 'Placement & Training Cell, Admin Building',
    hours: 'Mon–Fri 9:00 AM–5:00 PM',
    contact: 'placements@avit.ac.in',
  ),
  CampusService(
    id: 'svc_sports',
    label: 'Sports',
    icon: Icons.sports_soccer_rounded,
    route: Routes.activities,
    description:
        'Ground bookings, intramural leagues and the daily sports complex '
        'timetable.',
    location: 'Sports Complex, South Campus',
    hours: 'Mon–Sat 4:00 PM–8:00 PM',
    contact: 'sports@avit.ac.in',
  ),
  CampusService(
    id: 'svc_it_helpdesk',
    label: 'IT Helpdesk',
    icon: Icons.support_agent_rounded,
    route: Routes.serviceRequest,
    description:
        'Campus Wi-Fi, portal accounts and lab machine issues — raise a '
        'request and track it.',
    location: 'IT Helpdesk, Student Centre Level 1',
    hours: 'Mon–Sat 9:00 AM–6:00 PM',
    contact: 'helpdesk@avit.ac.in',
  ),
];

DateTime _hoursAgo(int hours) =>
    DateTime.now().subtract(Duration(hours: hours));

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));
