import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:proj/models/campus.dart';

import 'package:proj/services/directions/directions_controller.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';

/// ------------------------------
/// Fakes / Helpers
/// ------------------------------

class FakeDirectionsClient implements DirectionsClient {
  FakeDirectionsClient.success(this.result)
      : shouldThrow = false,
        throwValue = null;

  FakeDirectionsClient.throwing([Object? error])
      : shouldThrow = true,
        throwValue = error ?? Exception('boom'),
        result = null;

  final bool shouldThrow;
  final Object? throwValue;
  final RouteResult? result;

  int calls = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;
  TransportModeStrategy? lastMode;

  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    calls++;
    lastOrigin = origin;
    lastDestination = destination;
    lastMode = mode;

    if (shouldThrow) {
      throw throwValue!;
    }
    return result!;
  }
}

/// A tiny http.Client fake (no extra deps).
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.Request req) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final resp = await _handler(req);
    return http.StreamedResponse(
      Stream<Uint8List>.value(Uint8List.fromList(resp.bodyBytes)),
      resp.statusCode,
      headers: resp.headers,
      reasonPhrase: resp.reasonPhrase,
      request: request,
    );
  }
}

bool _almostEqual(double a, double b, {double eps = 1e-6}) => (a - b).abs() < eps;

void main() {
  group('TransportModeStrategy', () {
    test('modeParam strings match Google Directions expected values', () {
      expect(WalkStrategy().modeParam, 'walking');
      expect(BikeStrategy().modeParam, 'bicycling');
      expect(DriveStrategy().modeParam, 'driving');
      expect(MetroStrategy().modeParam, 'transit');
      expect(ShuttleStrategy().modeParam, 'shuttle');
    });
  });
  group('strategyForModeParam', () {

    test('returns WalkStrategy for walking', () {
      final strategy = strategyForModeParam(kModeWalking);
      expect(strategy, isA<WalkStrategy>());
    });

    test('returns BikeStrategy for bicycling', () {
      final strategy = strategyForModeParam(kModeBicycling);
      expect(strategy, isA<BikeStrategy>());
    });

    test('returns DriveStrategy for driving', () {
      final strategy = strategyForModeParam(kModeDriving);
      expect(strategy, isA<DriveStrategy>());
    });

    test('returns MetroStrategy for transit', () {
      final strategy = strategyForModeParam(kModeTransit);
      expect(strategy, isA<MetroStrategy>());
    });

    test('returns ShuttleStrategy for shuttle', () {
      final strategy = strategyForModeParam(kModeShuttle);
      expect(strategy, isA<ShuttleStrategy>());
    });

    test('defaults to WalkStrategy for unknown mode', () {
      final strategy = strategyForModeParam('unknown');
      expect(strategy, isA<WalkStrategy>());
    });

  });
  group('decodePolyline', () {
    test('decodes a known Google encoded polyline sample', () {
      // Official sample polyline used in many docs/examples.
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final pts = decodePolyline(encoded);

      expect(pts.length, 3);

      // Expected:
      // (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      expect(_almostEqual(pts[0].latitude, 38.5), isTrue);
      expect(_almostEqual(pts[0].longitude, -120.2), isTrue);

      expect(_almostEqual(pts[1].latitude, 40.7), isTrue);
      expect(_almostEqual(pts[1].longitude, -120.95), isTrue);

      expect(_almostEqual(pts[2].latitude, 43.252), isTrue);
      expect(_almostEqual(pts[2].longitude, -126.453), isTrue);
    });
  });

  group('GoogleDirectionsClient', () {
    test('builds correct URI + parses OK response + returns RouteResult', () async {
      final fakeHttp = FakeHttpClient((req) async {
        // Validate request URI and query params.
        expect(req.url.host, 'maps.googleapis.com');
        expect(req.url.path, '/maps/api/directions/json');

        final qp = req.url.queryParameters;
        expect(qp['origin'], '1.0,2.0');
        expect(qp['destination'], '3.0,4.0');
        expect(qp['mode'], 'walking');
        expect(qp['key'], 'TEST_KEY');

        // Minimal OK body with required fields.
        final body = jsonEncode({
          "status": "OK",
          "routes": [
            {
              "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
              "legs": [
                {
                  "duration": {"text": "12 min"},
                  "distance": {"text": "0.9 km"}
                }
              ]
            }
          ]
        });

        return http.Response(body, 200, headers: {'content-type': 'application/json'});
      });

      final client = GoogleDirectionsClient(
        apiKey: 'TEST_KEY',
        httpClient: fakeHttp,
      );

      final res = await client.getRoute(
        origin: const LatLng(1.0, 2.0),
        destination: const LatLng(3.0, 4.0),
        mode: WalkStrategy(),
      );

      expect(res.durationText, '12 min');
      expect(res.distanceText, '0.9 km');
      expect(res.polylinePoints.length, 3); // from decoded sample
    });

    test('throws when HTTP status != 200', () async {
      final fakeHttp = FakeHttpClient((req) async {
        return http.Response('nope', 500);
      });

      final client = GoogleDirectionsClient(
        apiKey: 'TEST_KEY',
        httpClient: fakeHttp,
      );

      expect(
            () => client.getRoute(
          origin: const LatLng(1, 1),
          destination: const LatLng(2, 2),
          mode: DriveStrategy(),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when JSON status != OK (uses error_message if present)', () async {
      final fakeHttp = FakeHttpClient((req) async {
        final body = jsonEncode({
          "status": "REQUEST_DENIED",
          "error_message": "The provided API key is invalid."
        });
        return http.Response(body, 200);
      });

      final client = GoogleDirectionsClient(
        apiKey: 'BAD_KEY',
        httpClient: fakeHttp,
      );

      try {
        await client.getRoute(
          origin: const LatLng(1, 1),
          destination: const LatLng(2, 2),
          mode: MetroStrategy(),
        );
        fail('Expected an exception');
      } catch (e) {
        expect(e.toString(), contains('Directions error'));
        expect(e.toString(), contains('invalid'));
      }
    });

    test('throws when JSON status != OK (falls back to status)', () async {
      final fakeHttp = FakeHttpClient((req) async {
        final body = jsonEncode({
          "status": "ZERO_RESULTS",
        });
        return http.Response(body, 200);
      });

      final client = GoogleDirectionsClient(
        apiKey: 'TEST_KEY',
        httpClient: fakeHttp,
      );

      expect(
            () => client.getRoute(
          origin: const LatLng(1, 1),
          destination: const LatLng(2, 2),
          mode: BikeStrategy(),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DirectionsController', () {
    test('defaults to WalkStrategy and initial state is empty', () {
      final c = DirectionsController(
        client: FakeDirectionsClient.success(
          const RouteResult(
            legs: [RouteLeg(polylinePoints: [LatLng(1, 1), LatLng(2, 2)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
            durationText: 'x',
            distanceText: 'y',
          ),
        ),
      );

      expect(c.mode, isA<WalkStrategy>());
      expect(c.state.isLoading, isFalse);
      expect(c.state.errorMessage, isNull);
      expect(c.state.polyline, isNull);
      expect(c.state.durationText, isNull);
      expect(c.state.distanceText, isNull);
    });

    test('setMode updates mode + notifies', () {
      final c = DirectionsController(
        client: FakeDirectionsClient.success(
          const RouteResult(
            legs: [RouteLeg(polylinePoints: [LatLng(1, 1), LatLng(2, 2)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
            durationText: 'x',
            distanceText: 'y',
          ),
        ),
      );

      var notified = 0;
      c.addListener(() => notified++);

      c.setMode(DriveStrategy());

      expect(c.mode, isA<DriveStrategy>());
      expect(notified, 1);
    });

    test('updateRoute resets if start or end is null and does not call client', () async {
      final fake = FakeDirectionsClient.success(
        const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(1, 1), LatLng(2, 2)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
          durationText: 'x',
          distanceText: 'y',
        ),
      );

      final c = DirectionsController(client: fake);

      await c.updateRoute(start: null, end: const LatLng(1, 1));
      expect(c.state.polyline, isNull);
      expect(fake.calls, 0);

      await c.updateRoute(start: const LatLng(1, 1), end: null);
      expect(c.state.polyline, isNull);
      expect(fake.calls, 0);
    });

    test('updateRoute success: sets loading then polyline/duration/distance', () async {
      final fake = FakeDirectionsClient.success(
        const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(10, 10), LatLng(20, 20)], legMode: LegMode.walking, durationSeconds: 0, durationText: '5 mins', distanceText: '1.2 km')],
          durationText: '5 mins',
          distanceText: '1.2 km',
        ),
      );

      final c = DirectionsController(client: fake);

      final events = <DirectionsViewState>[];
      c.addListener(() => events.add(c.state));

      const start = LatLng(1, 2);
      const end = LatLng(3, 4);

      await c.updateRoute(start: start, end: end);

      expect(fake.calls, 1);
      expect(fake.lastOrigin, start);
      expect(fake.lastDestination, end);
      expect(fake.lastMode, isA<WalkStrategy>()); // default mode

      expect(events.first.isLoading, isTrue);

      expect(c.state.isLoading, isFalse);
      expect(c.state.errorMessage, isNull);
      expect(c.state.durationText, '5 mins');
      expect(c.state.distanceText, '1.2 km');

      final poly = c.state.polyline;
      expect(poly, isNotNull);
      expect(poly!.polylineId.value, 'route_leg_0');
      expect(poly.points, const [LatLng(10, 10), LatLng(20, 20)]);
      expect(poly.width, 5);
    });

    test('updateRoute error: sets errorMessage and clears route', () async {
      final fake = FakeDirectionsClient.throwing(Exception('network down'));

      final c = DirectionsController(client: fake);

      final events = <DirectionsViewState>[];
      c.addListener(() => events.add(c.state));

      await c.updateRoute(start: const LatLng(1, 1), end: const LatLng(2, 2));

      expect(events.first.isLoading, isTrue);

      expect(c.state.isLoading, isFalse);
      expect(c.state.polyline, isNull);
      expect(c.state.durationText, isNull);
      expect(c.state.distanceText, isNull);
      expect(c.state.errorMessage, contains('network down'));
    });

    test('keeps old polyline while loading (covers polyline: _state.polyline line)', () async {
      // First call returns immediately -> sets an initial polyline.
      final c = DirectionsController(
        client: FakeDirectionsClient.success(
          const RouteResult(
            legs: [RouteLeg(polylinePoints: [LatLng(0, 0), LatLng(1, 1)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'A', distanceText: 'A')],
            durationText: 'A',
            distanceText: 'A',
          ),
        ),
      );

      await c.updateRoute(start: const LatLng(1, 1), end: const LatLng(2, 2));
      final old = c.state.polyline;
      expect(old, isNotNull);

      // Second call will complete later; during loading we should keep old polyline.
      final completer = Completer<RouteResult>();
      final delayedClient = _CompleterDirectionsClient(completer);

      final c2 = DirectionsController(client: delayedClient);

      // Seed c2 with an existing polyline first.
      await c2.updateRoute(
        start: const LatLng(1, 1),
        end: const LatLng(2, 2),
      );
      final seededOld = c2.state.polyline;
      expect(seededOld, isNotNull);

      final states = <DirectionsViewState>[];
      c2.addListener(() => states.add(c2.state));

      // Start loading (don’t await yet)
      final future = c2.updateRoute(
        start: const LatLng(3, 3),
        end: const LatLng(4, 4),
      );

      // Let listener run
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final loading = states.firstWhere(
            (s) => s.isLoading,
        orElse: () => c2.state,
      );

      expect(loading.isLoading, isTrue);
      expect(loading.polyline, seededOld); // the line we wanted to cover

      completer.complete(const RouteResult(
        legs: [RouteLeg(polylinePoints: [LatLng(9, 9), LatLng(8, 8)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'B', distanceText: 'B')],
        durationText: 'B',
        distanceText: 'B',
      ));

      await future;
      expect(c2.state.isLoading, isFalse);
      expect(c2.state.polyline!.points, const [LatLng(9, 9), LatLng(8, 8)]);
    });
    test('Shuttle mode shows placeholder and does not call API', () async {
      final fake = FakeDirectionsClient.success(
        const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(1,1)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
          durationText: 'x',
          distanceText: 'y',
        ),
      );

      final c = DirectionsController(client: fake);

      c.setMode(ShuttleStrategy());

      await c.updateRoute(
        start: const LatLng(1,1),
        end: const LatLng(2,2),
      );

      expect(fake.calls, 0); // API not called
      expect(c.state.placeholderMessage, isNotNull);
      expect(c.state.polyline, isNull);
    });
    test('Shuttle mode shows same-campus message', () async {
      final fake = FakeDirectionsClient.success(
        const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(1,1)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
          durationText: 'x',
          distanceText: 'y',
        ),
      );

      final c = DirectionsController(client: fake);

      c.setMode(ShuttleStrategy());

      await c.updateRoute(
        start: const LatLng(1,1),
        end: const LatLng(2,2),
        startCampus: Campus.sgw,
        endCampus: Campus.sgw,
      );

      expect(
        c.state.placeholderMessage,
        'Shuttle is only available for cross-campus travel (SGW ↔ Loyola)',
      );
    });
    test('Shuttle mode builds real route for cross-campus travel', () async {
      final fake = FakeDirectionsClient.success(
        const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(1,1)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'x', distanceText: 'y')],
          durationText: 'x',
          distanceText: 'y',
        ),
      );

      final c = DirectionsController(client: fake);

      c.setMode(ShuttleStrategy());

      final campusA = Campus.sgw;
      final campusB = Campus.loyola;

      await c.updateRoute(
        start: const LatLng(1,1),
        end: const LatLng(2,2),
        startCampus: campusA,
        endCampus: campusB,
      );

      expect(c.state.placeholderMessage, isNull);
      expect(c.state.polylines, isNotEmpty);
      expect(c.state.errorMessage, isNull);
    });
  });
}

class _CompleterDirectionsClient implements DirectionsClient {
  _CompleterDirectionsClient(this._next);

  final Completer<RouteResult> _next;

  bool _seeded = false;

  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) async {
    // First call: return a quick seed route so controller has an old polyline.
    if (!_seeded) {
      _seeded = true;
      return const RouteResult(
        legs: [RouteLeg(polylinePoints: [LatLng(5, 5), LatLng(6, 6)], legMode: LegMode.walking, durationSeconds: 0, durationText: 'seed', distanceText: 'seed')],
        durationText: 'seed',
        distanceText: 'seed',
      );
    }

    // Second call: wait on completer.
    return _next.future;
  }
}