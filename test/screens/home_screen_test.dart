import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/home_screen.dart' as home_screen;
import 'package:proj/services/building_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'home_screen_test.mocks.dart';


class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.always);

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return Stream.value(Position(
      latitude: 45.4972,
      longitude: -73.5788,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ));
  }
}

// --- Test data ---

CampusBuilding buildTestBuilding({
  String id = '1',
  String name = 'Building 1',
  String fullName = 'Full Building 1',
  Campus campus = Campus.sgw,
  List<LatLng>? boundary,
  String description = 'A test building',
  List<String> openingHours = const ['9-5'],
  List<String> departments = const ['Dept A'],
  List<String> services = const ['Service X'],
  bool isWheelchairAccessible = false,
  bool hasBikeParking = false,
  bool hasCarParking = false,
}) {
  return CampusBuilding(
    id: id,
    name: name,
    fullName: fullName,
    campus: campus,
    boundary: boundary ??
        const [
          LatLng(0, 0),
          LatLng(0, 2),
          LatLng(2, 2),
          LatLng(2, 0),
          LatLng(0, 0),
        ],
    description: description,
    openingHours: openingHours,
    departments: departments,
    services: services,
    isWheelchairAccessible: isWheelchairAccessible,
    hasBikeParking: hasBikeParking,
    hasCarParking: hasCarParking,
  );
}

@GenerateMocks([DataParser, BuildingLocator])
void main() {
  // -------------------------------------------------------------------------
  // isPointInPolygon (pure function)
  // -------------------------------------------------------------------------
  group('isPointInPolygon', () {
    const polygon = [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
      LatLng(0, 0),
    ];

    test('returns true for a point inside the polygon', () {
      expect(home_screen.isPointInPolygon(const LatLng(1, 1), polygon), isTrue);
    });

    test('returns false for a point outside the polygon', () {
      expect(home_screen.isPointInPolygon(const LatLng(3, 3), polygon), isFalse);
    });

    test('returns false for a point to the left of the polygon', () {
      expect(home_screen.isPointInPolygon(const LatLng(0.5, -0.5), polygon), isFalse);
    });

    test('handles polygon with zero denominator (vertical edge)', () {
      const degenerate = [LatLng(1, 0), LatLng(1, 2), LatLng(1, 0)];
      expect(home_screen.isPointInPolygon(const LatLng(0.5, 1), degenerate), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // findBuildingAtPoint (pure function)
  // -------------------------------------------------------------------------
  group('findBuildingAtPoint', () {
    late CampusBuilding sgwBuilding;
    late CampusBuilding loyolaBuilding;

    setUp(() {
      sgwBuilding = buildTestBuilding(id: 'sgw1', campus: Campus.sgw);
      loyolaBuilding = buildTestBuilding(
        id: 'loyola1',
        campus: Campus.loyola,
        boundary: const [
          LatLng(10, 10),
          LatLng(10, 12),
          LatLng(12, 12),
          LatLng(12, 10),
          LatLng(10, 10),
        ],
      );
    });

    test('returns building when point is inside boundary and campus matches', () {
      final result = home_screen.findBuildingAtPoint(
        const LatLng(1, 1),
        [sgwBuilding, loyolaBuilding],
        Campus.sgw,
      );
      expect(result, equals(sgwBuilding));
    });

    test('returns null when point is inside boundary but campus does not match', () {
      final result = home_screen.findBuildingAtPoint(
        const LatLng(1, 1),
        [sgwBuilding, loyolaBuilding],
        Campus.loyola,
      );
      expect(result, isNull);
    });

    test('returns null when point is outside all buildings', () {
      final result = home_screen.findBuildingAtPoint(
        const LatLng(5, 5),
        [sgwBuilding, loyolaBuilding],
        Campus.sgw,
      );
      expect(result, isNull);
    });

    test('returns null for empty buildings list', () {
      final result = home_screen.findBuildingAtPoint(
        const LatLng(1, 1),
        [],
        Campus.sgw,
      );
      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // HomeScreen widget
  // -------------------------------------------------------------------------
  group('HomeScreen', () {
    late MockDataParser mockDataParser;
    late MockBuildingLocator mockBuildingLocator;

    setUp(() {
      mockDataParser = MockDataParser();
      mockBuildingLocator = MockBuildingLocator();
      GeolocatorPlatform.instance = MockGeolocatorPlatform();

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => <CampusBuilding>[]);
      when(mockDataParser.buildingsPresent).thenReturn(<CampusBuilding>[]);
      when(mockBuildingLocator.update(
        userPoint: anyNamed('userPoint'),
        campus: anyNamed('campus'),
        buildings: anyNamed('buildings'),
      )).thenReturn(BuildingStatus.none());
      when(mockBuildingLocator.reset()).thenReturn(null);
    });

    Widget wrap(Widget child) {
      return MaterialApp(home: child);
    }

    testWidgets('shows app bar title', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.text('The Waitlisters'), findsOneWidget);
    });

    testWidgets('shows loading indicator until buildings future completes',
        (WidgetTester tester) async {
      final completer = Completer<List<CampusBuilding>>();
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) => completer.future);
      when(mockDataParser.buildingsPresent).thenReturn(<CampusBuilding>[]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error message when buildings future fails',
        (WidgetTester tester) async {
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => throw Exception('load failed'));
      when(mockDataParser.buildingsPresent).thenReturn(<CampusBuilding>[]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading polygons'), findsOneWidget);
    });

    testWidgets('builds map and overlay cards when buildings load',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('shows "Not in a building" when GPS has no building',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Not in a building'), findsOneWidget);
    });

    testWidgets('shows CampusToggle with SGW and Loyola', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.text('SGW'), findsOneWidget);
      expect(find.text('Loyola'), findsOneWidget);
    });

    testWidgets('calls getBuildingInfoFromJSON on init when parser is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pump();

      verify(mockDataParser.getBuildingInfoFromJSON()).called(1);
    });
  });
}
