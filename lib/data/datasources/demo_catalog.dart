import '../../models/academics.dart';
import '../../models/announcement.dart';
import '../../models/app_notification.dart';
import '../../models/campus_event.dart';
import '../../models/campus_services.dart';
import '../../models/pass.dart';
import '../../models/safety.dart';
import '../../models/user.dart';

/// Seed data used when no live API is configured (`--dart-define=API_BASE_URL`).
///
/// Everything here is clearly fictional development data — no real student
/// personal information is used anywhere.
abstract final class DemoCatalog {
  // ------------------------------------------------------------------ users
  static final AppUser student = AppUser(
    id: 'u_student_1',
    fullName: 'Arun Kumar',
    email: 'student@avit.ac.in',
    role: UserRole.student,
    studentId: 'AVIT2026CS001',
    phone: '9840012345',
    programme: 'B.Tech Computer Science and Cyber Security',
    department: 'Computer Science and Engineering',
    semester: 5,
    year: 3,
    hostel: 'Block B — Room 214',
    emergencyContact: '9840098765',
    emailVerified: true,
    phoneVerified: true,
    biometricEnabled: true,
    createdAt: DateTime(2023, 7, 12),
  );

  static final AppUser security = AppUser(
    id: 'u_security_1',
    fullName: 'Ravi Shankar',
    email: 'security@avit.ac.in',
    role: UserRole.security,
    studentId: 'AVITSEC001',
    phone: '9840022334',
    programme: 'Campus Security',
    department: 'Security Services',
    emailVerified: true,
    phoneVerified: true,
  );

  static const AppUser warden = AppUser(
    id: 'u_warden_1',
    fullName: 'Deepa Menon',
    email: 'warden@avit.ac.in',
    role: UserRole.warden,
    studentId: 'AVITWRD001',
    phone: '9840033445',
    programme: 'Hostel Warden',
    department: 'Student Affairs',
    hostel: 'Boys Hostel — Block B',
    emailVerified: true,
    phoneVerified: true,
  );

  static const AppUser admin = AppUser(
    id: 'u_admin_1',
    fullName: 'Suresh Iyer',
    email: 'admin@avit.ac.in',
    role: UserRole.admin,
    studentId: 'AVITADM001',
    phone: '9840044556',
    programme: 'Administration',
    department: 'Registrar Office',
    emailVerified: true,
    phoneVerified: true,
  );

  static final List<(UserRole, AppUser, String)> accounts = <(UserRole, AppUser, String)>[
    (UserRole.student, student, DemoCredentials.password),
    (UserRole.security, security, DemoCredentials.password),
    (UserRole.warden, warden, DemoCredentials.password),
    (UserRole.admin, admin, DemoCredentials.password),
  ];

  // ------------------------------------------------------------ announcements
  static List<Announcement> announcements() => <Announcement>[
    Announcement(
      id: 'ann_1',
      title: 'End Semester Examination — Time Table Released',
      body:
          'The B.Tech End Semester examination time table for Semester 5 is '
          'now published. Download your hall ticket from the student portal '
          'before 5 October. Candidates must carry a college ID card.',
      category: AnnouncementCategory.exam,
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      pinned: true,
      author: 'Controller of Examinations',
    ),
    Announcement(
      id: 'ann_2',
      title: 'Cybersecurity Hackathon — Registrations Open',
      body:
          'Cyfence Club is organising a 24-hour hackathon on 18 October. '
          'Teams of up to 4 can register from the Activities tab. Top three '
          'teams receive internship interviews with our industry partners.',
      category: AnnouncementCategory.events,
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      author: 'Cyfence Club',
    ),
    Announcement(
      id: 'ann_3',
      title: 'Hostel Water Maintenance — Block B',
      body:
          'Water supply to Block B will be interrupted on Thursday between '
          '10:00 AM and 2:00 PM for tank cleaning. Please store water in '
          'advance.',
      category: AnnouncementCategory.hostel,
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      author: 'Hostel Office',
    ),
    Announcement(
      id: 'ann_4',
      title: 'Bus Route 7 — Temporary Detour',
      body:
          'Route 7 (Tambaram) will operate via Rajiv Gandhi Salai until '
          'further notice due to road work at St. Thomas Mount.',
      category: AnnouncementCategory.transport,
      publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      author: 'Transport Department',
    ),
    Announcement(
      id: 'ann_5',
      title: 'Campus Wifi Upgrade Complete',
      body:
          'Eduroam coverage has been extended to the central library reading '
          'hall and the open-air auditorium. Reconnect your device to pick up '
          'the new access points.',
      category: AnnouncementCategory.campus,
      publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      author: 'IT Helpdesk',
    ),
    Announcement(
      id: 'ann_6',
      title: 'Guest Lecture: Zero Trust Architectures',
      body:
          'Industry experts from CERT-In empanelled firms will speak on Zero '
          'Trust design on Friday, 2:00 PM, Seminar Hall A. Open to all '
          'final-year students.',
      category: AnnouncementCategory.academic,
      publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      author: 'Department of CSE',
    ),
  ];

  // ------------------------------------------------------------------ events
  static List<CampusEvent> events() => <CampusEvent>[
    CampusEvent(
      id: 'ev_1',
      title: 'AVIT Cybersecurity Hackathon',
      description:
          'A 24-hour overnight hackathon focused on defensive security, '
          'capture-the-flag challenges and secure coding. Mentors from '
          'industry will be on site through the night.',
      startsAt: _nextDate(18, 8, 0),
      location: 'Innovation Lab, AB Block',
      organizer: 'Cyfence Club',
      capacity: 120,
      registeredCount: 96,
      category: 'Technical',
      imageAsset: 'cyber',
    ),
    CampusEvent(
      id: 'ev_2',
      title: 'Cloud Security Workshop',
      description:
          'Hands-on workshop covering IAM hardening, container runtime '
          'security and incident response on public cloud.',
      startsAt: _nextDate(9, 10, 30),
      location: 'Smart Classroom 2, CD Block',
      organizer: 'Department of CSE',
      capacity: 60,
      registeredCount: 42,
      category: 'Workshop',
      imageAsset: 'cloud',
    ),
    CampusEvent(
      id: 'ev_3',
      title: 'Inter-College Sports Meet',
      description:
          'Athletics, football, volleyball and cricket championships across '
          'fourteen participating colleges.',
      startsAt: _nextDate(25, 7, 0),
      location: 'AVIT Sports Complex',
      organizer: 'Sports Club',
      capacity: 500,
      registeredCount: 312,
      category: 'Sports',
      imageAsset: 'sports',
    ),
    CampusEvent(
      id: 'ev_4',
      title: 'Kavigaram Cultural Festival',
      description:
          'Two days of music, dance, street play and literary events. '
          'Open to all students — register for individual or team categories.',
      startsAt: _nextDate(31, 17, 0),
      location: 'Open Air Auditorium',
      organizer: 'Cultural Club',
      capacity: 800,
      registeredCount: 540,
      category: 'Cultural',
      imageAsset: 'culture',
    ),
    CampusEvent(
      id: 'ev_5',
      title: 'Campus Placement Fair 2026',
      description:
          'Forty-two recruiters across product, core and consulting roles. '
          'Resume screening opens one week before the fair.',
      startsAt: _nextDate(12, 9, 0),
      location: 'Placement Hall, Admin Block',
      organizer: 'Training & Placement Cell',
      capacity: 300,
      registeredCount: 300,
      category: 'Career',
      imageAsset: 'career',
    ),
    CampusEvent(
      id: 'ev_6',
      title: 'Robotics Build Sprint',
      description:
          'Build and battle autonomous rovers. Components and tools '
          'provided. Open to first and second year students.',
      startsAt: _nextDate(6, 14, 0),
      location: 'Robotics Lab, AB Block',
      organizer: 'Robotics Club',
      capacity: 40,
      registeredCount: 18,
      category: 'Technical',
      imageAsset: 'robotics',
    ),
  ];

  static List<Club> clubs() => <Club>[
    const Club(
      id: 'club_1',
      name: 'Cyfence Club',
      description: 'Cybersecurity CTFs, labs and capture-the-flag nights.',
      icon: 'shield',
      memberCount: 340,
      following: true,
      nextEvent: 'AVIT Cybersecurity Hackathon',
    ),
    const Club(
      id: 'club_2',
      name: 'Coding Club',
      description: 'Competitive programming, interviews and open source.',
      icon: 'code',
      memberCount: 520,
      nextEvent: 'Weekly Contest #42',
    ),
    const Club(
      id: 'club_3',
      name: 'Robotics Club',
      description: 'Rovers, drones and embedded systems builds.',
      icon: 'robot',
      memberCount: 210,
      following: true,
      nextEvent: 'Robotics Build Sprint',
    ),
    const Club(
      id: 'club_4',
      name: 'Sports Club',
      description: 'Inter-college athletics, football and indoor games.',
      icon: 'sports',
      memberCount: 640,
      nextEvent: 'Inter-College Sports Meet',
    ),
    const Club(
      id: 'club_5',
      name: 'Cultural Club',
      description: 'Music, dance, drama and literary competitions.',
      icon: 'music',
      memberCount: 720,
      nextEvent: 'Kavigaram Cultural Festival',
    ),
    const Club(
      id: 'club_6',
      name: 'Entrepreneurship Club',
      description: 'Startup mentoring, pitch nights and founder talks.',
      icon: 'rocket',
      memberCount: 180,
      nextEvent: 'Founder Fireside Chat',
    ),
  ];

  // -------------------------------------------------------------- academics
  static List<Course> courses() => const <Course>[
    Course(
      code: 'CS8491',
      name: 'Network Security',
      faculty: 'Dr. K. Meenakshi',
      credits: 4,
      category: 'Core',
    ),
    Course(
      code: 'CS8492',
      name: 'Cloud Security',
      faculty: 'Dr. S. Raghavan',
      credits: 4,
      category: 'Core',
    ),
    Course(
      code: 'CS8451',
      name: 'Data Mining',
      faculty: 'Dr. P. Lakshmi',
      credits: 3,
      category: 'Elective',
    ),
    Course(
      code: 'CS8493',
      name: 'Digital Forensics',
      faculty: 'Prof. A. Nirmal',
      credits: 3,
      category: 'Core',
    ),
    Course(
      code: 'MA8401',
      name: 'Applied Statistics',
      faculty: 'Dr. R. Swaminathan',
      credits: 3,
      category: 'Foundation',
    ),
    Course(
      code: 'CS8461',
      name: 'Secure Application Development',
      faculty: 'Prof. V. Divya',
      credits: 4,
      category: 'Elective',
    ),
  ];

  static List<TimetableEntry> timetable() => <TimetableEntry>[
    for (int day = 1; day <= 6; day++) ...<TimetableEntry>[
      TimetableEntry.fromSlot(
        id: 'tt_${day}_1',
        subject: 'Network Security',
        code: 'CS8491',
        faculty: 'Dr. K. Meenakshi',
        room: 'AB-204',
        weekday: day,
        start: '09:00',
        end: '10:00',
      ),
      TimetableEntry.fromSlot(
        id: 'tt_${day}_2',
        subject: 'Cloud Security',
        code: 'CS8492',
        faculty: 'Dr. S. Raghavan',
        room: 'AB-204',
        weekday: day,
        start: '11:00',
        end: '12:00',
      ),
      TimetableEntry.fromSlot(
        id: 'tt_${day}_3',
        subject: 'Data Mining',
        code: 'CS8451',
        faculty: 'Dr. P. Lakshmi',
        room: 'CD-105',
        weekday: day,
        start: '14:00',
        end: '15:00',
      ),
      TimetableEntry.fromSlot(
        id: 'tt_${day}_4',
        subject: day % 2 == 0 ? 'Digital Forensics Lab' : 'Secure Dev Lab',
        code: day % 2 == 0 ? 'CS8493' : 'CS8461',
        faculty: day % 2 == 0 ? 'Prof. A. Nirmal' : 'Prof. V. Divya',
        room: 'AB-Lab 3',
        weekday: day,
        start: '15:15',
        end: '17:15',
        lab: true,
      ),
    ],
  ];

  static List<AttendanceRecord> attendance() => const <AttendanceRecord>[
    AttendanceRecord(subject: 'Network Security', code: 'CS8491', attended: 42, total: 48),
    AttendanceRecord(subject: 'Cloud Security', code: 'CS8492', attended: 39, total: 46),
    AttendanceRecord(subject: 'Data Mining', code: 'CS8451', attended: 33, total: 44),
    AttendanceRecord(subject: 'Digital Forensics', code: 'CS8493', attended: 41, total: 45),
    AttendanceRecord(subject: 'Applied Statistics', code: 'MA8401', attended: 30, total: 42),
    AttendanceRecord(subject: 'Secure Application Development', code: 'CS8461', attended: 44, total: 47),
  ];

  static double overallAttendance() {
    final List<AttendanceRecord> records = attendance();
    final int attended = records.fold<int>(0, (int a, AttendanceRecord r) => a + r.attended);
    final int total = records.fold<int>(0, (int a, AttendanceRecord r) => a + r.total);
    return total == 0 ? 0 : attended / total * 100;
  }

  static List<ExamSchedule> exams() {
    final DateTime base = _nextDate(10, 9, 30);
    return <ExamSchedule>[
      ExamSchedule(
        subject: 'Network Security',
        code: 'CS8491',
        date: base,
        start: '09:30',
        end: '12:30',
        room: 'Hall A - 12',
      ),
      ExamSchedule(
        subject: 'Cloud Security',
        code: 'CS8492',
        date: base.add(const Duration(days: 2)),
        start: '09:30',
        end: '12:30',
        room: 'Hall A - 14',
      ),
      ExamSchedule(
        subject: 'Data Mining',
        code: 'CS8451',
        date: base.add(const Duration(days: 4)),
        start: '14:00',
        end: '17:00',
        room: 'Hall B - 03',
      ),
      ExamSchedule(
        subject: 'Digital Forensics',
        code: 'CS8493',
        date: base.add(const Duration(days: 6)),
        start: '09:30',
        end: '12:30',
        room: 'Hall B - 07',
      ),
    ];
  }

  static List<AcademicDate> academicCalendar() {
    final DateTime now = DateTime.now();
    return <AcademicDate>[
      AcademicDate(
        title: 'Semester 5 begins',
        date: DateTime(now.year, 7, 21),
        detail: 'Class work resumes for all UG programmes',
        kind: 'info',
      ),
      AcademicDate(
        title: 'Internal Assessment 1',
        date: _nextDate(3, 9, 0),
        detail: 'Days 1-3, all subjects',
        kind: 'exam',
      ),
      AcademicDate(
        title: 'Registration deadline for elective courses',
        date: _nextDate(7, 17, 0),
        detail: 'Course registration closes at 5:00 PM',
        kind: 'info',
      ),
      AcademicDate(
        title: 'Semester break begins',
        date: _nextDate(46, 9, 0),
        detail: 'Classes resume after the break on the notified date',
        kind: 'holiday',
      ),
      AcademicDate(
        title: 'End Semester Examinations',
        date: _nextDate(10, 9, 30),
        detail: 'Hall tickets available 7 days before the exam',
        kind: 'exam',
      ),
      AcademicDate(
        title: 'Convocation rehearsal',
        date: _nextDate(60, 10, 0),
        detail: 'Final-year students only',
        kind: 'event',
      ),
    ];
  }

  // ---------------------------------------------------------------- passes
  static List<GatePass> gatePasses() => <GatePass>[
    GatePass(
      id: 'gp_1',
      studentId: DemoCatalog.student.studentId!,
      studentName: DemoCatalog.student.fullName,
      reason: 'Medical appointment',
      destination: 'Apollo Clinic, Vandalur',
      outAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
      inBy: DateTime.now().add(const Duration(days: 1, hours: 7)),
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      status: PassStatus.approved,
      reviewerComment: 'Approved by warden',
      reviewedBy: 'Deepa Menon',
      reviewedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    GatePass(
      id: 'gp_2',
      studentId: DemoCatalog.student.studentId!,
      studentName: DemoCatalog.student.fullName,
      reason: 'Bank work',
      destination: 'Canara Bank, Selaiyur',
      outAt: DateTime.now().add(const Duration(days: 3, hours: 1)),
      inBy: DateTime.now().add(const Duration(days: 3, hours: 5)),
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      status: PassStatus.pending,
    ),
    GatePass(
      id: 'gp_3',
      studentId: DemoCatalog.student.studentId!,
      studentName: DemoCatalog.student.fullName,
      reason: 'Home visit',
      destination: 'Chengalpattu',
      outAt: DateTime.now().subtract(const Duration(days: 5)),
      inBy: DateTime.now().subtract(const Duration(days: 4)),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      status: PassStatus.used,
      reviewedBy: 'Ravi Shankar',
      usedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    GatePass(
      id: 'gp_4',
      studentId: 'AVIT2026EC014',
      studentName: 'Priya Raghavan',
      reason: 'Family event',
      destination: 'Tambaram',
      outAt: DateTime.now().add(const Duration(hours: 5)),
      inBy: DateTime.now().add(const Duration(hours: 12)),
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      status: PassStatus.pending,
    ),
    GatePass(
      id: 'gp_5',
      studentId: 'AVIT2026ME009',
      studentName: 'Karthik Subramani',
      reason: 'Project material purchase',
      destination: 'Ritchie Street, Mount Road',
      outAt: DateTime.now().add(const Duration(days: 2)),
      inBy: DateTime.now().add(const Duration(days: 2, hours: 8)),
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: PassStatus.pending,
    ),
  ];

  static List<VisitorPass> visitorPasses() => <VisitorPass>[
    VisitorPass(
      id: 'vp_1',
      hostStudentId: DemoCatalog.student.studentId!,
      hostStudentName: DemoCatalog.student.fullName,
      visitorName: 'Rajesh Kumar',
      visitorPhone: '9000011111',
      idType: 'Aadhaar',
      visitDate: DateTime.now().add(const Duration(days: 1)),
      purpose: 'Parent visit',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      status: PassStatus.approved,
      reviewedBy: 'Deepa Menon',
    ),
    VisitorPass(
      id: 'vp_2',
      hostStudentId: DemoCatalog.student.studentId!,
      hostStudentName: DemoCatalog.student.fullName,
      visitorName: 'Lakshmi Raghavan',
      visitorPhone: '9000022222',
      idType: 'Driving Licence',
      visitDate: DateTime.now().add(const Duration(days: 4)),
      purpose: 'Delivering study material',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: PassStatus.pending,
    ),
    VisitorPass(
      id: 'vp_3',
      hostStudentId: 'AVIT2026EC014',
      hostStudentName: 'Priya Raghavan',
      visitorName: 'Suresh Babu',
      visitorPhone: '9000033333',
      idType: 'Voter ID',
      visitDate: DateTime.now().add(const Duration(hours: 6)),
      purpose: 'Guardian meeting with warden',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      status: PassStatus.pending,
    ),
  ];

  // -------------------------------------------------------------- transport
  static List<BusRoute> busRoutes() => const <BusRoute>[
    BusRoute(
      id: 'bus_1',
      routeName: 'Route 1 — Tambaram',
      busNumber: 'TN 09 AB 4521',
      driverName: 'M. Selvam',
      driverPhone: '9840011223',
      pickupPoints: <String>['Tambaram Bus Stand', 'Vandalur', 'Campus Main Gate'],
      departure: '07:15 AM',
      arrival: '08:30 AM',
      totalSeats: 52,
      bookedSeats: 44,
      status: 'On time',
      ac: true,
    ),
    BusRoute(
      id: 'bus_2',
      routeName: 'Route 2 — Chennai Central',
      busNumber: 'TN 09 AB 7788',
      driverName: 'K. Dhandapani',
      driverPhone: '9840022334',
      pickupPoints: <String>['Central Railway Station', 'Guindy', 'Campus Main Gate'],
      departure: '07:00 AM',
      arrival: '08:45 AM',
      totalSeats: 52,
      bookedSeats: 52,
      status: 'On time',
    ),
    BusRoute(
      id: 'bus_3',
      routeName: 'Route 3 — Chengalpattu',
      busNumber: 'TN 09 AB 3311',
      driverName: 'A. Perumal',
      driverPhone: '9840033445',
      pickupPoints: <String>['Chengalpattu Bus Stand', 'Tambaram', 'Campus Main Gate'],
      departure: '06:45 AM',
      arrival: '08:15 AM',
      totalSeats: 44,
      bookedSeats: 30,
      status: 'Delayed 10 min',
      ac: false,
    ),
    BusRoute(
      id: 'bus_4',
      routeName: 'Route 4 — Guduvancheri',
      busNumber: 'TN 09 AB 9902',
      driverName: 'S. Ramesh',
      driverPhone: '9840044556',
      pickupPoints: <String>['Guduvancheri', 'Urapakkam', 'Campus Main Gate'],
      departure: '07:30 AM',
      arrival: '08:35 AM',
      totalSeats: 44,
      bookedSeats: 21,
      status: 'On time',
      ac: true,
    ),
    BusRoute(
      id: 'bus_5',
      routeName: 'Route 5 — Medavakkam',
      busNumber: 'TN 09 AB 6614',
      driverName: 'J. Baskaran',
      driverPhone: '9840055667',
      pickupPoints: <String>['Medavakkam Koot Road', 'Velachery', 'Campus Main Gate'],
      departure: '07:10 AM',
      arrival: '08:40 AM',
      totalSeats: 52,
      bookedSeats: 48,
      status: 'On time',
    ),
  ];

  // ---------------------------------------------------------- smart queue
  static List<QueueCounter> queueCounters() {
    const List<QueueCounter> base = <QueueCounter>[
      QueueCounter(
        id: 'q1',
        name: 'Student Affairs',
        icon: 'people',
        currentToken: 42,
        yourToken: 57,
        avgServiceMinutes: 3,
        location: 'Admin Block, Ground Floor',
      ),
      QueueCounter(
        id: 'q2',
        name: 'Administration',
        icon: 'building',
        currentToken: 18,
        yourToken: 26,
        avgServiceMinutes: 4,
        location: 'Admin Block, First Floor',
      ),
      QueueCounter(
        id: 'q3',
        name: 'Accounts',
        icon: 'wallet',
        currentToken: 31,
        yourToken: 33,
        avgServiceMinutes: 2,
        location: 'Admin Block, Ground Floor',
      ),
      QueueCounter(
        id: 'q4',
        name: 'Library',
        icon: 'book',
        currentToken: 12,
        yourToken: 14,
        avgServiceMinutes: 2,
        location: 'Central Library, Circulation Desk',
      ),
      QueueCounter(
        id: 'q5',
        name: 'Hostel Office',
        icon: 'hostel',
        currentToken: 7,
        yourToken: 11,
        avgServiceMinutes: 5,
        location: 'Hostel Administration Block',
      ),
      QueueCounter(
        id: 'q6',
        name: 'IT Helpdesk',
        icon: 'it',
        currentToken: 24,
        yourToken: 25,
        avgServiceMinutes: 4,
        location: 'CD Block, Room 001',
        open: false,
      ),
    ];
    return base;
  }

  // ------------------------------------------------------------ campus map
  static List<CampusLocation> locations() => const <CampusLocation>[
    CampusLocation(
      id: 'loc_1',
      name: 'AB Block',
      category: 'Academic',
      description: 'Computer Science & IT laboratories and faculty cabins.',
      x: 0.22,
      y: 0.28,
      hours: '8:00 AM - 6:00 PM',
    ),
    CampusLocation(
      id: 'loc_2',
      name: 'CD Block',
      category: 'Academic',
      description: 'Smart classrooms, seminar halls and IT helpdesk.',
      x: 0.44,
      y: 0.22,
      hours: '8:00 AM - 6:00 PM',
    ),
    CampusLocation(
      id: 'loc_3',
      name: 'Central Library',
      category: 'Library',
      description: 'Four-floor library with reading hall and digital lab.',
      x: 0.66,
      y: 0.30,
      hours: '8:00 AM - 8:00 PM',
      phone: '044-4747 2300',
    ),
    CampusLocation(
      id: 'loc_4',
      name: 'Boys Hostel — Block B',
      category: 'Hostel',
      description: 'Residency for outstation students with mess facility.',
      x: 0.16,
      y: 0.66,
    ),
    CampusLocation(
      id: 'loc_5',
      name: 'Girls Hostel',
      category: 'Hostel',
      description: 'Secured residency with 24x7 warden support.',
      x: 0.34,
      y: 0.74,
    ),
    CampusLocation(
      id: 'loc_6',
      name: 'Cafeteria',
      category: 'Dining',
      description: 'Subsidised mess, snacks and juice counter.',
      x: 0.55,
      y: 0.62,
      hours: '7:30 AM - 9:00 PM',
    ),
    CampusLocation(
      id: 'loc_7',
      name: 'Security Office',
      category: 'Safety',
      description: 'Main gate security desk and control room.',
      x: 0.84,
      y: 0.52,
      hours: '24x7',
      phone: '044-4747 2300',
    ),
    CampusLocation(
      id: 'loc_8',
      name: 'Parking',
      category: 'Facilities',
      description: 'Two-wheeler and four-wheeler parking bay.',
      x: 0.80,
      y: 0.72,
    ),
    CampusLocation(
      id: 'loc_9',
      name: 'Sports Complex',
      category: 'Sports',
      description: 'Indoor stadium, gym and outdoor courts.',
      x: 0.70,
      y: 0.82,
      hours: '6:00 AM - 8:00 PM',
    ),
    CampusLocation(
      id: 'loc_10',
      name: 'Medical Centre',
      category: 'Health',
      description: 'Campus doctor, first aid and ambulance bay.',
      x: 0.46,
      y: 0.44,
      hours: '9:00 AM - 6:00 PM',
      phone: '044-4747 2310',
    ),
    CampusLocation(
      id: 'loc_11',
      name: 'Administration Block',
      category: 'Administration',
      description: 'Registrar, accounts and examination sections.',
      x: 0.30,
      y: 0.46,
      hours: '9:00 AM - 5:00 PM',
    ),
    CampusLocation(
      id: 'loc_12',
      name: 'Open Air Auditorium',
      category: 'Facilities',
      description: 'Venue for cultural festivals and guest lectures.',
      x: 0.60,
      y: 0.15,
    ),
  ];

  // -------------------------------------------------------- notifications
  static List<AppNotification> notifications() => <AppNotification>[
    AppNotification(
      id: 'nt_1',
      title: 'Gate pass approved',
      body: 'Your gate pass for Apollo Clinic, Vandalur has been approved. '
          'Show the QR at the main gate.',
      category: NotificationCategory.security,
      receivedAt: DateTime.now().subtract(const Duration(hours: 4)),
      actionRoute: '/gate-pass',
    ),
    AppNotification(
      id: 'nt_2',
      title: 'Exam time table published',
      body: 'Semester 5 End Semester examination time table is now live.',
      category: NotificationCategory.academic,
      receivedAt: DateTime.now().subtract(const Duration(hours: 7)),
      actionRoute: '/examinations',
    ),
    AppNotification(
      id: 'nt_3',
      title: 'Hackathon registration closing soon',
      body: 'Only 24 seats left for the AVIT Cybersecurity Hackathon.',
      category: NotificationCategory.events,
      receivedAt: DateTime.now().subtract(const Duration(days: 1)),
      actionRoute: '/activities',
    ),
    AppNotification(
      id: 'nt_4',
      title: 'Bus Route 7 detour',
      body: 'Route 7 will operate via Rajiv Gandhi Salai until further notice.',
      category: NotificationCategory.transport,
      receivedAt: DateTime.now().subtract(const Duration(days: 2)),
      actionRoute: '/transport',
    ),
    AppNotification(
      id: 'nt_5',
      title: 'Hostel water maintenance',
      body: 'Block B water supply interrupted Thursday 10 AM - 2 PM.',
      category: NotificationCategory.hostel,
      receivedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AppNotification(
      id: 'nt_6',
      title: 'Password changed',
      body: 'Your AVIT Campus+ password was changed. If this was not you, '
          'contact the IT helpdesk immediately.',
      category: NotificationCategory.system,
      receivedAt: DateTime.now().subtract(const Duration(days: 3)),
      actionRoute: '/settings',
    ),
  ];

  // ------------------------------------------------------------ security
  static List<GateMovement> movements() {
    final DateTime now = DateTime.now();
    return <GateMovement>[
      GateMovement(
        id: 'gm_1',
        personName: 'Arun Kumar',
        personId: 'AVIT2026CS001',
        type: 'exit',
        time: now.subtract(const Duration(minutes: 12)),
      ),
      GateMovement(
        id: 'gm_2',
        personName: 'Vendor — Fresh Basket',
        personId: 'VND-2291',
        type: 'entry',
        time: now.subtract(const Duration(minutes: 26)),
        method: 'Manual',
        vehicleNumber: 'TN 11 BZ 4410',
      ),
      GateMovement(
        id: 'gm_3',
        personName: 'Priya Raghavan',
        personId: 'AVIT2026EC014',
        type: 'entry',
        time: now.subtract(const Duration(minutes: 44)),
      ),
      GateMovement(
        id: 'gm_4',
        personName: 'Karthik Subramani',
        personId: 'AVIT2026ME009',
        type: 'exit',
        time: now.subtract(const Duration(minutes: 61)),
        vehicleNumber: 'TN 09 CD 8890',
      ),
      GateMovement(
        id: 'gm_5',
        personName: 'Staff — Nandini Catering',
        personId: 'STF-114',
        type: 'entry',
        time: now.subtract(const Duration(hours: 2)),
        method: 'Manual',
      ),
    ];
  }

  static List<VehicleRecord> vehicles() => const <VehicleRecord>[
    VehicleRecord(number: 'TN 09 AB 4521', owner: 'Transport Dept', type: 'Bus'),
    VehicleRecord(number: 'TN 11 BZ 4410', owner: 'Fresh Basket', type: 'Delivery Van'),
    VehicleRecord(number: 'TN 09 CD 8890', owner: 'Karthik Subramani', type: 'Two Wheeler'),
    VehicleRecord(number: 'TN 07 EF 1123', owner: 'Not registered', type: 'Car', verified: false),
  ];

  static List<IncidentReport> incidents() => <IncidentReport>[
    IncidentReport(
      id: 'inc_1',
      title: 'Unattended bag near parking',
      description: 'Black backpack left unattended beside the two-wheeler bay. '
          'Checked with nearby students, no owner found.',
      severity: 'medium',
      location: 'Parking Bay',
      reportedBy: 'Ravi Shankar',
      reportedAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'Resolved',
    ),
    IncidentReport(
      id: 'inc_2',
      title: 'Ragging complaint — Block B corridor',
      description: 'Senior students obstructing a first-year student. '
          'Counselor informed.',
      severity: 'high',
      location: 'Boys Hostel Block B',
      reportedBy: 'Deepa Menon',
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: 'In progress',
    ),
  ];

  // ------------------------------------------------------ helper functions
  static DateTime _nextDate(int daysAhead, int hour, int minute) {
    final DateTime base = DateTime.now().add(Duration(days: daysAhead));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }
}

/// Development-only credentials. Never ship these in a production build —
/// see `README.md` § Demo mode.
abstract final class DemoCredentials {
  static const String password = 'Avit@2026Demo';
  static const Map<String, String> byEmail = <String, String>{
    'student@avit.ac.in': password,
    'security@avit.ac.in': password,
    'warden@avit.ac.in': password,
    'admin@avit.ac.in': password,
  };
}
