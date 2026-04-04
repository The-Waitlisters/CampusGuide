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
// Timetable (academic year, weekdays only)
// ─────────────────────────────────────────
// All times below are encoded as minutes since midnight (h*60 + m).
// Departures run Monday–Friday only; no weekend service.
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

  /// SGW departures, Monday–Thursday (minutes since midnight).
  static const List<int> _sgwMonThu = [
    570,  // 09:30
    585,  // 09:45
    600,  // 10:00
    615,  // 10:15
    630,  // 10:30
    645,  // 10:45
    660,  // 11:00
    675,  // 11:15
    690,  // 11:30
    // 11:45 skipped
    // 12:00 skipped
    735,  // 12:15
    750,  // 12:30
    765,  // 12:45
    780,  // 13:00
    795,  // 13:15
    810,  // 13:30
    825,  // 13:45
    840,  // 14:00
    855,  // 14:15
    870,  // 14:30
    885,  // 14:45
    900,  // 15:00
    915,  // 15:15
    930,  // 15:30
    // 15:45 skipped
    960,  // 16:00
    975,  // 16:15
    // 16:30 skipped
    1005, // 16:45
    1020, // 17:00
    1035, // 17:15
    1050, // 17:30
    1065, // 17:45
    1080, // 18:00
    1095, // 18:15
    1110, // 18:30
  ];

  /// SGW departures, Friday (minutes since midnight).
  static const List<int> _sgwFriday = [
    585,  // 09:45
    600,  // 10:00
    615,  // 10:15
    // 10:30 skipped
    645,  // 10:45
    // 11:00 skipped
    675,  // 11:15
    690,  // 11:30
    // 11:45 skipped
    // 12:00 skipped
    735,  // 12:15
    750,  // 12:30
    765,  // 12:45
    // 13:00 skipped
    795,  // 13:15
    // 13:30 skipped
    825,  // 13:45
    840,  // 14:00
    855,  // 14:15
    // 14:30 skipped
    885,  // 14:45
    900,  // 15:00
    915,  // 15:15
    // 15:30 skipped
    945,  // 15:45
    960,  // 16:00
    // 16:15 skipped
    // 16:30 skipped
    1005, // 16:45
    // 17:00 skipped
    1035, // 17:15
    // 17:30 skipped
    1065, // 17:45
    // 18:00 skipped
    1095, // 18:15
  ];

  /// Loyola departures, Monday–Thursday (minutes since midnight).
  static const List<int> _loyMonThu = [
    555,  // 09:15
    570,  // 09:30
    585,  // 09:45
    600,  // 10:00
    615,  // 10:15
    630,  // 10:30
    645,  // 10:45
    660,  // 11:00
    675,  // 11:15
    690,  // 11:30
    705,  // 11:45
    // 12:00 skipped
    // 12:15 skipped
    750,  // 12:30
    765,  // 12:45
    780,  // 13:00
    795,  // 13:15
    810,  // 13:30
    825,  // 13:45
    840,  // 14:00
    855,  // 14:15
    870,  // 14:30
    885,  // 14:45
    900,  // 15:00
    915,  // 15:15
    930,  // 15:30
    945,  // 15:45
    // 16:00 skipped
    // 16:15 skipped
    990,  // 16:30
    1005, // 16:45
    1020, // 17:00
    1035, // 17:15
    1050, // 17:30
    1065, // 17:45
    1080, // 18:00
    1095, // 18:15
    1110, // 18:30
  ];

  /// Loyola departures, Friday (minutes since midnight).
  static const List<int> _loyFriday = [
    555,  // 09:15
    570,  // 09:30
    585,  // 09:45
    // 10:00 skipped
    615,  // 10:15
    // 10:30 skipped
    645,  // 10:45
    660,  // 11:00
    675,  // 11:15
    // 11:30 skipped
    // 11:45 skipped
    720,  // 12:00
    735,  // 12:15
    // 12:30 skipped
    765,  // 12:45
    780,  // 13:00
    795,  // 13:15
    // 13:30 skipped
    825,  // 13:45
    // 14:00 skipped
    855,  // 14:15
    870,  // 14:30
    885,  // 14:45
    // 15:00 skipped
    915,  // 15:15
    930,  // 15:30
    945,  // 15:45
    // 16:00 skipped
    // 16:15 skipped
    // 16:30 skipped
    1005, // 16:45
    // 17:00 skipped
    1035, // 17:15
    // 17:30 skipped
    1065, // 17:45
    // 18:00 skipped
    1095, // 18:15
  ];

  // ---- Ride duration ------------------------------------------------------

  /// Approximate one-way ride duration (minutes).
  static const int rideDurationMinutes = 30;

  // ---- Convenience --------------------------------------------------------

  /// Returns the stop for the given [campus].
  static ShuttleStop stopForCampus(Campus campus) =>
      campus == Campus.sgw ? sgwStop : loyolaStop;

  /// Returns the departure list for [campus] on the given [weekday]
  /// (1 = Monday … 7 = Sunday, matching [DateTime.weekday]).
  static List<int> departuresFor(Campus campus, int weekday) {
    if (weekday == DateTime.friday) {
      return campus == Campus.sgw ? _sgwFriday : _loyFriday;
    }
    return campus == Campus.sgw ? _sgwMonThu : _loyMonThu;
  }

  /// Whether the shuttle is currently in service at [time].
  /// Service runs Monday–Friday only.
  static bool isInService(DateTime time) {
    if (time.weekday == DateTime.saturday || time.weekday == DateTime.sunday) {
      return false;
    }
    final nowMinutes = time.hour * 60 + time.minute;
    final schedule = departuresFor(
      Campus.sgw, // use either campus just to check service bounds
      time.weekday,
    );
    return schedule.isNotEmpty &&
        nowMinutes <= schedule.last;
  }

  /// Minutes until the next scheduled departure from [campus] at [now].
  ///
  /// Returns 60 when outside service hours or on weekends as a conservative
  /// upper bound so callers always receive a usable estimate.
  static int minutesUntilNextDeparture({
    required Campus campus,
    required DateTime now,
  }) {
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return 60;
    }

    final departures = departuresFor(campus, now.weekday);
    final nowMinutes = now.hour * 60 + now.minute;

    for (final depMinutes in departures) {
      if (depMinutes > nowMinutes) {
        return depMinutes - nowMinutes;
      }
    }

    // Past the last departure for today.
    return 60;
  }
}
