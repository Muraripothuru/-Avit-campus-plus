import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../widgets/avit_cards.dart';

/// One entry in the campus service catalogue.
///
/// Shared by the Campus tab grid and the global search so the two can never
/// drift apart: a service the student can see on the Campus tab is always
/// findable by name from the search screen, and vice versa.
class ServiceEntry {
  const ServiceEntry(
    this.title,
    this.icon,
    this.route,
    this.subtitle,
    this.tone, {
    this.badgeKey,
  });

  final String title;
  final IconData icon;
  final String route;
  final String subtitle;
  final AVITStatusTone tone;

  /// LocalStore counter surfaced as a badge: `gate`, `visitor` or null.
  final String? badgeKey;

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        route.toLowerCase().contains(q);
  }
}

/// Every destination reachable from the Campus tab, grouped for browsing.
abstract final class ServiceCatalog {
  static const Map<String, List<ServiceEntry>> groups =
      <String, List<ServiceEntry>>{
        'Academics': <ServiceEntry>[
          ServiceEntry(
            'Timetable',
            Icons.schedule_rounded,
            Routes.timetable,
            'Week at a glance',
            AVITStatusTone.brand,
          ),
          ServiceEntry(
            'Attendance',
            Icons.pie_chart_rounded,
            Routes.attendance,
            'Subject-wise tracking',
            AVITStatusTone.brand,
          ),
          ServiceEntry(
            'Courses',
            Icons.menu_book_rounded,
            Routes.courses,
            'Syllabus & credits',
            AVITStatusTone.brand,
          ),
          ServiceEntry(
            'Examinations',
            Icons.assignment_rounded,
            Routes.examinations,
            'Hall tickets & dates',
            AVITStatusTone.warning,
          ),
          ServiceEntry(
            'Academic Calendar',
            Icons.calendar_month_rounded,
            Routes.academicCalendar,
            'Important dates',
            AVITStatusTone.info,
          ),
        ],
        'Passes & Movement': <ServiceEntry>[
          ServiceEntry(
            'Gate Pass',
            Icons.qr_code_rounded,
            Routes.gatePass,
            'Exit approval + QR',
            AVITStatusTone.brand,
            badgeKey: 'gate',
          ),
          ServiceEntry(
            'Visitor Pass',
            Icons.badge_rounded,
            Routes.visitorPass,
            'Invite someone on campus',
            AVITStatusTone.brand,
            badgeKey: 'visitor',
          ),
          ServiceEntry(
            'Transport',
            Icons.directions_bus_rounded,
            Routes.transport,
            'Bus routes & seats',
            AVITStatusTone.info,
          ),
          ServiceEntry(
            'Scanner',
            Icons.qr_code_scanner_rounded,
            Routes.scanner,
            'Scan any AVIT pass',
            AVITStatusTone.info,
          ),
        ],
        'On Campus': <ServiceEntry>[
          ServiceEntry(
            'Service Request',
            Icons.edit_note_rounded,
            Routes.serviceRequest,
            'Ask any campus unit',
            AVITStatusTone.brand,
          ),
          ServiceEntry(
            'Smart Queue',
            Icons.hourglass_top_rounded,
            Routes.smartQueue,
            'Skip the waiting line',
            AVITStatusTone.info,
          ),
          ServiceEntry(
            'Campus Map',
            Icons.map_rounded,
            Routes.campusMap,
            'Find any building',
            AVITStatusTone.info,
          ),
          ServiceEntry(
            'Library',
            Icons.local_library_rounded,
            Routes.library,
            'Hours, books, dues',
            AVITStatusTone.brand,
          ),
          ServiceEntry(
            'Cafeteria',
            Icons.restaurant_rounded,
            Routes.cafeteria,
            'Menu & timings',
            AVITStatusTone.success,
          ),
          ServiceEntry(
            'Hostel',
            Icons.apartment_rounded,
            Routes.hostel,
            'Rooms, mess, requests',
            AVITStatusTone.info,
          ),
          ServiceEntry(
            'Lost & Found',
            Icons.search_rounded,
            Routes.lostFound,
            'Report or claim an item',
            AVITStatusTone.warning,
          ),
          ServiceEntry(
            'Health Centre',
            Icons.local_hospital_rounded,
            Routes.healthCentre,
            'Appointments & first aid',
            AVITStatusTone.danger,
          ),
        ],
        'Safety': <ServiceEntry>[
          ServiceEntry(
            'Emergency',
            Icons.emergency_rounded,
            Routes.emergency,
            'One tap to alert security',
            AVITStatusTone.danger,
          ),
          ServiceEntry(
            'Report Incident',
            Icons.report_problem_rounded,
            Routes.reportIncident,
            'Confidential report',
            AVITStatusTone.danger,
          ),
          ServiceEntry(
            'Complaints',
            Icons.support_agent_rounded,
            Routes.complaints,
            'Track your requests',
            AVITStatusTone.warning,
          ),
        ],
      };

  /// Flat view used by the global search.
  static List<ServiceEntry> get all => <ServiceEntry>[
    for (final List<ServiceEntry> entries in groups.values) ...entries,
  ];
}
