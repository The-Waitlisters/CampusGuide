import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';

// ---------------------------------------------------------------------------
// ShuttleStop
// ---------------------------------------------------------------------------

class ShuttleStop {
  const ShuttleStop({
    required this.campus,
    required this.location,
    required this.name,
  });

  final Campus campus;
  final LatLng location;
  final String name;
}

// ---------------------------------------------------------------------------
// ShuttleScheduleData
//
// Static data for the Concordia inter-campus shuttle service.
// Source: https://www.concordia.ca/maps/shuttle-bus.html
//
// Stops
// ─────
// SGW    — Bishop St entrance, Hall Building area
// Loyola — near Loyola Jesuit Hall & Conference Centre
//
// Timetable (academic year, weekdays)
// ────────────────────────────────────
// Departures from SGW    : :00 and :30 every hour  (07:00 – 23:00)
// Departures from Loyola : :15 and :45 every hour  (07:15 – 23:15)
// One-way ride time      : ~30 minutes
// ---------------------------------------------------------------------------

abstract final class ShuttleScheduleData {
  // ---- Stop coordinates ---------------------------------------------------

  static const ShuttleStop sgwStop = ShuttleStop(
    campus:   Campus.sgw,
    location: LatLng(45.4965, -73.5793),
    name:     'SGW Shuttle Stop (Hall Building)',
  );

  static const ShuttleStop loyolaStop = ShuttleStop(
    campus:   Campus.loyola,
    location: LatLng(45.4584, -73.6391),
    name:     'Loyola Shuttle Stop',
  );

  // ---- Timetable ----------------------------------------------------------

  /// Minutes past the hour at which the shuttle departs from SGW.
  static const List<int> sgwDepartureMinutes = [0, 30];

  /// Minutes past the hour at which the shuttle departs from Loyola.
  static const List<int> loyolaDepartureMinutes = [15, 45];

  /// Approximate one-way ride duration (minutes).
  static const int rideDurationMinutes = 30;

  /// First hour of service (inclusive). Shuttle starts at 07:00.
  static const int serviceStartHour = 7;

  /// Last hour of service (exclusive). Last departure ~23:00.
  static const int serviceEndHour = 23;

  // ---- Convenience --------------------------------------------------------

  /// Returns the stop for the given [campus].
  static ShuttleStop stopForCampus(Campus campus) =>
      campus == Campus.sgw ? sgwStop : loyolaStop;

  /// Returns departure minutes for the given [campus].
  static List<int> departureMinutesForCampus(Campus campus) =>
      campus == Campus.sgw ? sgwDepartureMinutes : loyolaDepartureMinutes;

  /// Whether the shuttle is currently in service at the given [time].
  static bool isInService(DateTime time) =>
      time.hour >= serviceStartHour && time.hour < serviceEndHour;

  /// Minutes until the next departure from [campus] at [now].
  /// Returns 60 when outside service hours (conservative upper bound).
  static int minutesUntilNextDeparture({
    required Campus campus,
    required DateTime now,
  }) {
    if (!isInService(now)) return 60;

    for (final dep in departureMinutesForCampus(campus)) {
      if (now.minute < dep) return dep - now.minute;
    }

    // All departures this hour passed — next is the first one next hour.
    return (60 - now.minute) + departureMinutesForCampus(campus).first;
  }
}