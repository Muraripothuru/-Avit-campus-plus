import '../../models/announcement.dart';
import '../../models/app_notification.dart';
import '../../models/campus_event.dart';
import '../../models/pass.dart';
import '../../models/safety.dart';
import 'demo_catalog.dart';

/// Mutable, process-local state for offline/demo operation.
///
/// This is a *fallback* data source. When `API_BASE_URL` is supplied the
/// repositories talk to the REST API instead and this class is never used for
/// authoritative reads. Nothing here is persisted to disk, so no personal data
/// survives a restart on a shared device.
class LocalStore {
  LocalStore() {
    reset();
  }

  late List<GatePass> gatePasses;
  late List<VisitorPass> visitorPasses;
  late List<CampusEvent> events;
  late List<Club> clubs;
  late List<AppNotification> notifications;
  late List<Announcement> announcements;
  late List<Complaint> complaints;
  late List<EmergencyRequest> emergencies;
  late List<String> usedQrNonces;
  final Map<String, int> queueTokens = <String, int>{};

  void reset() {
    gatePasses = DemoCatalog.gatePasses();
    visitorPasses = DemoCatalog.visitorPasses();
    events = DemoCatalog.events();
    clubs = DemoCatalog.clubs();
    notifications = DemoCatalog.notifications();
    announcements = DemoCatalog.announcements();
    complaints = <Complaint>[
      Complaint(
        id: 'cmp_1',
        category: 'Hostel',
        subject: 'Mess food quality',
        description: 'Dal served undercooked three days in a row.',
        raisedBy: DemoCatalog.student.fullName,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: 'In progress',
        response: 'Hostel supervisor visiting the kitchen this week.',
        assignedTo: 'Hostel Office',
      ),
      Complaint(
        id: 'cmp_2',
        category: 'IT',
        subject: 'WiFi disconnects in AB-204',
        description: 'Drops every 10 minutes during lab sessions.',
        raisedBy: DemoCatalog.student.fullName,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        status: 'Resolved',
        response: 'Access point firmware updated and channel re-planned.',
        assignedTo: 'IT Helpdesk',
        rating: 5,
      ),
    ];
    emergencies = <EmergencyRequest>[];
    usedQrNonces = <String>[];
  }

  int get unreadNotifications =>
      notifications.where((AppNotification n) => !n.read).length;

  List<GatePass> gatePassesFor(String studentId) => gatePasses
      .where((GatePass p) => p.studentId == studentId)
      .toList();

  List<VisitorPass> visitorPassesFor(String studentId) => visitorPasses
      .where((VisitorPass p) => p.hostStudentId == studentId)
      .toList();

  int get pendingGatePasses =>
      gatePasses.where((GatePass p) => p.status == PassStatus.pending).length;

  int get pendingVisitorPasses =>
      visitorPasses.where((VisitorPass p) => p.status == PassStatus.pending).length;
}
