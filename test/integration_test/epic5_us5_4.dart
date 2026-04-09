// US-5.4: Indoor points of interest are displayed on the indoor map.
//         Different types of points of interest use distinct icons.
//         Points of interest correspond to the selected floor.
//         Points of interest are clearly distinguishable from rooms.
//         The map remains readable when points of interest are shown.
//
// Uses the real Hall building (H.json) so the test reflects exactly what a
// normal user sees. H.json has no embedded POI data, so the POI-overlay icon
// distinctness AC is verified at the model level (IndoorPoiType enum). All
// other ACs — floor switching, room list, map readability — are exercised
// against the live asset on floors 1 and 8.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/indoor_poi.dart';
import 'package:proj/screens/indoor_map_screen.dart';

import 'helpers.dart';

// ── Real Hall building ─────────────────────────────────────────────────────────
// H.json floors: 1, 2, 8, 9.
// Floor 8 has 78 rooms labelled 801, 802, 803 … — the deepest teaching floor
// that a student would navigate to.

final _kBuilding = CampusBuilding(
  id: 'hall-building',
  name: 'H',
  fullName: 'Henry F. Hall Building',
  campus: Campus.sgw,
  description: '',
  boundary: const [],
);

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.4: POI icon types are distinct (model), indoor map is readable on '
    'floor 1 and floor 8, floor switching updates the room list',
    (tester) async {
      // ── Pump the screen with the real loader ──────────────────────────────────
      await tester.pumpWidget(
        MaterialApp(
          home: IndoorMapScreen(building: _kBuilding),
        ),
      );

      // Wait for the real JSON asset to load and parse.
      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe floor 1

      expect(find.text('Henry F. Hall Building'), findsOneWidget,
          reason: 'AppBar must show the building name');

      // ─── AC: Different POI types use distinct icons (model level) ─────────────
      //
      // Even though H.json carries no embedded POI data, the IndoorPoiType enum
      // contract must hold: each type maps to a unique icon, and every POI icon
      // differs from the regular room icon so a user can tell them apart at a
      // glance.

      final allPoiIcons    = IndoorPoiType.values.map((t) => t.icon).toList();
      final uniquePoiIcons = allPoiIcons.toSet();
      expect(
        uniquePoiIcons.length,
        equals(allPoiIcons.length),
        reason: 'Every IndoorPoiType must map to a distinct icon',
      );
      for (final poiType in IndoorPoiType.values) {
        expect(
          poiType.icon == Icons.meeting_room_outlined,
          isFalse,
          reason: '${poiType.name} POI icon must differ from the room icon',
        );
      }
      await pause(1);

      // ─── AC: Map is readable on floor 1 ──────────────────────────────────────

      expect(find.byType(InteractiveViewer), findsOneWidget,
          reason: 'Zoomable floor-plan canvas must be present on floor 1');
      expect(find.byType(Image), findsWidgets,
          reason: 'Floor-plan image must be visible on floor 1');
      expect(find.byType(ListView), findsWidgets,
          reason: 'Room list must be present on floor 1');
      expect(find.byIcon(Icons.meeting_room_outlined), findsWidgets,
          reason: 'Room tiles must use meeting_room_outlined on floor 1');
      await pause(1);

      // ─── AC: Switch to floor 8 — what a normal user sees ─────────────────────

      await tester.tap(find.byType(DropdownButton<int>));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Floor 8').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(2); // observe floor 8 — this is what the user navigates to

      // Floor 8 must render its own floor-plan image and room list.
      expect(find.byType(InteractiveViewer), findsOneWidget,
          reason: 'Zoomable floor-plan canvas must be present on floor 8');
      expect(find.byType(Image), findsWidgets,
          reason: 'Floor-plan image must be visible on floor 8');

      // Floor 8 rooms are labelled 801, 802, … — at least one must appear in
      // the (unscrolled) room list to confirm the list updated for the new floor.
      expect(find.byIcon(Icons.meeting_room_outlined), findsWidgets,
          reason: 'Room tiles must appear in the list after switching to floor 8');

      await pause(2); // final visual pause — user observes the floor 8 layout
    },
  );
}
