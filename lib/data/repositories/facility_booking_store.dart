import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/facility_booking.dart';

/// Persistence for confirmed facility bookings.
///
/// The booking lab demo held bookings in memory only, but the admin
/// operations inbox must show every booking — including ones made before
/// the app was reloaded — so confirmed bookings are mirrored into
/// shared_preferences and restored on the next session.
abstract class BookingPersistence {
  /// Restored bookings (in confirmation order), or null when nothing was
  /// saved yet.
  Future<List<Booking>?> read();

  /// Replaces the persisted booking list.
  Future<void> write(List<Booking> bookings);
}

/// [BookingPersistence] backed by SharedPreferences.
class PrefsBookingPersistence implements BookingPersistence {
  PrefsBookingPersistence(this._prefs);

  static const String storageKey = 'avit.facility.bookings';

  final SharedPreferences _prefs;

  /// Opens the preference store, or returns null when the platform channel
  /// is unavailable (widget tests) so callers fall back to memory.
  static Future<PrefsBookingPersistence?> tryCreate() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      return PrefsBookingPersistence(prefs);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Booking>?> read() async {
    final String? raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return null;
      return <Booking>[
        for (final Object? item in decoded)
          if (item is Map<Object?, Object?>) _bookingFrom(item),
      ];
    } catch (_) {
      return null;
    }
  }

  Booking _bookingFrom(Map<Object?, Object?> item) {
    String value(Object? key) {
      final Object? v = item[key];
      return v == null ? '' : '$v';
    }

    return Booking(
      facilityId: value('facilityId'),
      purpose: value('purpose'),
      start: DateTime.tryParse(value('start')) ?? DateTime(2026),
      end: DateTime.tryParse(value('end')) ?? DateTime(2026),
      studentName: value('studentName'),
      studentId: value('studentId'),
    );
  }

  @override
  Future<void> write(List<Booking> bookings) async {
    try {
      await _prefs.setString(
        storageKey,
        jsonEncode(<Map<String, String>>[
          for (final Booking b in bookings)
            <String, String>{
              'facilityId': b.facilityId,
              'purpose': b.purpose,
              'start': b.start.toIso8601String(),
              'end': b.end.toIso8601String(),
              'studentName': b.studentName,
              'studentId': b.studentId,
            },
        ]),
      );
    } catch (_) {
      // Losing a demo write must never break the booking flow.
    }
  }
}

/// Resolves SharedPreferences once, lazily and failure-safe: every call
/// degrades to a no-op when the platform channel is missing, so bookings
/// simply stay in memory.
class LazyPrefsBookingPersistence implements BookingPersistence {
  LazyPrefsBookingPersistence() : _future = PrefsBookingPersistence.tryCreate();

  final Future<PrefsBookingPersistence?> _future;

  @override
  Future<List<Booking>?> read() async => (await _future)?.read();

  @override
  Future<void> write(List<Booking> bookings) async =>
      (await _future)?.write(bookings);
}
