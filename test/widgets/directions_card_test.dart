import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/models/room.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/services/shuttle_service.dart';
import 'package:proj/widgets/home/directions_card.dart';

CampusBuilding _hall() => CampusBuilding(
      name: 'H',
      fullName: 'Hall',
      campus: Campus.sgw,
      id: '',
      boundary: [],
      description: '',
    );

void main() {
  testWidgets('tapping transport mode calls onModeChanged', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (m) => selected = m,
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.pump();

    expect(selected, 'bicycling');
  });

  testWidgets('shows location required message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              locationRequiredMessage: 'Location permission needed',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Location permission needed'), findsOneWidget);
  });

  testWidgets('shows placeholder message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              placeholderMessage: 'Shuttle coming soon',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Shuttle coming soon'), findsOneWidget);
  });

  testWidgets('shows loading indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: true,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows duration and distance when route exists', (tester) async {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: const [LatLng(0, 0), LatLng(1, 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: polyline,
              durationText: '5 min',
              distanceText: '1 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('5 min · 1 km'), findsOneWidget);
  });

  testWidgets('uses startPoi name in start label when startBuilding is null',
      (tester) async {
    final startPoi = Poi(
      id: 'sp1',
      name: 'Nearby Cafe',
      campus: Campus.sgw,
      description: null,
      boundary: const LatLng(45.497, -73.578),
      openNow: true,
      openingHours: const [],
      photoName: const <String?>[],
      rating: 4.0,
      address: '1 Test St',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              startPoi: startPoi,
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('Nearby Cafe'), findsOneWidget);
  });

  testWidgets('uses endPoi name in end label when endBuilding is null',
      (tester) async {
    final endPoi = Poi(
      id: 'ep1',
      name: 'Central Park',
      campus: Campus.sgw,
      description: null,
      boundary: const LatLng(45.497, -73.578),
      openNow: true,
      openingHours: const [],
      photoName: const <String?>[],
      rating: 3.8,
      address: '2 Test St',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: _hall(),
              endBuilding: null,
              endPoi: endPoi,
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('Central Park'), findsOneWidget);
  });

  // ── Multi-leg breakdown ──────────────────────────────────────────────────────

  testWidgets('shows multi-leg step breakdown with walk and transit legs',
      (tester) async {
    const walkLeg = RouteLeg(
      polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
      legMode: LegMode.walking,
      durationSeconds: 300,
      durationText: '5 min',
      distanceText: '0.4 km',
    );
    const transitLeg = RouteLeg(
      polylinePoints: [LatLng(1, 1), LatLng(2, 2)],
      legMode: LegMode.transit,
      durationSeconds: 600,
      durationText: '10 min',
      distanceText: '3 km',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: '15 min',
              distanceText: '3.4 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'transit',
              onModeChanged: (_) {},
              legs: const [walkLeg, transitLeg],
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Walk'), findsAtLeastNWidgets(2));
    expect(find.text('Transit'), findsAtLeastNWidgets(2));
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('0.4 km'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('15 min · 3.4 km'), findsOneWidget);
  });

  testWidgets('shows lineName instead of mode label when leg has lineName',
      (tester) async {
    const legA = RouteLeg(
      polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
      legMode: LegMode.walking,
      durationSeconds: 120,
      durationText: '2 min',
      distanceText: '0.1 km',
    );
    const legB = RouteLeg(
      polylinePoints: [LatLng(1, 1), LatLng(2, 2)],
      legMode: LegMode.transit,
      durationSeconds: 300,
      durationText: '5 min',
      distanceText: '2 km',
      lineName: 'Green Line',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: '7 min',
              distanceText: '2.1 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'transit',
              onModeChanged: (_) {},
              legs: const [legA, legB],
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Green Line'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
  });

  testWidgets('hides distance separator when leg distanceText is empty',
      (tester) async {
    const legA = RouteLeg(
      polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
      legMode: LegMode.shuttle,
      durationSeconds: 1800,
      durationText: '30 min',
      distanceText: '',
    );
    const legB = RouteLeg(
      polylinePoints: [LatLng(1, 1), LatLng(2, 2)],
      legMode: LegMode.walking,
      durationSeconds: 300,
      durationText: '5 min',
      distanceText: '0.4 km',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: '35 min',
              distanceText: '0.4 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'shuttle',
              onModeChanged: (_) {},
              legs: const [legA, legB],
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Shuttle'), findsAtLeastNWidgets(2));
    expect(find.text(''), findsNothing);
  });

  testWidgets('retry button calls onRetry when route errors', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: 'Directions failed',
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () => retries++,
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('polyline shows duration only when distance null', (tester) async {
    final polyline = Polyline(
      polylineId: const PolylineId('r'),
      points: const [LatLng(0, 0), LatLng(1, 1)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: polyline,
              durationText: '2 min',
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    expect(find.text('2 min'), findsOneWidget);
  });

  // ── ETA badge ────────────────────────────────────────────────────────────────

  testWidgets('shows Realtime etaBadge in single-leg summary', (tester) async {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: const [LatLng(0, 0), LatLng(1, 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: polyline,
              durationText: '30 min',
              distanceText: '7 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'shuttle',
              onModeChanged: (_) {},
              etaType: ShuttleEtaType.realtime,
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Realtime'), findsOneWidget);
  });

  testWidgets('shows Estimated etaBadge in single-leg summary', (tester) async {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: const [LatLng(0, 0), LatLng(1, 1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: polyline,
              durationText: '30 min',
              distanceText: '7 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'shuttle',
              onModeChanged: (_) {},
              etaType: ShuttleEtaType.estimated,
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Estimated'), findsOneWidget);
  });

  testWidgets('shows etaBadge in multi-leg Total row', (tester) async {
    const legA = RouteLeg(
      polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
      legMode: LegMode.walking,
      durationSeconds: 300,
      durationText: '5 min',
      distanceText: '0.4 km',
    );
    const legB = RouteLeg(
      polylinePoints: [LatLng(1, 1), LatLng(2, 2)],
      legMode: LegMode.shuttle,
      durationSeconds: 1800,
      durationText: '30 min',
      distanceText: '7 km',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: '35 min',
              distanceText: '7.4 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'shuttle',
              onModeChanged: (_) {},
              legs: const [legA, legB],
              etaType: ShuttleEtaType.realtime,
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Realtime'), findsOneWidget);
  });

  testWidgets('covers remaining leg mode icons and colors', (tester) async {
    const legA = RouteLeg(
      polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
      legMode: LegMode.cycling,
      durationSeconds: 600,
      durationText: '10 min',
      distanceText: '3 km',
    );
    const legB = RouteLeg(
      polylinePoints: [LatLng(1, 1), LatLng(2, 2)],
      legMode: LegMode.driving,
      durationSeconds: 300,
      durationText: '5 min',
      distanceText: '2 km',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: '15 min',
              distanceText: '5 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'bicycling',
              onModeChanged: (_) {},
              legs: const [legA, legB],
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Bike'), findsAtLeastNWidgets(2));
    expect(find.text('Drive'), findsAtLeastNWidgets(2));
  });

  testWidgets('Loyola appears in building start label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: CampusBuilding(
                name: 'X',
                fullName: 'X Hall',
                campus: Campus.loyola,
                id: 'x',
                boundary: const [],
                description: '',
              ),
              endBuilding: _hall(),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
              onRoomToRoomToggled: (_) {},
              onStartFloorChanged: (_) {},
              onEndFloorChanged: (_) {},
              onStartRoomChanged: (_) {},
              onEndRoomChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    expect(find.textContaining('Loyola'), findsOneWidget);
  });

  group('room-to-room', () {
    CampusBuilding startB() => CampusBuilding(
          id: 's',
          name: 'H',
          fullName: 'Hall',
          campus: Campus.sgw,
          boundary: const [],
          description: '',
        );

    CampusBuilding endB() => CampusBuilding(
          id: 'e',
          name: 'MB',
          fullName: 'MB',
          campus: Campus.sgw,
          boundary: const [],
          description: '',
        );

    IndoorMap tinyMap(CampusBuilding b) {
      final room = NavNode(id: 'r1', type: 'room', x: 0.5, y: 0.5, name: '101');
      final g = NavGraph(nodes: [room], edges: []);
      final floor = Floor(
        level: 8,
        label: '8',
        rooms: [
          Room(id: 'r1', name: '101', boundary: const [
            Offset(0.4, 0.4),
            Offset(0.6, 0.4),
            Offset(0.6, 0.6),
            Offset(0.4, 0.6),
          ]),
        ],
        navGraph: g,
      );
      return IndoorMap(building: b, floors: [floor]);
    }

    testWidgets('toggle calls onRoomToRoomToggled', (tester) async {
      bool? last;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              DirectionsCard(
                startBuilding: startB(),
                endBuilding: endB(),
                isLoading: false,
                errorMessage: null,
                polyline: Polyline(
                  polylineId: const PolylineId('p'),
                  points: const [LatLng(0, 0), LatLng(1, 1)],
                ),
                durationText: '1 min',
                distanceText: '1 m',
                onCancel: () {},
                onRetry: () {},
                selectedModeParam: 'walking',
                onModeChanged: (_) {},
                roomToRoomEnabled: false,
                onRoomToRoomToggled: (v) => last = v,
                onStartFloorChanged: (_) {},
                onEndFloorChanged: (_) {},
                onStartRoomChanged: (_) {},
                onEndRoomChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      expect(last, isTrue);
    });

    testWidgets('shows loading when indoorMapsLoading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              DirectionsCard(
                startBuilding: startB(),
                endBuilding: endB(),
                isLoading: false,
                errorMessage: null,
                polyline: Polyline(
                  polylineId: const PolylineId('p'),
                  points: const [LatLng(0, 0), LatLng(1, 1)],
                ),
                durationText: '1 min',
                distanceText: '1 m',
                onCancel: () {},
                onRetry: () {},
                selectedModeParam: 'walking',
                onModeChanged: (_) {},
                roomToRoomEnabled: true,
                indoorMapsLoading: true,
                onRoomToRoomToggled: (_) {},
                onStartFloorChanged: (_) {},
                onEndFloorChanged: (_) {},
                onStartRoomChanged: (_) {},
                onEndRoomChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(find.textContaining('Loading indoor maps'), findsOneWidget);
    });

    testWidgets('shows unavailable when a map is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              DirectionsCard(
                startBuilding: startB(),
                endBuilding: endB(),
                isLoading: false,
                errorMessage: null,
                polyline: Polyline(
                  polylineId: const PolylineId('p'),
                  points: const [LatLng(0, 0), LatLng(1, 1)],
                ),
                durationText: '1 min',
                distanceText: '1 m',
                onCancel: () {},
                onRetry: () {},
                selectedModeParam: 'walking',
                onModeChanged: (_) {},
                roomToRoomEnabled: true,
                startIndoorMap: tinyMap(startB()),
                endIndoorMap: null,
                onRoomToRoomToggled: (_) {},
                onStartFloorChanged: (_) {},
                onEndFloorChanged: (_) {},
                onStartRoomChanged: (_) {},
                onEndRoomChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(
          find.textContaining('Indoor maps not available'), findsOneWidget);
    });

    testWidgets('Start Navigation invokes onStartNavigation', (tester) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              DirectionsCard(
                startBuilding: startB(),
                endBuilding: endB(),
                isLoading: false,
                errorMessage: null,
                polyline: Polyline(
                  polylineId: const PolylineId('p'),
                  points: const [LatLng(0, 0), LatLng(1, 1)],
                ),
                durationText: '1 min',
                distanceText: '1 m',
                onCancel: () {},
                onRetry: () {},
                selectedModeParam: 'walking',
                onModeChanged: (_) {},
                roomToRoomEnabled: true,
                startIndoorMap: tinyMap(startB()),
                endIndoorMap: tinyMap(endB()),
                startRoomId: 'r1',
                endRoomId: 'r1',
                onRoomToRoomToggled: (_) {},
                onStartFloorChanged: (_) {},
                onEndFloorChanged: (_) {},
                onStartRoomChanged: (_) {},
                onEndRoomChanged: (_) {},
                onStartNavigation: () => started = true,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('start_navigation_button')));
      expect(started, isTrue);
    });

    testWidgets('floor dropdown triggers onStartFloorChanged', (tester) async {
      int? floorSeen;
      final map = IndoorMap(
        building: startB(),
        floors: [
          Floor(
            level: 8,
            label: 'Eight',
            rooms: [
              Room(id: 'r8', name: 'A', boundary: const [
                Offset(0.4, 0.4),
                Offset(0.6, 0.4),
                Offset(0.6, 0.6),
                Offset(0.4, 0.6),
              ]),
            ],
            navGraph: NavGraph(
              nodes: [
                NavNode(id: 'r8', type: 'room', x: 0.5, y: 0.5, name: 'A'),
              ],
              edges: const [],
            ),
          ),
          Floor(
            level: 9,
            label: 'Nine',
            rooms: [
              Room(id: 'r9', name: 'B', boundary: const [
                Offset(0.4, 0.4),
                Offset(0.6, 0.4),
                Offset(0.6, 0.6),
                Offset(0.4, 0.6),
              ]),
            ],
            navGraph: NavGraph(
              nodes: [
                NavNode(id: 'r9', type: 'room', x: 0.5, y: 0.5, name: 'B'),
              ],
              edges: const [],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              DirectionsCard(
                startBuilding: startB(),
                endBuilding: endB(),
                isLoading: false,
                errorMessage: null,
                polyline: Polyline(
                  polylineId: const PolylineId('p'),
                  points: const [LatLng(0, 0), LatLng(1, 1)],
                ),
                durationText: '1 min',
                distanceText: '1 m',
                onCancel: () {},
                onRetry: () {},
                selectedModeParam: 'walking',
                onModeChanged: (_) {},
                roomToRoomEnabled: true,
                startIndoorMap: map,
                endIndoorMap: tinyMap(endB()),
                startFloorFilter: 8,
                onRoomToRoomToggled: (_) {},
                onStartFloorChanged: (f) => floorSeen = f,
                onEndFloorChanged: (_) {},
                onStartRoomChanged: (_) {},
                onEndRoomChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Eight').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nine').last);
      await tester.pumpAndSettle();
      expect(floorSeen, 9);
    });
  });
}
