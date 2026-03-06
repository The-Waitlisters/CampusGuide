import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:proj/data/data_parser.dart';
import 'package:proj/main.dart' as main_app;
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/screens/home_screen.dart' as home_screen;
import 'package:proj/screens/home_screen.dart' show HomeScreenState, HomeScreen, boundsForRoute;
import 'package:proj/services/building_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:proj/services/directions/directions_controller.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/utilities/polygon_helper.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:proj/widgets/home/building_detail_content.dart';
import 'package:proj/widgets/home/building_detail_sheet.dart';

import '../services/directions/directions_controller_and_strategy_test.dart';
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

/// Platform mock when location services are disabled (covers debugPrint branch).
class LocationDisabledGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() => Future.value(false);
}

class FakeDataParser extends DataParser {
  FakeDataParser(this._buildings);

  final List<CampusBuilding> _buildings;

  @override
  Future<List<CampusBuilding>> getBuildingInfoFromJSON() async {
    buildingsPresent = _buildings;
    return _buildings;
  }
}

class FakeGeocodingSuccess extends GeocodingPlatform with MockPlatformInterfaceMixin {
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
      double latitude,
      double longitude, {
        String? localeIdentifier,
      }) async {
    return <Placemark>[
      const Placemark(
        street: '123 Test St',
        locality: 'Montreal',
        postalCode: 'H0H0H0',
      ),
    ];
  }
}

class FakeGeocodingThrow extends GeocodingPlatform with MockPlatformInterfaceMixin {
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
      double latitude,
      double longitude, {
        String? localeIdentifier,
      }) {
    throw PlatformException(code: 'FAIL', message: 'boom');
  }
}

/// Platform mock when permission is denied (covers requestPermission + debugPrint).
class PermissionDeniedGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.denied);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.deniedForever);

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream.empty();
}

/// Platform mock that exposes a stream controller for multi-emit tests.
class PositionStreamGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  PositionStreamGeolocatorPlatform(this.stream);

  final Stream<Position> stream;

  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.always);

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      stream;
}

/// Fake map controller so _goToCampus can complete in tests.
class FakeGoogleMapController implements GoogleMapController {
  int animateCameraCallCount = 0;
  CameraUpdate? lastCameraUpdate;

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) {
    animateCameraCallCount++;
    lastCameraUpdate = cameraUpdate;
    return Future.value();
  }

  @override
  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate) =>
      Future.value(const LatLng(0, 0));

  @override
  Future<ScreenCoordinate> getScreenCoordinate(LatLng latLng) =>
      Future.value(const ScreenCoordinate(x: 0, y: 0));

  @override
  Future<LatLngBounds> getVisibleRegion() =>
      Future.value(LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      ));

  @override
  Future<void> moveCamera(CameraUpdate update) => Future.value();

  @override
  int get mapId => 0;

  @override
  Future<double> getZoomLevel() => Future.value(0);

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId) => Future.value();

  @override
  Future<bool> isMarkerInfoWindowShown(MarkerId markerId) =>
      Future.value(false);

  @override
  Future<void> setMapStyle(String? mapStyle) => Future.value();

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId) => Future.value();

  @override
  Future<Uint8List?> takeSnapshot() => Future.value(null);

  @override
  Future<String?> getStyleError() => Future.value(null);

  @override
  Future<void> clearTileCache(TileOverlayId tileOverlayId) => Future.value();

  @override
  void dispose() {}
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
  // geocoding method channel used by `geocoding`.
  const MethodChannel geocodingChannel = MethodChannel('flutter.baseflow.com/geocoding');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geocodingChannel, null);
  });

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
      expect(isPointInPolygon(const LatLng(1, 1), polygon), isTrue);
    });

    test('returns false for a point outside the polygon', () {
      expect(isPointInPolygon(const LatLng(3, 3), polygon), isFalse);
    });

    test('returns false for a point to the left of the polygon', () {
      expect(isPointInPolygon(const LatLng(0.5, -0.5), polygon), isFalse);
    });

    test('handles polygon with zero denominator (vertical edge)', () {
      const degenerate = [LatLng(1, 0), LatLng(1, 2), LatLng(1, 0)];
      expect(isPointInPolygon(const LatLng(0.5, 1), degenerate), isFalse);
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
      final result = findBuildingAtPoint(
        const LatLng(1, 1),
        [sgwBuilding, loyolaBuilding],
        Campus.sgw,
      );
      expect(result, equals(sgwBuilding));
    });

    test('returns null when point is inside boundary but campus does not match', () {
      final result = findBuildingAtPoint(
        const LatLng(1, 1),
        [sgwBuilding, loyolaBuilding],
        Campus.loyola,
      );
      expect(result, isNull);
    });

    test('returns null when point is outside all buildings', () {
      final result = findBuildingAtPoint(
        const LatLng(5, 5),
        [sgwBuilding, loyolaBuilding],
        Campus.sgw,
      );
      expect(result, isNull);
    });

    test('returns null for empty buildings list', () {
      final result = findBuildingAtPoint(
        const LatLng(1, 1),
        [],
        Campus.sgw,
      );
      expect(result, isNull);
    });
  });

  test('boundsForRoute computes southwest and northeast correctly', () {
    final a = const LatLng(45.0, -73.0);
    final b = const LatLng(46.0, -74.0);

    final bounds = boundsForRoute(a, b);

    expect(bounds.southwest.latitude, 45.0);
    expect(bounds.southwest.longitude, -74.0);
    expect(bounds.northeast.latitude, 46.0);
    expect(bounds.northeast.longitude, -73.0);
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

    testWidgets('location services disabled does not start stream',
        (WidgetTester tester) async {
      GeolocatorPlatform.instance = LocationDisabledGeolocatorPlatform();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('permission denied does not start stream',
        (WidgetTester tester) async {
      GeolocatorPlatform.instance = PermissionDeniedGeolocatorPlatform();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('when GPS building changes, getBuildingInfoFromJSON is called again',
        (WidgetTester tester) async {
      final building = buildTestBuilding(id: 'b1', name: 'B1');
      final streamController = StreamController<Position>.broadcast();
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);
      var updateCallCount = 0;
      when(mockBuildingLocator.update(
        userPoint: anyNamed('userPoint'),
        campus: anyNamed('campus'),
        buildings: anyNamed('buildings'),
      )).thenAnswer((_) {
        updateCallCount++;
        return updateCallCount == 1
            ? BuildingStatus.none()
            : BuildingStatus(building: building, treatedAsInside: true);
      });

      GeolocatorPlatform.instance =
          PositionStreamGeolocatorPlatform(streamController.stream);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      streamController.add(Position(
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
      await tester.pump();
      streamController.add(Position(
        latitude: 45.4973,
        longitude: -73.5789,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));
      await tester.pumpAndSettle();

      verify(mockDataParser.getBuildingInfoFromJSON()).called(greaterThan(1));
      await streamController.close();
    });

    testWidgets('tapping campus toggle calls reset and completes when test completer provided',
        (WidgetTester tester) async {
      final mapCompleter = Completer<GoogleMapController>()
        ..complete(FakeGoogleMapController());

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testMapControllerCompleter: mapCompleter,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loyola'));
      await tester.pumpAndSettle();

      verify(mockBuildingLocator.reset()).called(1);
    });

    testWidgets('shows GPS building name when inside building',
        (WidgetTester tester) async {
      final building = buildTestBuilding(id: 'b1', name: 'B1');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);
      when(mockBuildingLocator.update(
        userPoint: anyNamed('userPoint'),
        campus: anyNamed('campus'),
        buildings: anyNamed('buildings'),
      )).thenReturn(BuildingStatus(building: building, treatedAsInside: true));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.text('Full Building 1'), findsOneWidget);
    });

    testWidgets('tapping outside buildings shows not part of campus sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final state = tester.state<HomeScreenState>(find.byType(home_screen.HomeScreen));
      final scaffoldContext = tester.element(find.byType(CampusToggle));
      state.handleMapTap(const LatLng(99, 99), scaffoldContext);

      await tester.pumpAndSettle();

      expect(find.text('Not part of campus'), findsOneWidget);
      expect(find.text('Please select a shaded building'), findsOneWidget);
    });

    testWidgets('handleMapTap closes existing sheet if already open',
            (WidgetTester tester) async {
          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final state = tester.state<HomeScreenState>(
            find.byType(home_screen.HomeScreen).first,
          );

          final ctx = tester.element(find.byType(CampusToggle));

          // First tap → opens sheet
          state.handleMapTap(const LatLng(99, 99), ctx);
          await tester.pumpAndSettle();

          expect(find.text('Not part of campus'), findsOneWidget);

          // Second tap → should close sheet
          state.handleMapTap(const LatLng(99, 99), ctx);
          await tester.pumpAndSettle();

          expect(find.text('Not part of campus'), findsNothing);
    });

    testWidgets('selecting building shows detail sheet',
            (WidgetTester tester) async {

          final building = buildTestBuilding(
            id: 'b1',
            name: 'B1',
            fullName: 'B1 Annex',
          );

          when(mockDataParser.getBuildingInfoFromJSON())
              .thenAnswer((_) async => [building]);
          when(mockDataParser.buildingsPresent).thenReturn([building]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final state = tester.state<HomeScreenState>(
            find.byType(home_screen.HomeScreen).first,
          ) as dynamic;

          state.simulateBuildingSelection(building, const LatLng(1, 1));

          await tester.pump();          // setState
          await tester.pump();          // postFrameCallback
          await tester.pumpAndSettle();

          expect(find.textContaining('B1 Annex'), findsOneWidget);
          expect(find.byType(BuildingDetailContent), findsOneWidget);
          expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        });

    testWidgets('handleMapTap inside a building selects it and opens detail sheet',
        (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'B1',
        fullName: 'B1 Annex',
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final state = tester.state<HomeScreenState>(
        find.byType(home_screen.HomeScreen).first,
      );

      // Point (1,1) is inside the default boundary used by buildTestBuilding.
      state.handleMapTap(const LatLng(1, 1), tester.element(find.byType(CampusToggle)));

      // _showBuildingDetailSheet uses addPostFrameCallback.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('B1 Annex'), findsOneWidget);
      expect(find.byType(BuildingDetailContent), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('simulatePolygonTap selects building and opens detail sheet',
        (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'B1',
        fullName: 'Full B1',
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      // Access private state helpers via dynamic.
      final dynamic state = tester.state(
        find.byType(home_screen.HomeScreen).first,
      );

      state.simulatePolygonTap(const PolygonId('b1'), const LatLng(1, 1));

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Full B1'), findsOneWidget);
      expect(find.byType(BuildingDetailContent), findsOneWidget);
    });

    testWidgets(
        'search debounce shows results; selecting result opens sheet; Set as Start renders Directions card',
        (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'HALL',
        fullName: 'Hall Building',
        description: 'Desc',
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      // Type search query -> _onSearchChanged starts 300ms debounce.
      await tester.enterText(find.byType(TextField), 'hall');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Result tile appears.
      expect(find.text('HALL'), findsOneWidget);

      // Select result -> _onBuildingTapped(b) -> modal sheet.
      await tester.tap(find.text('HALL'));
      await tester.pumpAndSettle();

      // tap the actual button widget, not just the text.
      final setStartBtn = find.widgetWithText(ElevatedButton, 'Set as Start');
      expect(setStartBtn, findsOneWidget);

      await tester.tap(setStartBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Directions overlay should render when start is set.
      expect(find.text('Directions'), findsOneWidget);
      expect(find.textContaining('Start:'), findsOneWidget);

      // Close directions.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Directions'), findsNothing);
    });

    testWidgets('search clear button clears results and hides list',
        (WidgetTester tester) async {
      final building = buildTestBuilding(id: 'b1', name: 'HALL');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hall');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('HALL'), findsOneWidget);

      // Suffix clear icon should be visible once there is text.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('HALL'), findsNothing);
    });

    testWidgets(
        'getPlaceMarks returns formatted address when inside cursor building; returns No Address on exception',
        (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'B1',
        fullName: 'B1 Annex',
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      const insidePoint = LatLng(1, 1);
      state.simulateBuildingSelection(building, insidePoint);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Force geocoding to return a placemark without touching MethodChannels.
      GeocodingPlatform.instance = FakeGeocodingSuccess();

      final String address = await state.getPlaceMarks(insidePoint);
      // Don't assert exact formatting: it depends on how Placemark fields are
      // derived on a given platform. We only need to ensure the happy-path
      // returns a non-empty address (and not the catch fallback).
      expect(address, isNot('No Address'));
      expect(address.toLowerCase(), contains('montreal'));
      expect(address, contains('H0H0H0'));

      // Now force geocoding to throw -> catch branch returns "No Address".
      GeocodingPlatform.instance = FakeGeocodingThrow();

      final String address2 = await state.getPlaceMarks(insidePoint);
      expect(address2, 'No Address');
    });
    //test annex logic, applyPolygonSelection , showBuildingDetailSheet, selection styling
    group('BuildingDetailContent', () {
      testWidgets('renders building details correctly',
              (WidgetTester tester) async {
            final building = buildTestBuilding(
              name: 'B1',
              fullName: 'Full B1',
              description: 'Test description',
              openingHours: ['9-5'],
              departments: ['CS'],
              services: ['Library'],
              isWheelchairAccessible: true,
              hasBikeParking: true,
              hasCarParking: true,
            );

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: BuildingDetailContent(
                    building: building,
                    isAnnex: false,
                    startBuilding: null,
                    endBuilding: null,
                    onSetStart: () {},
                    onSetDestination: () {},
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            await tester.pumpAndSettle();

            expect(find.textContaining('B1'), findsOneWidget);
            expect(find.text('Test description'), findsOneWidget);
            expect(find.text('9-5'), findsOneWidget);
            expect(find.text('CS'), findsOneWidget);
            expect(find.text('Library'), findsOneWidget);

            expect(find.byIcon(Icons.accessible), findsOneWidget);
            expect(find.byIcon(Icons.pedal_bike), findsOneWidget);
            expect(find.byIcon(Icons.local_parking), findsOneWidget);
          });
    });

    testWidgets('search: empty query clears results and hides list',
            (WidgetTester tester) async {
          final b1 = buildTestBuilding(id: 'b1', name: 'HALL', fullName: 'Hall Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [b1]);
          when(mockDataParser.buildingsPresent).thenReturn([b1]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'hall');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(find.text('HALL'), findsOneWidget);

          // Empty/whitespace -> q.isEmpty branch
          await tester.enterText(find.byType(TextField), '   ');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();

          expect(find.text('HALL'), findsNothing);
        });

    testWidgets('search: matches fullName; list renders dividers; tapping field keeps list visible',
            (WidgetTester tester) async {
          final b1 = buildTestBuilding(id: 'b1', name: 'AAA', fullName: 'Hall Building');
          final b2 = buildTestBuilding(id: 'b2', name: 'BBB', fullName: 'Hall Annex');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [b1, b2]);
          when(mockDataParser.buildingsPresent).thenReturn([b1, b2]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          // Matches fullName (not name) -> line 185
          await tester.enterText(find.byType(TextField), 'hall');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();

          expect(find.text('AAA'), findsOneWidget);
          expect(find.text('BBB'), findsOneWidget);

          // 2 items -> separatorBuilder executes (line 801)
          expect(find.byType(Divider), findsWidgets);

          // Tap field when results exist -> onTap block (782–787)
          await tester.tap(find.byType(TextField));
          await tester.pump();

          expect(find.text('AAA'), findsOneWidget);
        });

    testWidgets('simulateBuildingTap(null) shows Not part of campus modal sheet',
            (WidgetTester tester) async {
          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find.byType(home_screen.HomeScreen).first);
          state.simulateBuildingTap(null);
          await tester.pumpAndSettle();

          expect(find.text('Not part of campus'), findsOneWidget);
          expect(find.text('Please select a shaded building'), findsOneWidget);
        });

    testWidgets('building sheet: set start then set destination updates directions',
            (WidgetTester tester) async {
          final startB = buildTestBuilding(id: 'b1', name: 'START', fullName: 'Start Building');
          final destB = buildTestBuilding(id: 'b2', name: 'DEST', fullName: 'Destination Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [startB, destB]);
          when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          // open START sheet
          await tester.enterText(find.byType(TextField), 'start');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tester.tap(find.text('START'));
          await tester.pumpAndSettle();

          // Set as Start -> covers 531–538 (+ sheet close path)
          await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.text('Directions'), findsOneWidget);

          // open DEST sheet
          await tester.enterText(find.byType(TextField), 'dest');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tester.tap(find.text('DEST'));
          await tester.pumpAndSettle();

          // Set as Destination -> covers 264–273 and 539–544
          await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Destination'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.textContaining('Destination Building'), findsOneWidget);
        });

    testWidgets('triggerPolygonOnTap runs Polygon.onTap closure',
            (WidgetTester tester) async {
          final building = buildTestBuilding(id: 'b1', name: 'B1', fullName: 'B1 Annex');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [building]);
          when(mockDataParser.buildingsPresent).thenReturn([building]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find.byType(home_screen.HomeScreen).first);
          state.lastTap = const LatLng(1, 1); // so _updateOnTap doesn't early return
          state.triggerPolygonOnTap(const PolygonId('b1'));

          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(BuildingDetailContent), findsOneWidget);
        });

    testWidgets('map Listener onPointerDown computes lastTap using controller.getLatLng',
            (WidgetTester tester) async {
          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find.byType(home_screen.HomeScreen).first);
          state.completeInternalMapController(FakeGoogleMapController());

          await tester.tapAt(const Offset(50, 200));
          await tester.pumpAndSettle();

          expect(state.lastTap, isNotNull);
        });

    testWidgets('GoogleMap onMapCreated completes controller when not completed',
            (WidgetTester tester) async {
          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
          map.onMapCreated!(FakeGoogleMapController());
          await tester.pump();

          expect(find.byType(GoogleMap), findsOneWidget);
        });

    testWidgets('GoogleMap onTap shows search results when results already exist',
            (WidgetTester tester) async {
          final b1 = buildTestBuilding(id: 'b1', name: 'HALL', fullName: 'Hall Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [b1]);
          when(mockDataParser.buildingsPresent).thenReturn([b1]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'hall');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(find.text('HALL'), findsOneWidget);

          final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
          map.onTap!(const LatLng(99, 99));
          await tester.pumpAndSettle();

          expect(find.text('HALL'), findsOneWidget);
        });

    testWidgets('_zoomToRoute executes when route exists',
            (WidgetTester tester) async {

          final startB = buildTestBuilding(
              id: 'b1', name: 'START', fullName: 'Start Building');
          final destB = buildTestBuilding(
              id: 'b2', name: 'DEST', fullName: 'Destination Building');

          when(mockDataParser.getBuildingInfoFromJSON())
              .thenAnswer((_) async => [startB, destB]);
          when(mockDataParser.buildingsPresent)
              .thenReturn([startB, destB]);

          final fakeMapController = FakeGoogleMapController();
          final mapCompleter = Completer<GoogleMapController>();
          mapCompleter.complete(fakeMapController);

          final fakeDirections = DirectionsController(
            client: FakeDirectionsClient.success(
              const RouteResult(
                polylinePoints: [LatLng(45, -73), LatLng(46, -74)],
                durationText: '5 mins',
                distanceText: '1 km',
              ),
            ),
          );

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
            testMapControllerCompleter: mapCompleter,
            testDirectionsController: fakeDirections,
          )));

          await tester.pumpAndSettle();

          final dynamic state = tester.state<HomeScreenState>(
            find.byType(home_screen.HomeScreen).first,
          );

          state.simulateBuildingSelection(
            startB,
            const LatLng(45.0, -73.0),
          );
          await tester.pumpAndSettle();

          expect(find.text('Set as Start'), findsOneWidget);
          await tester.tap(find.text('Set as Start'));
          await tester.pumpAndSettle();

          state.simulateBuildingSelection(
            destB,
            const LatLng(46.0, -74.0),
          );
          await tester.pumpAndSettle();

          expect(find.text('Set as Destination'), findsOneWidget);
          await tester.tap(find.text('Set as Destination'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(fakeDirections.state.polyline, isNotNull);
        });

    testWidgets('GPS polygon selection comparison executes',
            (WidgetTester tester) async {

          final gpsBuilding = buildTestBuilding(
              id: 'gps1', name: 'GPS', fullName: 'GPS Building');

          final otherBuilding = buildTestBuilding(
              id: 'other', name: 'Other', fullName: 'Other Building');

          when(mockDataParser.getBuildingInfoFromJSON())
              .thenAnswer((_) async => [gpsBuilding, otherBuilding]);

          when(mockDataParser.buildingsPresent)
              .thenReturn([gpsBuilding, otherBuilding]);

          await tester.pumpWidget(
            wrap(HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            )),
          );

          await tester.pumpAndSettle();

          final state = tester.state<HomeScreenState>(
            find.byType(HomeScreen),
          ) as dynamic;


          state.setCurrentBuildingFromGPS(gpsBuilding);


          await tester.pump(); // triggers polygon rebuild

          expect(find.byType(GoogleMap), findsOneWidget);
        });

    testWidgets('E2E label renders when isE2EMode is true', (WidgetTester tester) async {
      main_app.isE2EMode = true;
      addTearDown(() => main_app.isE2EMode = false);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("campus_label")), findsOneWidget);
      expect(find.textContaining("campus:"), findsOneWidget);
    });

    testWidgets('UseAsStart button sets start building and updates directions', (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'B1',
        boundary: const [
          LatLng(45.0, -73.0),
          LatLng(45.0, -74.0),
          LatLng(46.0, -74.0),
          LatLng(46.0, -73.0),
          LatLng(45.0, -73.0),
        ],
      );
      when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      // Mock GPS location is (45.4972, -73.5788), which is inside the above boundary.
      when(mockBuildingLocator.update(
        userPoint: anyNamed('userPoint'),
        campus: anyNamed('campus'),
        buildings: anyNamed('buildings'),
      )).thenReturn(BuildingStatus(building: building, treatedAsInside: true));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final state = tester.state<HomeScreenState>(
        find.byType(home_screen.HomeScreen),
      ) as dynamic;

      state.simulateBuildingSelection(building, const LatLng(45.1, -73.1));


      await tester.pumpAndSettle();

// press start button
      await tester.tap(find.text('Set as Start'));
      await tester.pumpAndSettle();


      // Should show directions card
      expect(find.text('Directions'), findsOneWidget);
    });

    testWidgets('polygon selection with GPS building hits selection logic branches', (WidgetTester tester) async {
      final gpsB = buildTestBuilding(id: 'gps', name: 'GPS');
      final targetB = buildTestBuilding(id: 'target', name: 'Target');

      when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [gpsB, targetB]);
      when(mockDataParser.buildingsPresent).thenReturn([gpsB, targetB]);

      await tester.pumpWidget(wrap(HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.setCurrentBuildingFromGPS(gpsB);
      await tester.pump();

      // Now tap targetB. This calls _updateOnTap -> _applyPolygonSelection.
      state.lastTap = const LatLng(1, 1);
      state.triggerPolygonOnTap(const PolygonId('target'));
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
    });

    testWidgets('polygon color branch when gps building matches polygon',
            (WidgetTester tester) async {

          final gpsB = buildTestBuilding(id: 'b1', name: 'GPS');

          when(mockDataParser.getBuildingInfoFromJSON())
              .thenAnswer((_) async => [gpsB]);
          when(mockDataParser.buildingsPresent)
              .thenReturn([gpsB]);

          await tester.pumpWidget(wrap(HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));

          await tester.pumpAndSettle();

          final dynamic state = tester.state(find.byType(HomeScreen));

          state.setCurrentBuildingFromGPS(gpsB);

          await tester.pump();

          // rebuild polygons
          state.triggerPolygonOnTap(const PolygonId('b1'));

          await tester.pumpAndSettle();

          expect(find.byType(GoogleMap), findsOneWidget);
        });
      test('boundsForRoute computes southwest and northeast correctly', () {
        final a = const LatLng(45.0, -73.0);
        final b = const LatLng(46.0, -74.0);

        final bounds = home_screen.boundsForRoute(a, b);

        expect(bounds.southwest.latitude, 45.0);
        expect(bounds.southwest.longitude, -74.0);
        expect(bounds.northeast.latitude, 46.0);
        expect(bounds.northeast.longitude, -73.0);
      });

    testWidgets('zoomToRouteForTest animates camera', (WidgetTester tester) async {
      final fakeMapController = FakeGoogleMapController();
      final mapCompleter = Completer<GoogleMapController>()
        ..complete(fakeMapController);

      await tester.pumpWidget(
        wrap(home_screen.HomeScreen(
          dataParser: mockDataParser,
          buildingLocator: mockBuildingLocator,
          testMapControllerCompleter: mapCompleter,
        )),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state<HomeScreenState>(
        find.byType(home_screen.HomeScreen).first,
      );

      await state.zoomToRouteForTest(
        const LatLng(45.0, -73.0),
        const LatLng(46.0, -74.0),
      );
      await tester.pumpAndSettle();

      expect(fakeMapController.animateCameraCallCount, 1);
      expect(fakeMapController.lastCameraUpdate, isNotNull);
    });

    test('boundsForRoute handles reversed coordinates', () {
      final a = const LatLng(46.0, -74.0);
      final b = const LatLng(45.0, -73.0);
      //same thing just swapped the values to test another path

      final bounds = home_screen.boundsForRoute(a, b);

      expect(bounds.southwest.latitude, 45.0);
      expect(bounds.southwest.longitude, -74.0);
      expect(bounds.northeast.latitude, 46.0);
      expect(bounds.northeast.longitude, -73.0);
    });
  });
}
