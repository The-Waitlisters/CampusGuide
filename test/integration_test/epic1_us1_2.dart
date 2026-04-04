// US-1.2: Make shapes for campus buildings so they are visually distinct

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/main.dart';
import 'package:proj/screens/home_screen.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/data/data_parser.dart';
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─── [Data] tests — no widget tree needed ────────────────────────────────────

  test(
    'US-1.2 [Data]: every SGW building has a valid polygon boundary (≥3 points)',
        () async {
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final sgw = buildings.where((b) => b.campus == Campus.sgw).toList();

      expect(sgw, isNotEmpty, reason: 'At least one SGW building must exist');
      for (final b in sgw) {
        expect(b.boundary.length, greaterThanOrEqualTo(3),
            reason: 'SGW building "${b.name}" needs ≥3 boundary points');
      }
    },
  );

  test(
    'US-1.2 [Data]: every Loyola building has a valid polygon boundary (≥3 points)',
        () async {
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final loyola = buildings.where((b) => b.campus == Campus.loyola).toList();

      expect(loyola, isNotEmpty, reason: 'At least one Loyola building must exist');
      for (final b in loyola) {
        expect(b.boundary.length, greaterThanOrEqualTo(3),
            reason: 'Loyola building "${b.name}" needs ≥3 boundary points');
      }
    },
  );

  test(
    'US-1.2 [Data]: every building belongs to a known Concordia campus',
        () async {
      final buildings = await DataParser().getBuildingInfoFromJSON();
      for (final b in buildings) {
        expect(
          b.campus == Campus.sgw || b.campus == Campus.loyola,
          isTrue,
          reason:
          'Building "${b.name}" has an unknown campus — '
              'non-Concordia buildings must not be loaded',
        );
      }
    },
  );

  // ─── [Widget] tests — pumps HomeScreen, checks polygon state ─────────────────

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      CampusGuideApp(
        home: HomeScreen(
          testMapControllerCompleter: Completer<GoogleMapController>(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Wait for the buildings future to fully resolve so polygons are on the map
    final dynamic state = tester.state(find.byType(HomeScreen));
    await state.testBuildingsFuture;
    await tester.pumpAndSettle();

    await pause(4); // let the Google Maps native view render the polygons
  }

  testWidgets(
    'US-1.2 [Widget]: every rendered polygon has a unique ID (no building drawn twice)',
        (tester) async {
      await pumpApp(tester);
      final dynamic state = tester.state(find.byType(HomeScreen));
      final Set<Polygon> polygons = state.testPolygons as Set<Polygon>;

      final ids = polygons.map((p) => p.polygonId.value).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Each building must have a distinct polygon ID');
      await pause(2);
    },
  );

  testWidgets(
    'US-1.2 [Widget]: every rendered polygon corresponds to a known Concordia building',
        (tester) async {
      await pumpApp(tester);
      final buildings = await DataParser().getBuildingInfoFromJSON();
      final knownIds = buildings.map((b) => b.id).toSet();

      final dynamic state = tester.state(find.byType(HomeScreen));
      final Set<Polygon> polygons = state.testPolygons as Set<Polygon>;

      for (final poly in polygons) {
        expect(
          knownIds.contains(poly.polygonId.value),
          isTrue,
          reason:
          'Polygon "${poly.polygonId.value}" does not match any known '
              'Concordia building — non-Concordia shapes must not be rendered',
        );
      }
      await pause(2);
    },
  );
}