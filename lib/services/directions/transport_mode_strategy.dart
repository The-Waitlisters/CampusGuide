import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// What the UI needs after route generation
@immutable
class RouteResult {
  const RouteResult({
    required this.polylinePoints,
    required this.durationText,
    required this.distanceText,
  });

  final List<LatLng> polylinePoints;
  final String durationText; // e.g. "12 min"
  final String distanceText; // e.g. "0.9 km"
}

/// Strategy: each mode maps to a google directions mode string
abstract class TransportModeStrategy {
  String get modeParam; // e.g. driving, walking, bicycling, transit
}

class WalkStrategy implements TransportModeStrategy {
  @override
  String get modeParam => 'walking';
}

class BikeStrategy implements TransportModeStrategy {
  @override
  String get modeParam => 'bicycling';
}

class DriveStrategy implements TransportModeStrategy {
  @override
  String get modeParam => 'driving';
}

class MetroStrategy implements TransportModeStrategy {
  @override
  String get modeParam => 'transit';
}

/// Shuttle mode: campus shuttle routing (not yet implemented).
/// Does not call Directions API; shows placeholder in UI instead.
class ShuttleStrategy implements TransportModeStrategy {
  @override
  String get modeParam => 'shuttle';
}

/// Abstraction for testability & decoupling from Google API
abstract class DirectionsClient {
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  });
}

/// Concrete client using Google Directions API (REST).
/// NOTE: Don’t hardcode keys. Inject from secure config.
class GoogleDirectionsClient implements DirectionsClient {
  GoogleDirectionsClient({
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode.modeParam,
        'key': apiKey,
      },
    );

    final resp = await _http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Directions HTTP ${resp.statusCode}');
    }

    final jsonBody = json.decode(resp.body) as Map<String, dynamic>;
    final status = (jsonBody['status'] ?? '') as String;

    if (status != 'OK') {
      final msg = (jsonBody['error_message'] ?? status).toString();
      throw Exception('Directions error: $msg');
    }

    final routes = (jsonBody['routes'] as List).cast<Map<String, dynamic>>();
    final route0 = routes.first;

    final legs = (route0['legs'] as List).cast<Map<String, dynamic>>();
    final leg0 = legs.first;

    final durationText = (leg0['duration'] as Map)['text'].toString();
    final distanceText = (leg0['distance'] as Map)['text'].toString();

    final polyline = (route0['overview_polyline'] as Map)['points'].toString();
    final points = decodePolyline(polyline);

    return RouteResult(
      polylinePoints: points,
      durationText: durationText,
      distanceText: distanceText,
    );
  }
}

/// Google encoded polyline decoder
List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}