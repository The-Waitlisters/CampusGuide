import 'dart:js_interop';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'transport_mode_strategy.dart';

/// Calls the `window.getRoute` JavaScript helper defined in `web/index.html`.
@JS('getRoute')
external void _jsGetRoute(
  JSNumber lat1,
  JSNumber lng1,
  JSNumber lat2,
  JSNumber lng2,
  JSString travelMode,
  JSFunction callback,
);

/// Directions client for Flutter Web.
///
/// Delegates to the `window.getRoute` JavaScript helper defined in
/// `web/index.html`, which calls `google.maps.DirectionsService` from the
/// already-loaded Maps JS SDK.  This avoids the CORS restrictions that block
/// direct calls to the REST Directions API (`maps.googleapis.com/…/directions`)
/// from a browser.
class WebDirectionsClient implements DirectionsClient {
  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) {
    assert(
      mode.modeParam != kModeShuttle,
      'Shuttle routes must go through ShuttleRouteBuilder.',
    );

    final completer = Completer<RouteResult>();

    _jsGetRoute(
      origin.latitude.toJS,
      origin.longitude.toJS,
      destination.latitude.toJS,
      destination.longitude.toJS,
      _jsTravelMode(mode.modeParam).toJS,
      ((JSString jsonStr) {
        try {
          final data = json.decode(jsonStr.toDart) as Map<String, dynamic>;
          final polylineRaw = data['overview_polyline'];
          debugPrint('[WebDirectionsClient] overview_polyline '
              'type=${polylineRaw?.runtimeType} '
              'value=${polylineRaw?.toString().substring(0, polylineRaw.toString().length.clamp(0, 80))}');
          if (data.containsKey('error')) {
            completer.completeError(
              Exception('Directions error: ${data['error']}'),
            );
          } else {
            completer.complete(_parseResult(data, mode.modeParam));
          }
        } catch (e, st) {
          completer.completeError(e, st);
        }
      }).toJS,
    );

    return completer.future;
  }

  // ---- helpers ---------------------------------------------------------------

  static String _jsTravelMode(String modeParam) {
    switch (modeParam) {
      case kModeBicycling: return 'BICYCLING';
      case kModeDriving:   return 'DRIVING';
      case kModeTransit:   return 'TRANSIT';
      case kModeWalking:
      default:             return 'WALKING';
    }
  }

  static RouteResult _parseResult(Map<String, dynamic> data, String modeParam) {
    final durationText  = (data['duration_text']  as String?) ?? '';
    final distanceText  = (data['distance_text']  as String?) ?? '';
    final durationValue = (data['duration_value'] as num?)?.toInt() ?? 0;

    if (modeParam == kModeTransit) {
      final steps = (data['steps'] as List).cast<Map<String, dynamic>>();
      return RouteResult(
        legs:         steps.map(_stepToLeg).toList(),
        durationText: durationText,
        distanceText: distanceText,
      );
    }

    final encoded = (data['overview_polyline'] as String?) ?? '';
    return RouteResult(
      legs: [
        RouteLeg(
          polylinePoints:  decodePolyline(encoded),
          legMode:         _toLegMode(modeParam),
          durationSeconds: durationValue,
          durationText:    durationText,
          distanceText:    distanceText,
        ),
      ],
      durationText: durationText,
      distanceText: distanceText,
    );
  }

  static RouteLeg _stepToLeg(Map<String, dynamic> step) {
    final travelMode = (step['travel_mode'] as String?)?.toUpperCase() ?? 'WALKING';
    final legMode    = travelMode == 'TRANSIT' ? LegMode.transit : LegMode.walking;
    final durText    = (step['duration_text']  as String?) ?? '';
    final durSec     = (step['duration_value'] as num?)?.toInt() ?? 0;
    final distTxt    = (step['distance_text']  as String?) ?? '';
    final encoded    = (step['polyline']       as String?) ?? '';

    Color?  transitColor;
    String? lineName;
    if (legMode == LegMode.transit) {
      final hexColor = step['transit_color'] as String?;
      if (hexColor != null) transitColor = _hexColor(hexColor);
      lineName = step['line_name'] as String?;
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

  static LegMode _toLegMode(String p) {
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
