import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/location.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/widgets/home/search_overlay.dart';

Widget _wrapResults(List<MapLocation> results, ValueChanged<MapLocation> onSelect) {
  return MaterialApp(
    home: Scaffold(
      body: SearchResultsCard(results: results, onSelect: onSelect),
    ),
  );
}

Poi _poi({String id = 'p1', String name = 'Test POI', String? description}) =>
    Poi(
      id: id,
      name: name,
      campus: Campus.sgw,
      description: description,
      boundary: const LatLng(45.497, -73.578),
      openNow: true,
      openingHours: const [],
      photoName: const [],
      rating: 4.0,
      address: '1 Test St',
    );

CampusBuilding _building({String name = 'Hall', String? fullName}) =>
    CampusBuilding(
      id: 'b1',
      name: name,
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
      fullName: fullName,
      description: null,
    );

void main() {
  group('SearchResultsCard', () {
    testWidgets('renders Poi name as list tile title', (tester) async {
      final poi = _poi(name: 'Nearby Cafe', description: 'Good coffee');
      await tester.pumpWidget(_wrapResults([poi], (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Nearby Cafe'), findsOneWidget);
    });

    testWidgets('renders Poi description as subtitle when non-empty',
        (tester) async {
      final poi = _poi(name: 'Nearby Cafe', description: 'Good coffee');
      await tester.pumpWidget(_wrapResults([poi], (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Good coffee'), findsOneWidget);
    });

    testWidgets('Poi subtitle absent when description is empty', (tester) async {
      final poi = _poi(name: 'Silent Cafe', description: '');
      await tester.pumpWidget(_wrapResults([poi], (_) {}));
      await tester.pumpAndSettle();
      expect(find.text(''), findsNothing);
    });

    testWidgets('onSelect called with Poi when Poi tile tapped', (tester) async {
      MapLocation? selected;
      final poi = _poi(name: 'Nearby Cafe', description: 'Desc');
      await tester.pumpWidget(_wrapResults([poi], (loc) => selected = loc));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearby Cafe'));
      await tester.pump();
      expect(selected, equals(poi));
    });

    testWidgets('renders CampusBuilding name and fullName', (tester) async {
      final b = _building(name: 'Hall', fullName: 'Hall Building');
      await tester.pumpWidget(_wrapResults([b], (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Hall'), findsOneWidget);
      expect(find.text('Hall Building'), findsOneWidget);
    });

    testWidgets('onSelect called with CampusBuilding when building tile tapped',
        (tester) async {
      MapLocation? selected;
      final b = _building(name: 'Hall', fullName: 'Hall Building');
      await tester.pumpWidget(_wrapResults([b], (loc) => selected = loc));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hall'));
      await tester.pump();
      expect(selected, equals(b));
    });

    testWidgets('renders both Poi and CampusBuilding in same list',
        (tester) async {
      final poi = _poi(name: 'My Cafe');
      final b = _building(name: 'MB', fullName: 'MB Building');
      await tester.pumpWidget(_wrapResults([poi, b], (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('My Cafe'), findsOneWidget);
      expect(find.text('MB'), findsOneWidget);
    });
  });
}
