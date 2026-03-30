import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/shuttle_schedule.dart';
import '../models/campus.dart';
import 'directions/transport_mode_strategy.dart';

// Re-export so callers only need to import shuttle_service.dart.
export '../data/shuttle_schedule.dart' show ShuttleStop, ShuttleScheduleData;

// ---------------------------------------------------------------------------
// ShuttleEtaType
// ---------------------------------------------------------------------------

enum ShuttleEtaType {
  /// ETA sourced from a live shuttle API — show "Realtime" badge.
  realtime,

  /// ETA derived from the static schedule — show "Estimated" badge.
  estimated,
}

// ---------------------------------------------------------------------------
// ShuttleRouteResult
// ---------------------------------------------------------------------------

@immutable
class ShuttleRouteResult {
  const ShuttleRouteResult({
    required this.routeResult,
    required this.etaType,
    required this.waitMinutes,
  });

  final RouteResult    routeResult;
  final ShuttleEtaType etaType;
  final int            waitMinutes;
}

// ---------------------------------------------------------------------------
// ShuttleRouteBuilder
//
// Builds a complete 3-leg shuttle route:
//
//   Leg 1 — Walk    : origin → pickup stop         (Google Directions API)
//   Leg 2 — Shuttle : pickup → drop-off            (schedule-derived ETA)
//   Leg 3 — Walk    : drop-off → destination       (Google Directions API)
//
// Stop coordinates and timetable come from lib/data/shuttle_schedule.dart.
// The walking legs are fetched via the injected [DirectionsClient] so this
// builder is fully testable with a mock client.
// ---------------------------------------------------------------------------

class ShuttleRouteBuilder {
  const ShuttleRouteBuilder({required DirectionsClient client})
      : _client = client;

  final DirectionsClient _client;

  Future<ShuttleRouteResult> buildRoute({
    required LatLng origin,
    required LatLng destination,
    required Campus fromCampus,
    required Campus toCampus,
    DateTime? now, // injectable for testing
  }) async {
    if (fromCampus == toCampus) {
      throw ArgumentError(
          'Shuttle is only available for cross-campus travel (SGW ↔ Loyola).');
    }

    final pickupStop  = ShuttleScheduleData.stopForCampus(fromCampus);
    final dropoffStop = ShuttleScheduleData.stopForCampus(toCampus);

    final effectiveNow = now ?? DateTime.now();
    final waitMinutes  = ShuttleScheduleData.minutesUntilNextDeparture(
      campus: fromCampus,
      now:    effectiveNow,
    );

    // Always Estimated until Concordia provides a live shuttle API.
    // To add real-time: call the live endpoint here, compare against schedule,
    // and return ShuttleEtaType.realtime when data is fresh.
    const etaType = ShuttleEtaType.estimated;

    // -- Leg 1: walk to pickup stop ----------------------------------------
    final walkIn = await _client.getRoute(
      origin:      origin,
      destination: pickupStop.location,
      mode:        WalkStrategy(),
    );

    // -- Leg 2: shuttle ride (schedule-derived) ----------------------------
    final totalRideMin   = waitMinutes + ShuttleScheduleData.rideDurationMinutes;
    final durationString = waitMinutes > 0
        ? '~$totalRideMin min (~$waitMinutes min wait + '
        '${ShuttleScheduleData.rideDurationMinutes} min ride)'
        : '~${ShuttleScheduleData.rideDurationMinutes} min';

    final shuttleLeg = RouteLeg(
      polylinePoints:  [pickupStop.location, dropoffStop.location],
      legMode:         LegMode.shuttle,
      durationSeconds: totalRideMin * 60,
      durationText:    durationString,
      distanceText:    '≈ 7 km',
      transitColor:    const Color(0xFF912338), // Concordia burgundy
      lineName:        'Concordia Shuttle',
    );

    // -- Leg 3: walk from drop-off to destination -------------------------
    final walkOut = await _client.getRoute(
      origin:      dropoffStop.location,
      destination: destination,
      mode:        WalkStrategy(),
    );

    // -- Combine ----------------------------------------------------------
    final allLegs = [
      ...walkIn.legs,
      shuttleLeg,
      ...walkOut.legs,
    ];

    final totalSec  = allLegs.fold<int>(0, (s, l) => s + l.durationSeconds);
    final totalMin  = totalSec ~/ 60;
    final etaSuffix = etaType == ShuttleEtaType.realtime
        ? '(Realtime)'
        : '(Estimated)';

    return ShuttleRouteResult(
      routeResult: RouteResult(
        legs:         allLegs,
        durationText: '$totalMin min $etaSuffix',
        distanceText: walkIn.distanceText,
      ),
      etaType:     etaType,
      waitMinutes: waitMinutes,
    );
  }
}