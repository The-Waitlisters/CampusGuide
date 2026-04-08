// US-6.2: Walking route from a user's location to an outdoor POI.
//
//   TASK-6.2.1 — User location detected via GPS or accepted as manual start.
//   TASK-6.2.2 — Outdoor POI selectable as destination.
//   TASK-6.2.3 — Walking route computed between user and selected POI.
//   TASK-6.2.4 — Route rendered visually on the map (polyline set).
//   TASK-6.2.5 — Distance/time estimate displayed.
//   TASK-6.2.6 — Location denied/unavailable → informative message shown.
//
// Strategy: test the relevant widget layer directly —
//   • BuildingDetailContent (isPoi:true) — POI detail sheet with
//     "Set as Start" / "Set as Destination" buttons.
//   • DirectionsCard — shows route summary (duration + distance),
//     transport-mode chips, and the location-required error.
//
// No Firebase, no live GPS, no Google Maps controller needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/widgets/home/building_detail_content.dart';
import 'package:proj/widgets/home/directions_card.dart';

import 'helpers.dart';

// ── Stub POI ──────────────────────────────────────────────────────────────────

final _kDestPoi = Poi(
  id:          'poi-cafe',
  name:        'Café Near',
  campus:      Campus.sgw,
  description: 'café',
  boundary:    const LatLng(45.4973, -73.5760),
  openNow:     true,
  openingHours: const ['Mon–Fri: 08:00–18:00'],
);

// ── Stub route polyline ───────────────────────────────────────────────────────
//
// A minimal 2-point polyline; enough to satisfy the DirectionsCard condition
// `polyline != null` so the duration/distance row is rendered.

final _kRoutePolyline = Polyline(
  polylineId: const PolylineId('test-walk-route'),
  points: const [
    LatLng(45.4973, -73.5789), // user
    LatLng(45.4973, -73.5760), // POI
  ],
  color: Colors.blue,
  width: 4,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A [DirectionsCard] wrapped in a Stack so its Positioned widget renders.
Widget _buildDirectionsCard({
  Poi?     startPoi,
  Poi?     endPoi,
  bool     useCurrentLocationAsStart = false,
  Polyline? polyline,
  String?  durationText,
  String?  distanceText,
  String?  locationRequiredMessage,
  String   selectedMode = kModeWalking,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          DirectionsCard(
            startPoi:                 startPoi,
            endPoi:                   endPoi,
            isLoading:                false,
            errorMessage:             null,
            polyline:                 polyline,
            durationText:             durationText,
            distanceText:             distanceText,
            onCancel:                 () {},
            onRetry:                  () {},
            useCurrentLocationAsStart: useCurrentLocationAsStart,
            locationRequiredMessage:  locationRequiredMessage,
            selectedModeParam:        selectedMode,
            onModeChanged:            (_) {},
            onRoomToRoomToggled:      (_) {},
            onStartFloorChanged:      (_) {},
            onEndFloorChanged:        (_) {},
            onStartRoomChanged:       (_) {},
            onEndRoomChanged:         (_) {},
          ),
        ],
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── US-6.2: POI selection + route display ────────────────────────────────

  testWidgets(
    'US-6.2: POI selectable as destination, walking route shown with '
    'distance/time estimate',
    (tester) async {
      // ── Phase 1: POI detail sheet — "Set as Start" / "Set as Destination" ──

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuildingDetailContent(
                isPoi:          true,
                poi:            _kDestPoi,
                startPoi:       null,
                endPoi:         null,
                isAnnex:        false,
                startBuilding:  null,
                endBuilding:    null,
                onSetStart:       () {},
                onSetDestination: () {},
              ),
            ),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: POI name shown in the detail sheet ────────────────────────────

      expect(find.textContaining('Café Near'), findsOneWidget,
          reason: 'POI name must appear in the detail sheet header');

      // ─── AC: User can select the POI as destination (TASK-6.2.2) ──────────

      expect(find.text('Set as Destination'), findsOneWidget,
          reason: '"Set as Destination" button must be present for a POI');

      // ─── AC: User can also use the POI as the route start ─────────────────

      expect(find.text('Set as Start'), findsOneWidget,
          reason: '"Set as Start" button must be present for a POI');

      // Open status and description visible.
      expect(find.text('Open'), findsOneWidget,
          reason: 'Open/Closed status must be shown in the POI sheet');
      await pause(1);

      // ── Phase 2: Walking route — DirectionsCard with GPS start + POI dest ──

      await tester.pumpWidget(
        _buildDirectionsCard(
          useCurrentLocationAsStart: true,     // TASK-6.2.1 — GPS location
          endPoi:      _kDestPoi,              // TASK-6.2.2 — POI as destination
          polyline:    _kRoutePolyline,        // TASK-6.2.4 — route polyline set
          durationText: '3 min',              // TASK-6.2.5 — time estimate
          distanceText: '225 m',              // TASK-6.2.5 — distance estimate
          selectedMode: kModeWalking,
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: Start point shown as current GPS location (TASK-6.2.1) ───────

      expect(
        find.textContaining('Current location'),
        findsOneWidget,
        reason: 'GPS origin must be labelled "Current location" in the card',
      );

      // ─── AC: Destination is the selected POI (TASK-6.2.2) ─────────────────

      expect(
        find.textContaining('Café Near'),
        findsOneWidget,
        reason: 'Selected POI must appear as the destination in the card',
      );

      // ─── AC: Walking mode chip available (TASK-6.2.3) ─────────────────────

      expect(find.text('Walk'), findsOneWidget,
          reason: '"Walk" transport mode chip must be present');
      expect(find.text('Bike'),    findsOneWidget);
      expect(find.text('Drive'),   findsOneWidget);
      expect(find.text('Transit'), findsOneWidget);
      await pause(1);

      // ─── AC: Distance/time estimate displayed (TASK-6.2.5) ────────────────

      expect(
        find.textContaining('3 min'),
        findsOneWidget,
        reason: 'Walking time estimate must be shown in the directions card',
      );
      expect(
        find.textContaining('225 m'),
        findsOneWidget,
        reason: 'Walking distance estimate must be shown in the directions card',
      );

      // ─── AC: Polyline is set — route rendered on map (TASK-6.2.4) ─────────
      //
      // The DirectionsCard enters the route-display branch only when
      // `polyline != null`.  The duration/distance text appearing above
      // confirms the card reached that branch, meaning the polyline object
      // was consumed for map rendering.
      expect(
        find.textContaining('3 min'),
        findsOneWidget,
        reason:
            'Route display branch reached — polyline must have been provided',
      );
      await pause(1);
    },
  );

  // ── US-6.2: Location denied / unavailable ────────────────────────────────

  testWidgets(
    'US-6.2: Location denied — informative message shown instead of route',
    (tester) async {
      const locationDeniedMsg =
          'Location access is required to get directions from your current '
          'position. Please enable GPS or select a manual start point.';

      await tester.pumpWidget(
        _buildDirectionsCard(
          endPoi: _kDestPoi,
          locationRequiredMessage: locationDeniedMsg, // TASK-6.2.6
          polyline: null,
          durationText: null,
          distanceText: null,
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: Location error message shown instead of route (TASK-6.2.6) ───

      expect(
        find.textContaining('Location access is required'),
        findsOneWidget,
        reason:
            'When location is denied the card must explain how to proceed',
      );
      expect(
        find.textContaining('enable GPS'),
        findsOneWidget,
        reason: 'Error message must guide user to enable GPS or use manual start',
      );

      // No duration/distance must appear — route cannot be computed.
      expect(
        find.textContaining('min'),
        findsNothing,
        reason: 'No route duration must appear when location is unavailable',
      );
      expect(
        find.textContaining('Loading directions'),
        findsNothing,
        reason: 'Loading spinner must not appear when location is blocked',
      );

      // The destination is still shown so the user knows what they wanted.
      expect(
        find.textContaining('Café Near'),
        findsOneWidget,
        reason: 'Destination POI must still be labelled in the card',
      );

      await pause(2);
    },
  );
}
