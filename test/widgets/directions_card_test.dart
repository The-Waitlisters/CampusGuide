import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
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
            ),
          ],
        ),
      ),
    );

    expect(find.text('5 min · 1 km'), findsOneWidget);
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
            ),
          ],
        ),
      ),
    );

    // Per-leg mode labels (covers _labelForLegMode walk + transit)
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    // Per-leg durations
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    // Per-leg distances (distanceText non-empty → visible)
    expect(find.text('0.4 km'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    // Total line
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
            ),
          ],
        ),
      ),
    );

    expect(find.text('Green Line'), findsOneWidget);
    expect(find.text('Transit'), findsNothing);
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
            ),
          ],
        ),
      ),
    );

    // Shuttle leg labels (covers _labelForLegMode shuttle + _iconForLegMode shuttle)
    expect(find.text('Shuttle'), findsOneWidget);
    // Empty distanceText leg hides the distance (no ' · ' separator for that leg)
    expect(find.text(''), findsNothing);
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
            ),
          ],
        ),
      ),
    );

    // Covers _labelForLegMode cycling + driving, _iconForLegMode cycling + driving
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
  });
}
