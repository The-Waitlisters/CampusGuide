// US-5.6: The system supports indoor directions between different buildings.
//         Indoor and outdoor navigation segments are seamlessly connected.
//         Routes between SGW and Loyola are supported.
//         Transitions between buildings are clearly indicated.
//         The full route is understandable and continuous.
//
// Flow:
//   1. App launches on the map (HomeScreen)
//   2. Hall building tapped → "Set as Start"
//   3. LB building tapped → "Set as Destination"
//   4. DirectionsCard appears with outdoor route
//   5. Room-to-Room Navigation toggle enabled
//   6. Indoor maps load; start room (H-110) selected in Hall
//   7. End room (204) selected in LB (floor 2)
//   8. "Start Navigation" tapped → MultiBuildingRouteScreen opens
//   9. Three-phase bar, indoor/outdoor segments, transitions verified

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'US-5.6: map → Hall as start → LB as destination → '
    'room-to-room toggle → select rooms → Start Navigation → '
    'three-phase bar, indoor/outdoor segments connected, '
    'transitions clearly indicated, route continuous',
    (tester) async {
      await loadEnv();

      // ── 1. Launch the real app ────────────────────────────────────────────────

      await tester.pumpWidget(
        CampusGuideApp(
          home: HomeScreen(
            testMapControllerCompleter: Completer<GoogleMapController>(),
            testStartLocation: const LatLng(45.4972, -73.5785),
          ),
        ),
      );

      await pumpFor(tester, const Duration(seconds: 3));

      final dynamic state = tester.state(find.byType(HomeScreen));

      await pumpFor(tester, const Duration(seconds: 5));
      await pause(3); // observe the campus map

      expect(find.byKey(const Key('campus_toggle')), findsOneWidget);
      expect(find.text('SGW'), findsOneWidget);

      // ── 2. Select Hall as Start ───────────────────────────────────────────────

      final buildings = List.from(state.buildingsPresent as List);
      final hallBuilding = buildings.firstWhere(
        (b) => b.name == 'H' && b.campus == Campus.sgw,
      );
      final lbBuilding = buildings.firstWhere(
        (b) => b.name == 'LB' && b.campus == Campus.sgw,
      );

      state.simulateBuildingTap(hallBuilding);
      await pumpFor(tester, const Duration(seconds: 2));
      await pause(1); // observe Hall detail sheet

      await tester.tap(find.text('Set as Start'));
      await pumpFor(tester, const Duration(seconds: 2));
      await pause(1);

      expect(find.textContaining('Start:'), findsOneWidget);

      // ── 3. Select LB as Destination ──────────────────────────────────────────

      state.simulateBuildingTap(lbBuilding);
      await pumpFor(tester, const Duration(seconds: 2));
      await pause(1); // observe LB detail sheet

      await tester.tap(find.text('Set as Destination'));
      await pumpFor(tester, const Duration(seconds: 2));
      await pause(1);

      // ── 4. Wait for outdoor route to load ────────────────────────────────────

      await pumpFor(tester, const Duration(seconds: 8));
      await pause(2); // observe directions card with outdoor route

      // ── 5. Enable Room-to-Room Navigation toggle ──────────────────────────────

      expect(
        find.byKey(const Key('room_to_room_toggle')),
        findsOneWidget,
        reason: 'Room-to-Room toggle must appear when both buildings are set',
      );

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ── 6. Wait for indoor maps to load ──────────────────────────────────────

      // The loading indicator disappears once both IndoorMaps are ready.
      await pumpFor(tester, const Duration(seconds: 5));
      expect(
        find.text('Loading indoor maps...'),
        findsNothing,
        reason: 'Indoor maps must finish loading before room pickers appear',
      );
      await pause(1);

      // ── 7. Select start room in Hall (floor 1 → H-110) ───────────────────────
      //
      // _RoomPicker order: first = start (Hall), last = end (LB).
      // DropdownButton<String>.first = Hall room picker.
      // Hall floor 1 is the default first floor level — no floor change needed.

      await tester.tap(find.byType(DropdownButton<String>).first);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1); // observe room list for Hall

      // Select 'H-131' from the Hall room list.
      await tester.tap(find.text('H-131').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ── 8. Select end room in LB (room 204) ──────────────────────────────────

      await tester.tap(find.byType(DropdownButton<String>).last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // Select '204' from the LB room list.
      await tester.tap(find.text('204').last);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ── 9. Start Navigation → MultiBuildingRouteScreen ───────────────────────

      expect(
        find.byKey(const Key('start_navigation_button')),
        findsOneWidget,
        reason: 'Start Navigation button must appear when both rooms are selected',
      );

      await tester.tap(find.byKey(const Key('start_navigation_button')));
      await pumpFor(tester, const Duration(seconds: 3));
      await pause(2); // observe MultiBuildingRouteScreen loading

      // Wait for _computeRoutes() to finish.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Loading indicator must be gone before assertions start',
      );
      await pause(1);

      // ─── AC: Full route is understandable — three-phase bar visible ────────

      expect(find.text('H'),    findsOneWidget,
          reason: 'Phase bar must show start-building chip "H"');
      expect(find.text('Walk'), findsOneWidget,
          reason: 'Phase bar must show transport-mode chip "Walk"');
      expect(find.text('LB'),   findsOneWidget,
          reason: 'Phase bar must show end-building chip "LB"');

      expect(find.byIcon(Icons.chevron_right), findsWidgets,
          reason: 'Phase bar must show chevron arrows between chips');

      // ─── AC: Indoor phase 1 — navigate to Hall exit ───────────────────────

      expect(
        find.textContaining('Navigate to exit'),
        findsOneWidget,
        reason: 'Phase 1 title must say "Navigate to exit"',
      );
      expect(
        find.textContaining('Henry F. Hall Building'),
        findsOneWidget,
        reason: 'Phase 1 must reference the start building by full name',
      );

      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Phase 1 must display a floor-plan canvas',
      );

      expect(
        find.textContaining("I've exited"),
        findsOneWidget,
        reason: 'Phase 1 continue button must say "I\'ve exited …"',
      );
      await pause(1);

      // ─── AC: Outdoor segment shown ────────────────────────────────────────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      // The outdoor phase renders a GoogleMap — give it time to initialise.
      await pumpFor(tester, const Duration(seconds: 6));
      await pause(4);

      expect(
        find.textContaining('Walk to'),
        findsOneWidget,
        reason: 'Outdoor phase title must describe the walk to LB',
      );
      expect(
        find.byIcon(Icons.directions_walk),
        findsWidgets,
        reason: 'Same-campus route must show the walking icon',
      );
      expect(
        find.textContaining("I've arrived at"),
        findsOneWidget,
        reason: 'Outdoor continue button must confirm arrival at LB',
      );
      await pause(1);

      // ─── AC: Indoor phase 3 — navigate inside LB to room 204 ──────────────

      await tester.tap(find.byKey(const Key('phase_continue_button')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      expect(
        find.textContaining('Navigate inside'),
        findsOneWidget,
        reason: 'Phase 3 title must say "Navigate inside"',
      );
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'Phase 3 must display a floor-plan canvas for LB',
      );

      // ─── AC: Completed phases show check-circle icons ─────────────────────

      expect(
        find.byIcon(Icons.check_circle),
        findsWidgets,
        reason: 'Completed phases must show check-circle icons in the phase bar',
      );

      // ─── AC: Done button ends navigation ──────────────────────────────────

      expect(
        find.textContaining('Done'),
        findsOneWidget,
        reason: 'Phase 3 final button must say "Done — arrived at destination"',
      );

      await pause(2); // final visual pause
    },
  );
}
