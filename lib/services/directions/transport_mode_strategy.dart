import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// LegMode
// ---------------------------------------------------------------------------

enum LegMode { walking, cycling, driving, transit, shuttle }

// ---------------------------------------------------------------------------
// RouteLeg — one segment of a multi-modal route
// ---------------------------------------------------------------------------

@immutable
class RouteLeg {
  const RouteLeg({
    required this.polylinePoints,
    required this.legMode,
    required this.durationSeconds,
    required this.durationText,
    required this.distanceText,
    this.transitColor,
    this.lineName,
  });

  final List<LatLng> polylinePoints;
  final LegMode legMode;
  final int durationSeconds;
  final String durationText;
  final String distanceText;
  final Color? transitColor;  // Transit brand color from Google API
  final String? lineName;     // e.g. "105", "Green Line"
}

// ---------------------------------------------------------------------------
// RouteResult
// ---------------------------------------------------------------------------

@immutable
class RouteResult {
  const RouteResult({
    required this.legs,
    required this.durationText,
    required this.distanceText,
  });

  final List<RouteLeg> legs;
  final String durationText;
  final String distanceText;

  List<LatLng> get polylinePoints =>
      legs.expand((l) => l.polylinePoints).toList();
}

// ---------------------------------------------------------------------------
// Mode param constants — single source of truth
// ---------------------------------------------------------------------------

const String kModeWalking   = 'walking';
const String kModeBicycling = 'bicycling';
const String kModeDriving   = 'driving';
const String kModeTransit   = 'transit';
const String kModeShuttle   = 'shuttle';

/// Ordered list used by the UI chip row.
const List<({String label, String modeParam})> kTransportModes = [
  (label: 'Walk',    modeParam: kModeWalking),
  (label: 'Bike',    modeParam: kModeBicycling),
  (label: 'Drive',   modeParam: kModeDriving),
  (label: 'Transit', modeParam: kModeTransit),
  (label: 'Shuttle', modeParam: kModeShuttle),
];

TransportModeStrategy strategyForModeParam(String modeParam) {
  switch (modeParam) {
    case kModeBicycling: return BikeStrategy();
    case kModeDriving:   return DriveStrategy();
    case kModeTransit:   return MetroStrategy();
    case kModeShuttle:   return ShuttleStrategy();
    case kModeWalking:
    default:             return WalkStrategy();
  }
}

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

abstract class TransportModeStrategy {
  String get modeParam;
}

class WalkStrategy    implements TransportModeStrategy { @override String get modeParam => kModeWalking;   }
class BikeStrategy    implements TransportModeStrategy { @override String get modeParam => kModeBicycling; }
class DriveStrategy   implements TransportModeStrategy { @override String get modeParam => kModeDriving;   }
class MetroStrategy   implements TransportModeStrategy { @override String get modeParam => kModeTransit;   }
class ShuttleStrategy implements TransportModeStrategy { @override String get modeParam => kModeShuttle;   }

// ---------------------------------------------------------------------------
// DirectionsClient
// ---------------------------------------------------------------------------

abstract class DirectionsClient {
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  });
}

// ---------------------------------------------------------------------------
// GoogleDirectionsClient
// ---------------------------------------------------------------------------

class GoogleDirectionsClient implements DirectionsClient {
  GoogleDirectionsClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    assert(mode.modeParam != kModeShuttle,
    'Shuttle routes must go through ShuttleRouteBuilder.');

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin':      '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode':        mode.modeParam,
        'key':         apiKey,
      },
    );

    final resp = await _http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Directions HTTP ${resp.statusCode}');
    }

    final body   = json.decode(resp.body) as Map<String, dynamic>;
    final status = (body['status'] ?? '') as String;
    if (status != 'OK') {
      throw Exception('Directions error: ${body['error_message'] ?? status}');
    }

    final routes = (body['routes'] as List).cast<Map<String, dynamic>>();
    final route0 = routes.first;
    final legs   = (route0['legs'] as List).cast<Map<String, dynamic>>();
    final leg0   = legs.first;

    final durationText = (leg0['duration'] as Map)['text'].toString();
    final distanceText = (leg0['distance'] as Map)['text'].toString();

    // Transit: parse each step as a separate leg (walk + vehicle legs).
    if (mode.modeParam == kModeTransit) {
      final steps = (leg0['steps'] as List).cast<Map<String, dynamic>>();
      return RouteResult(
        legs:         steps.map(_stepToLeg).toList(),
        durationText: durationText,
        distanceText: distanceText,
      );
    }

    // All other modes: single leg from the overview polyline.
    final durationSeconds =
        ((leg0['duration'] as Map)['value'] as num?)?.toInt() ?? 0;
    final encoded =
    (route0['overview_polyline'] as Map)['points'].toString();

    return RouteResult(
      legs: [
        RouteLeg(
          polylinePoints:  decodePolyline(encoded),
          legMode:         _modeToLegMode(mode.modeParam),
          durationSeconds: durationSeconds,
          durationText:    durationText,
          distanceText:    distanceText,
        ),
      ],
      durationText: durationText,
      distanceText: distanceText,
    );
  }

  // ---- helpers -------------------------------------------------------------

  static RouteLeg _stepToLeg(Map<String, dynamic> step) {
    final travelMode = (step['travel_mode'] as String?)?.toUpperCase() ?? 'WALKING';
    final legMode    = travelMode == 'TRANSIT' ? LegMode.transit : LegMode.walking;

    final dur     = step['duration'] as Map?;
    final durText = dur?['text']?.toString() ?? '';
    final durSec  = (dur?['value'] as num?)?.toInt() ?? 0;
    final distTxt = (step['distance'] as Map?)?['text']?.toString() ?? '';
    final encoded = (step['polyline'] as Map?)?['points']?.toString() ?? '';

    Color? transitColor;
    String? lineName;

    if (legMode == LegMode.transit) {
      final details = step['transit_details'] as Map<String, dynamic>?;
      final line    = details?['line'] as Map<String, dynamic>?;
      final hex     = line?['color'] as String?;
      if (hex != null) transitColor = _hexColor(hex);
      lineName = (line?['short_name'] ?? line?['name']) as String?;
    }

    return RouteLeg(
      polylinePoints:  decodePolyline(encoded),
      legMode:         legMode,
      durationSeconds: durSec,
      durationText:    durText,
      distanceText:    distTxt,
      transitColor:    transitColor,
      lineName:        lineName,
    );
  }

  static LegMode _modeToLegMode(String p) {
    switch (p) {
      case kModeBicycling: return LegMode.cycling;
      case kModeDriving:   return LegMode.driving;
      case kModeTransit:   return LegMode.transit;
      default:             return LegMode.walking;
    }
  }

  static Color _hexColor(String hex) {
    final c = hex.replaceAll('#', '');
    if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    return const Color(0xFF1A73E8);
  }
}

// ---------------------------------------------------------------------------
// Polyline decoder
// ---------------------------------------------------------------------------

List<LatLng> decodePolyline(String encoded) {
  final pts = <LatLng>[];
  int i = 0, lat = 0, lng = 0;
  while (i < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0; result = 0;
    do {
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    pts.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return pts;
}