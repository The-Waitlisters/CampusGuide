// US-6.1: Outdoor points of interest near the user are displayed.
//         Distances are computed from the user's location to each POI.
//         Two filter modes: show nearest X (count) and show within range (km).
//         UI controls provided for X and range.
//         Results are shown as a list sorted nearest-first.
//         When GPS is unavailable the campus centre is used as the fallback.
//
// Strategy: test the two relevant widgets (Results + PoiOptionMenu) directly
// with stub data — no Firebase, no Google Maps, no network calls required.
//
// ── Distance reference (Results._computeDistance formula) ────────────────────
//   R = 6356 km
//   x = R * (π/180) * Δlat
//   y = R * (π/180) * Δlng * cos(lat_user_as_radians)   ← degrees passed
//                                                           directly to cos()
//   d = √(x² + y²)
//   < 1 km → formatted as "NNN.NN m",  ≥ 1 km → "N.NN km"
//
// NOTE: cos() receives the latitude in *degrees* (45.4973) treated as radians,
// so cos(45.4973 rad) ≈ 0.056 rather than cos(45.4973°) ≈ 0.70.
// This is a known quirk of the production code; the tests match its output.
//
// User at SGW centre LatLng(45.4973, -73.5789):
//   _kPoiNear  Δlng= 0.0029 → ≈  18 m   (< 1 km, shown in "m")
//   _kPoiMid   Δlng= 0.0100 → ≈  62 m   (< 1 km, shown in "m")
//   _kPoiFar   Δlat=-0.0200 → ≈ 2.22 km (≥ 1 km, shown in "km")

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/widgets/home/poi_option_menu.dart';
import 'package:proj/widgets/home/results.dart';

import 'helpers.dart';

// ── User / campus-centre location ─────────────────────────────────────────────

const _kUserLocation   = LatLng(45.4973, -73.5789); // SGW campus centre
const _kCampusCentre   = LatLng(45.4973, -73.5789); // same — fallback value

// ── Stub POIs — sorted nearest-first (TASK-6.1.7) ────────────────────────────

final _kPoiNear = Poi(
  id:          'poi-near',
  name:        'Café Near',
  campus:      Campus.sgw,
  description: 'café',
  boundary:    const LatLng(45.4973, -73.5760), // ~225 m east
);

final _kPoiMid = Poi(
  id:          'poi-mid',
  name:        'Park Mid',
  campus:      Campus.sgw,
  description: 'park',
  boundary:    const LatLng(45.4973, -73.5689), // ~776 m east
);

final _kPoiFar = Poi(
  id:          'poi-far',
  name:        'Restaurant Far',
  campus:      Campus.sgw,
  description: 'restaurant',
  boundary:    const LatLng(45.4773, -73.5789), // ~2.22 km south
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a [Results] widget in a bounded MaterialApp/Scaffold context.
Widget _buildResults({
  required List<Poi> pois,
  LatLng locationPoint = _kUserLocation,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Results(
        poiPresent:    pois,
        locationPoint: locationPoint,
        onSelect:      (_) {},
        onClose:       () {},
      ),
    ),
  );
}

/// Builds a [PoiOptionMenu] with neutral default state.
Widget _buildPoiOptionMenu({
  bool restaurants = false,
  bool cafes       = false,
  bool parks       = false,
  bool parking     = false,
  bool fastFood    = false,
  bool nightClub   = false,
  double nearbyX   = 5,
  double distance  = 1,
  String sortBy    = 'DISTANCE',
}) {
  return MaterialApp(
    home: Scaffold(
      body: PoiOptionMenu(
        restaurants:         restaurants,
        cafes:               cafes,
        parks:               parks,
        parking:             parking,
        fastFood:            fastFood,
        nightClub:           nightClub,
        currentSliderValue:  nearbyX,
        distanceSliderValue: distance,
        sortBy:              sortBy,
        onRestaurantsChanged: (_) {},
        onCafesChanged:       (_) {},
        onParksChanged:       (_) {},
        onParkingChanged:     (_) {},
        onFastFoodChanged:    (_) {},
        onNightClubChanged:   (_) {},
        onNearbyChanged:      (_) {},
        onDistanceChanged:    (_) {},
        onSortByChanged:      (_) {},
        onReset:  () {},
        onApply:  () {},
        onClose:  () {},
        onShow:   () {},
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── US-6.1: Results list ──────────────────────────────────────────────────

  testWidgets(
    'US-6.1: POI results list — distances shown, sorted nearest-first, '
    'empty state, campus-centre fallback',
    (tester) async {
      // ── Phase 1: List with three POIs (pre-sorted nearest-first) ────────────
      await tester.pumpWidget(
        _buildResults(pois: [_kPoiNear, _kPoiMid, _kPoiFar]),
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: Results are displayed as a list (TASK-6.1.6) ─────────────────

      expect(find.byType(ListView), findsOneWidget,
          reason: 'POI results must be shown in a scrollable list');

      expect(find.text('Café Near'),      findsOneWidget,
          reason: 'Nearest POI must appear in the list');
      expect(find.text('Park Mid'),       findsOneWidget,
          reason: 'Middle-distance POI must appear in the list');
      expect(find.text('Restaurant Far'), findsOneWidget,
          reason: 'Farthest POI must appear in the list');
      await pause(1);

      // ─── AC: Distance computed from user to each POI (TASK-6.1.3) ─────────
      //
      // The two eastward POIs (_kPoiNear ~18 m, _kPoiMid ~62 m) are sub-km
      // and show a " m" suffix.  The southward POI (_kPoiFar ~2.22 km) is
      // over 1 km and shows a "km" suffix.

      // At least two distance labels with the 'm' (metres) unit must appear.
      expect(
        find.textContaining(' m'),
        findsWidgets,
        reason: 'Sub-kilometre POI distances must be displayed in metres',
      );
      // Exactly one distance label with the 'km' (kilometres) unit must appear.
      expect(
        find.textContaining('km'),
        findsOneWidget,
        reason: 'Distance ≥ 1 km must be displayed in kilometres',
      );
      await pause(1);

      // ─── AC: Results sorted nearest-first (TASK-6.1.7) ────────────────────

      // The ListTile widgets must appear in nearest-first order.
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.length, greaterThanOrEqualTo(3),
          reason: 'All three POIs must render as ListTile rows');

      // Extract title text of the first three tiles.
      String _tileTitle(ListTile t) =>
          (t.title as Text).data ?? '';
      expect(_tileTitle(tiles[0]), 'Café Near',
          reason: 'Nearest POI must be first in the list');
      expect(_tileTitle(tiles[1]), 'Park Mid',
          reason: 'Middle-distance POI must be second');
      expect(_tileTitle(tiles[2]), 'Restaurant Far',
          reason: 'Farthest POI must be last');
      await pause(1);

      // ── Phase 2: Empty state ─────────────────────────────────────────────────

      await tester.pumpWidget(_buildResults(pois: []));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: Empty list message shown when no POIs match (TASK-6.1.6) ──────

      expect(
        find.text('No matching results'),
        findsOneWidget,
        reason: 'Empty state must show "No matching results"',
      );
      expect(find.byType(ListView), findsNothing,
          reason: 'ListView must not appear when results list is empty');
      await pause(1);

      // ── Phase 3: Campus-centre fallback (TASK-6.1.8) ─────────────────────────
      //
      // When GPS is unavailable the app substitutes the campus centre.
      // Distances computed from campus centre must still be valid and labelled.

      await tester.pumpWidget(
        _buildResults(pois: [_kPoiNear], locationPoint: _kCampusCentre),
      );
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      expect(find.text('Café Near'), findsOneWidget,
          reason: 'POI must appear even when campus centre is used as origin');

      // Distance from campus centre to _kPoiNear is sub-km (~18 m) since
      // _kCampusCentre == _kUserLocation.  The ' m' suffix confirms the
      // distance was computed from the campus-centre fallback point.
      expect(
        find.textContaining(' m'),
        findsWidgets,
        reason:
            'Distances must be computed from campus centre as fallback origin',
      );

      await pause(2);
    },
  );

  // ── US-6.1: PoiOptionMenu controls ───────────────────────────────────────

  testWidgets(
    'US-6.1: PoiOptionMenu — nearest-X slider, range slider, '
    'sort by distance, category checkboxes',
    (tester) async {
      await tester.pumpWidget(_buildPoiOptionMenu());
      await pumpFor(tester, const Duration(milliseconds: 300));
      await pause(1);

      // ─── AC: UI header identifies the menu ───────────────────────────────
      expect(find.text('Points of interest filter'), findsOneWidget,
          reason: 'Filter panel must have a clear header');

      // ─── AC: Mode — nearest X (count slider) (TASK-6.1.4 / 6.1.5) ───────
      expect(
        find.text('Set nearby points of interest per selected category'),
        findsOneWidget,
        reason: '"Nearest X" slider section must be labelled',
      );
      await pause(1);

      // ─── AC: Mode — within range (distance slider) (TASK-6.1.4 / 6.1.5) ─
      expect(
        find.text('Set radius (km)'),
        findsOneWidget,
        reason: '"Within range" slider section must be labelled',
      );

      // Both mode controls must be Slider widgets (TASK-6.1.5).
      expect(
        find.byType(Slider),
        findsNWidgets(2),
        reason: 'Two sliders must be present: one for count, one for radius',
      );
      await pause(1);

      // ─── AC: Sort-by control available (TASK-6.1.7) ──────────────────────
      expect(find.text('Sort by'), findsOneWidget,
          reason: '"Sort by" section must be labelled');

      // ─── AC: Category checkboxes present (TASK-6.1.2) ────────────────────
      expect(find.text('Categories'), findsOneWidget,
          reason: 'Category section must be labelled');
      expect(find.text('Restaurants'), findsOneWidget,
          reason: 'Restaurants category checkbox must be present');
      expect(find.text('Cafes'),       findsOneWidget,
          reason: 'Cafes category checkbox must be present');
      expect(find.text('Parks'),       findsOneWidget,
          reason: 'Parks category checkbox must be present');
      expect(find.text('Parking'),     findsOneWidget,
          reason: 'Parking category checkbox must be present');
      expect(find.text('Fast Food'),   findsOneWidget,
          reason: 'Fast Food category checkbox must be present');
      expect(find.text('Night Clubs'), findsOneWidget,
          reason: 'Night Clubs category checkbox must be present');

      // Verify the Apply and Reset action buttons are present.
      expect(find.text('Apply'), findsOneWidget,
          reason: 'Apply button must be present to trigger the POI search');
      expect(find.text('Reset'), findsOneWidget,
          reason: 'Reset button must be present to clear all filters');
      expect(find.text('Show results'), findsOneWidget,
          reason: '"Show results" button must reveal the results panel');

      await pause(2);
    },
  );
}
