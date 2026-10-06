import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../widgets/avit_cards.dart';

/// One entry in the campus service catalogue.
///
/// Shared by the Campus tab grid and the global search so the two can never
/// drift apart: a service the student can see on the Campus tab is always
/// findable by name from the search screen, and vice versa.
///
/// The `description`, `location`, `hours` and `contact` fields are the
/// CampusService detail data shown on the Service Details route — every
/// entry carries its own values so no two detail pages are identical.
class ServiceEntry {
  const ServiceEntry(
    this.title,
    this.icon,
    this.route,
    this.subtitle,
    this.tone, {
    required this.description,
    required this.location,
    required this.hours,
    required this.contact,
    this.status = 'Available',
    this.badgeKey,
  });

  final String title;
  final IconData icon;
  final String route;
  final String subtitle;
  final AVITStatusTone tone;

  /// Long-form copy shown on the Service Details route.
  final String description;

  /// Where the service is delivered.
  final String location;

  /// Opening hours shown on the detail route.
  final String hours;

  /// Enquiry contact shown on the detail route.
  final String contact;

  /// Live-looking service status shown as the chip on the detail route.
  final String status;

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
            description:
                'Your weekly class timetable with rooms, faculty and the '
                'highlighted next class.',
            location: 'Academic Block A • published by the Registrar',
            hours: 'Updated every semester',
            contact: 'registrar@avit.ac.in',
          ),
          ServiceEntry(
            'Attendance',
            Icons.pie_chart_rounded,
            Routes.attendance,
            'Subject-wise tracking',
            AVITStatusTone.brand,
            description:
                'Subject-wise attendance with shortage alerts and the '
                'required 75% marker.',
            location: 'Academic Block A, Room 12',
            hours: 'Mon–Sat 9:00 AM–4:00 PM',
            contact: 'attendance@avit.ac.in',
          ),
          ServiceEntry(
            'Courses',
            Icons.menu_book_rounded,
            Routes.courses,
            'Syllabus & credits',
            AVITStatusTone.brand,
            description:
                'Syllabus, credit load and course outcomes for your programme.',
            location: 'Academic Block A, Room 10',
            hours: 'Mon–Fri 9:30 AM–4:30 PM',
            contact: 'academics@avit.ac.in',
          ),
          ServiceEntry(
            'Examinations',
            Icons.assignment_rounded,
            Routes.examinations,
            'Hall tickets & dates',
            AVITStatusTone.warning,
            description:
                'Hall tickets, exam timetable, results and re-evaluation '
                'requests.',
            location: 'Examination Cell, Admin Building',
            hours: 'Mon–Fri 10:00 AM–3:00 PM',
            contact: 'exams@avit.ac.in',
            status: 'Exam season',
          ),
          ServiceEntry(
            'Academic Calendar',
            Icons.calendar_month_rounded,
            Routes.academicCalendar,
            'Important dates',
            AVITStatusTone.info,
            description:
                'Semester start dates, holidays, internal exams and '
                'placement windows at a glance.',
            location: 'Registrar Office, Admin Building',
            hours: 'Mon–Fri 9:00 AM–5:00 PM',
            contact: 'registrar@avit.ac.in',
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
            description:
                'Request exit approval from the warden and carry a scannable '
                'QR pass at the gate.',
            location: 'Security Cabin, Main Gate',
            hours: 'Open 24×7',
            contact: 'security@avit.ac.in',
          ),
          ServiceEntry(
            'Visitor Pass',
            Icons.badge_rounded,
            Routes.visitorPass,
            'Invite someone on campus',
            AVITStatusTone.brand,
            badgeKey: 'visitor',
            description:
                'Invite guests on campus in advance with a time-bound visitor '
                'pass.',
            location: 'Security Cabin, Main Gate',
            hours: 'Open 24×7',
            contact: 'visitors@avit.ac.in',
          ),
          ServiceEntry(
            'Transport',
            Icons.directions_bus_rounded,
            Routes.transport,
            'Bus routes & seats',
            AVITStatusTone.info,
            description:
                'Bus routes, stop timings, live seat counts and route '
                'changes.',
            location: 'Transport Office, Main Gate',
            hours: 'Mon–Sat 7:00 AM–7:00 PM',
            contact: 'transport@avit.ac.in',
            status: 'Limited seats',
          ),
          ServiceEntry(
            'Scanner',
            Icons.qr_code_scanner_rounded,
            Routes.scanner,
            'Scan any AVIT pass',
            AVITStatusTone.info,
            description:
                'Verify any gate or visitor pass QR at the counter in one '
                'scan.',
            location: 'Main Gate counter',
            hours: 'Open 24×7',
            contact: 'security@avit.ac.in',
          ),
        ],
        'On Campus': <ServiceEntry>[
          ServiceEntry(
            'Service Request',
            Icons.edit_note_rounded,
            Routes.serviceRequest,
            'Ask any campus unit',
            AVITStatusTone.brand,
            description:
                'Raise a validated request with any campus unit — helpdesk, '
                'facilities, accounts and more.',
            location: 'Student Centre, Level 1',
            hours: 'Mon–Fri 9:00 AM–5:00 PM',
            contact: 'helpdesk@avit.ac.in',
          ),
          ServiceEntry(
            'Smart Queue',
            Icons.hourglass_top_rounded,
            Routes.smartQueue,
            'Skip the waiting line',
            AVITStatusTone.info,
            description:
                'Book a slot before you walk over and watch the live queue '
                'from your phone.',
            location: 'Student Centre, Level 1',
            hours: 'Mon–Sat 8:30 AM–4:30 PM',
            contact: 'queues@avit.ac.in',
          ),
          ServiceEntry(
            'Campus Map',
            Icons.map_rounded,
            Routes.campusMap,
            'Find any building',
            AVITStatusTone.info,
            description:
                'Locate buildings, labs, blocks and landmarks with opening '
                'hours for each place.',
            location: 'Campus-wide wayfinding',
            hours: 'Available 24/7',
            contact: 'maps@avit.ac.in',
          ),
          ServiceEntry(
            'Library',
            Icons.local_library_rounded,
            Routes.library,
            'Hours, books, dues',
            AVITStatusTone.brand,
            description:
                'Search the catalogue, renew issues and clear dues before '
                'they pile up.',
            location: 'Library Block, Level 2',
            hours: 'Mon–Sat 8:30 AM–6:00 PM',
            contact: 'library@avit.ac.in',
            status: 'Open until 6 PM',
          ),
          ServiceEntry(
            'Cafeteria',
            Icons.restaurant_rounded,
            Routes.cafeteria,
            'Menu & timings',
            AVITStatusTone.success,
            description:
                'Today\'s menu, meal timings and prepaid balance top-ups.',
            location: 'Food Court, Student Centre',
            hours: 'Mon–Sat 7:30 AM–8:00 PM',
            contact: 'cafeteria@avit.ac.in',
            status: 'Lunch rush',
          ),
          ServiceEntry(
            'Hostel',
            Icons.apartment_rounded,
            Routes.hostel,
            'Rooms, mess, requests',
            AVITStatusTone.info,
            description:
                'Room allotment, mess menu, maintenance requests and warden '
                'contacts.',
            location: 'Hostel Block, East Campus',
            hours: 'Warden desk 8:00 AM–9:00 PM',
            contact: 'hostel@avit.ac.in',
          ),
          ServiceEntry(
            'Lost & Found',
            Icons.search_rounded,
            Routes.lostFound,
            'Report or claim an item',
            AVITStatusTone.warning,
            description:
                'Report something you lost or claim an item somebody else '
                'found on campus.',
            location: 'Student Centre, Level 1',
            hours: 'Mon–Fri 10:00 AM–4:00 PM',
            contact: 'lostfound@avit.ac.in',
          ),
          ServiceEntry(
            'Health Centre',
            Icons.local_hospital_rounded,
            Routes.healthCentre,
            'Appointments & first aid',
            AVITStatusTone.danger,
            description:
                'Book a consultation, walk in for first aid and keep your '
                'check-up history.',
            location: 'Health Centre, near Sports Ground',
            hours: 'Mon–Sat 8:00 AM–6:00 PM',
            contact: 'health@avit.ac.in',
            status: 'Walk-ins welcome',
          ),
        ],
        'Safety': <ServiceEntry>[
          ServiceEntry(
            'Emergency',
            Icons.emergency_rounded,
            Routes.emergency,
            'One tap to alert security',
            AVITStatusTone.danger,
            description:
                'One tap alerts the security control room with your live '
                'campus location.',
            location: 'Security Control Room, Main Gate',
            hours: 'Open 24×7',
            contact: 'emergency@avit.ac.in',
          ),
          ServiceEntry(
            'Report Incident',
            Icons.report_problem_rounded,
            Routes.reportIncident,
            'Confidential report',
            AVITStatusTone.danger,
            description:
                'File a confidential incident report that only authorised '
                'staff can read.',
            location: 'Security Control Room, Main Gate',
            hours: 'Open 24×7',
            contact: 'incident@avit.ac.in',
          ),
          ServiceEntry(
            'Complaints',
            Icons.support_agent_rounded,
            Routes.complaints,
            'Track your requests',
            AVITStatusTone.warning,
            description:
                'Log service complaints and follow their status until they '
                'are resolved.',
            location: 'Grievance Cell, Admin Building',
            hours: 'Mon–Fri 10:00 AM–4:00 PM',
            contact: 'grievance@avit.ac.in',
          ),
        ],
      };

  /// Flat view used by the global search.
  static List<ServiceEntry> get all => <ServiceEntry>[
    for (final List<ServiceEntry> entries in groups.values) ...entries,
  ];
}
