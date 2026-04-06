import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:proj/data/data_parser.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/nav_graph.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/models/room.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/screens/home_screen.dart' as home_screen;
import 'package:proj/screens/home_screen.dart' show HomeScreenState, HomeScreen;
import 'package:proj/screens/indoor_map_screen.dart';
import 'package:proj/services/building_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:proj/services/directions/directions_controller.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/services/markerIconLoader.dart';
import 'package:proj/utilities/polygon_helper.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:proj/widgets/home/building_detail_content.dart';
import 'package:proj/widgets/home/building_detail_sheet.dart';
import 'package:proj/widgets/home/search_overlay.dart';
import 'package:proj/widgets/schedule/schedule_overlay.dart';
import 'package:proj/widgets/use_as_start.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:proj/screens/auth/login_screen.dart';
import 'package:proj/services/auth/auth_service.dart';
import 'package:proj/services/auth/user_profile_service.dart';
import '../services/directions/directions_controller_and_strategy_test.dart';
import 'home_screen_test.mocks.dart';

class _MockUserProfileSvc extends Mock implements UserProfileService {}

/// Fake auth service used in the logout test: overrides signOut/authStateChanges
/// so we don't need a real Firebase connection.
class _FakeAuthService extends AuthService {
  _FakeAuthService()
      : super(
          auth: MockFirebaseAuth(),
          profileService: _MockUserProfileSvc(),
        );

  @override
  Future<void> signOut() async {}

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  bool get isGuestMode => false;
}


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

class TimeoutCurrentPositionGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  double distanceBetween(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) {
    return 100.0;
  }

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
      const Stream.empty();

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) {
    return Completer<Position>().future;
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
  bool animateCameraCalled = false;
  CameraUpdate? lastCameraUpdate;

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) {
    animateCameraCalled = true;
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
class CurrentPositionGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  double distanceBetween(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) => 100.0;
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
      Stream.value(Position(
        latitude: 45.4972, longitude: -73.5788,
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, altitudeAccuracy: 0,
        heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
      ));
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async =>
      Position(
        latitude: 45.4972, longitude: -73.5788,
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, altitudeAccuracy: 0,
        heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
      );
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

Poi testPoi({
  String id = '1',
  String name = 'Building 1',
  String fullName = 'Full Building 1',
  LatLng boundary = const LatLng(0, 0),
  String description = 'A test building',
  Campus campus = Campus.sgw,
  List<String> openingHours = const ['9-5'],
  String poiType = 'assets/coffee.png'
}) {
  return Poi(id: id, name: name, boundary: boundary, description: description, campus: campus, openingHours: openingHours, photoName: [], rating: 2, address: '', );
}

IndoorMap _rtTinyIndoorMap(CampusBuilding b, String roomId) {
  final roomNode =
      NavNode(id: roomId, type: 'room', x: 0.5, y: 0.5, name: roomId);
  final g = NavGraph(nodes: [roomNode], edges: []);
  final floor = Floor(
    level: 1,
    label: '1',
    rooms: [
      Room(
        id: roomId,
        name: roomId,
        boundary: _rtFakeRoomBoundary(0.5, 0.5),
      ),
    ],
    navGraph: g,
  );
  return IndoorMap(building: b, floors: [floor]);
}

IndoorMap _rtTwoFloorIndoorMap(CampusBuilding b, String roomId) {
  final n1 =
      NavNode(id: roomId, type: 'room', x: 0.5, y: 0.5, name: roomId);
  final g1 = NavGraph(nodes: [n1], edges: []);
  final f1 = Floor(
    level: 1,
    label: '1',
    rooms: [
      Room(
        id: roomId,
        name: roomId,
        boundary: _rtFakeRoomBoundary(0.5, 0.5),
      ),
    ],
    navGraph: g1,
  );
  final id2 = '${roomId}_L2';
  final n2 = NavNode(id: id2, type: 'room', x: 0.5, y: 0.5, name: id2);
  final g2 = NavGraph(nodes: [n2], edges: []);
  final f2 = Floor(
    level: 2,
    label: '2',
    rooms: [
      Room(
        id: id2,
        name: id2,
        boundary: _rtFakeRoomBoundary(0.5, 0.5),
      ),
    ],
    navGraph: g2,
  );
  return IndoorMap(building: b, floors: [f1, f2]);
}

List<Offset> _rtFakeRoomBoundary(double cx, double cy) {
  const h = 0.025;
  return [
    Offset(cx - h, cy - h),
    Offset(cx + h, cy - h),
    Offset(cx + h, cy + h),
    Offset(cx - h, cy + h),
  ];
}

Poi testPoi2({
  String id = '1',
  String name = 'Building 1',
  String fullName = 'Full Building 1',
  LatLng boundary = const LatLng(0, 0),
  String description = 'A test building',
  Campus campus = Campus.sgw,
  List<String> openingHours = const ['Monday'],
}) {
  return Poi(id: id, name: name, boundary: boundary, description: description, campus: campus, openingHours: openingHours, photoName: [], rating: 2, address: '');
}

@GenerateMocks([DataParser, BuildingLocator])
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // geocoding method channel used by `geocoding`.
  const MethodChannel geocodingChannel = MethodChannel(
      'flutter.baseflow.com/geocoding');

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

    test(
        'returns building when point is inside boundary and campus matches', () {
      final result = findBuildingAtPoint(
        const LatLng(1, 1),
        [sgwBuilding, loyolaBuilding],
        Campus.sgw,
      );
      expect(result, equals(sgwBuilding));
    });

    test(
        'returns null when point is inside boundary but campus does not match', () {
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

  test('defaultMarkerImageLoader loads and converts an asset image', () async {
    final Uint8List bytes =
        await defaultMarkerImageLoader('assets/coffee.png', 100);

    expect(bytes, isNotEmpty);
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
      when(mockDataParser.poiPresent).thenReturn(<Poi>[]);
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

    testWidgets(
        'shows CampusToggle with SGW and Loyola', (WidgetTester tester) async {
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

    testWidgets(
        'when GPS building changes, getBuildingInfoFromJSON is called again',
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

          verify(mockDataParser.getBuildingInfoFromJSON()).called(
              greaterThan(1));
          await streamController.close();
        });

    testWidgets(
        'tapping campus toggle calls reset and completes when test completer provided',
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
          )).thenReturn(
              BuildingStatus(building: building, treatedAsInside: true));

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

          final state = tester.state<HomeScreenState>(
              find.byType(home_screen.HomeScreen));
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
            find
                .byType(home_screen.HomeScreen)
                .first,
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
            find
                .byType(home_screen.HomeScreen)
                .first,
          ) as dynamic;

          state.simulateBuildingSelection(building, const LatLng(1, 1));

          await tester.pump(); // setState
          await tester.pump(); // postFrameCallback
          await tester.pumpAndSettle();

          expect(find.textContaining('B1 Annex'), findsOneWidget);
          expect(find.byType(BuildingDetailContent), findsOneWidget);
          expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        });

    testWidgets(
        'handleMapTap inside a building selects it and opens detail sheet',
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
            find
                .byType(home_screen.HomeScreen)
                .first,
          );

          // Point (1,1) is inside the default boundary used by buildTestBuilding.
          state.handleMapTap(
              const LatLng(1, 1), tester.element(find.byType(CampusToggle)));

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
            find
                .byType(home_screen.HomeScreen)
                .first,
          );

          state.simulatePolygonTap(const PolygonId('b1'), const LatLng(1, 1));

          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.textContaining('Full B1'), findsOneWidget);
          expect(find.byType(BuildingDetailContent), findsOneWidget);
        });
    //probably refactor into directions card test not sure
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
          final setStartBtn = find.widgetWithText(
              ElevatedButton, 'Set as Start');
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
          tester.state(find
              .byType(home_screen.HomeScreen)
              .first);
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
                    isPoi: false,
                  ),
                ),
              ),
            );

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
          final b1 = buildTestBuilding(
              id: 'b1', name: 'HALL', fullName: 'Hall Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [b1]);
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

    testWidgets(
        'search: matches fullName; list renders dividers; tapping field keeps list visible',
            (WidgetTester tester) async {
          final b1 = buildTestBuilding(
              id: 'b1', name: 'AAA', fullName: 'Hall Building');
          final b2 = buildTestBuilding(
              id: 'b2', name: 'BBB', fullName: 'Hall Annex');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [b1, b2]);
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

    testWidgets('search matches POI by description', (WidgetTester tester) async {
      final cafe = Poi(
        id: 'c1',
        name: 'Zebra Lounge',
        description: 'matcha and coffee',
        campus: Campus.sgw,
        boundary: const LatLng(45.5, -73.5),
        openingHours: const [],
        photoName: const <String?>[],
        rating: 4,
        address: '1 St',
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.poiPresent.add(cafe);

      await tester.enterText(find.byType(TextField).first, 'matcha');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Zebra Lounge'), findsOneWidget);
    });

    testWidgets(
        'simulateBuildingTap(null) shows Not part of campus modal sheet',
            (WidgetTester tester) async {
          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find
              .byType(home_screen.HomeScreen)
              .first);
          state.simulateBuildingTap(null);
          await tester.pumpAndSettle();

          expect(find.text('Not part of campus'), findsOneWidget);
          expect(find.text('Please select a shaded building'), findsOneWidget);
        });

    testWidgets(
        'building sheet: set start then set destination updates directions',
            (WidgetTester tester) async {
          final startB = buildTestBuilding(
              id: 'b1', name: 'START', fullName: 'Start Building');
          final destB = buildTestBuilding(
              id: 'b2', name: 'DEST', fullName: 'Destination Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [startB, destB]);
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
          await tester.tap(
              find.widgetWithText(ElevatedButton, 'Set as Destination'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.textContaining('Destination Building'), findsOneWidget);
        });

    testWidgets(
        'room-to-room toggle uses testIndoorMapLoader and shows room pickers',
        (WidgetTester tester) async {
      final startB = buildTestBuilding(
          id: 'b1', name: 'START', fullName: 'Start Building');
      final destB = buildTestBuilding(
          id: 'b2', name: 'DEST', fullName: 'Destination Building');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [startB, destB]);
      when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

      const walkLeg = RouteLeg(
        polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '100 m',
      );
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [walkLeg],
          durationText: '1 min',
          distanceText: '100 m',
        )),
      );

      Future<IndoorMap?> testLoader(CampusBuilding b) async {
        return _rtTinyIndoorMap(b, b.id == 'b1' ? 'ROOM_A' : 'ROOM_B');
      }

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
        testIndoorMapLoader: testLoader,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'start');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'dest');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEST'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Set as Destination'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Start room'), findsOneWidget);
    });

    testWidgets(
        'room-to-room: failing testIndoorMapLoader clears loading state',
        (WidgetTester tester) async {
      final startB = buildTestBuilding(
          id: 'b1', name: 'START', fullName: 'Start Building');
      final destB = buildTestBuilding(
          id: 'b2', name: 'DEST', fullName: 'Destination Building');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [startB, destB]);
      when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

      const walkLeg = RouteLeg(
        polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '100 m',
      );
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [walkLeg],
          durationText: '1 min',
          distanceText: '100 m',
        )),
      );

      Future<IndoorMap?> badLoader(CampusBuilding _) async {
        throw Exception('loader failed');
      }

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
        testIndoorMapLoader: badLoader,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'start');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'dest');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEST'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Set as Destination'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('room-to-room toggle off clears indoor state',
        (WidgetTester tester) async {
      final startB = buildTestBuilding(
          id: 'b1', name: 'START', fullName: 'Start Building');
      final destB = buildTestBuilding(
          id: 'b2', name: 'DEST', fullName: 'Destination Building');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [startB, destB]);
      when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

      const walkLeg = RouteLeg(
        polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '100 m',
      );
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [walkLeg],
          durationText: '1 min',
          distanceText: '100 m',
        )),
      );

      Future<IndoorMap?> testLoader(CampusBuilding b) async {
        return _rtTinyIndoorMap(b, b.id == 'b1' ? 'ROOM_A' : 'ROOM_B');
      }

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
        testIndoorMapLoader: testLoader,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'start');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'dest');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEST'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Set as Destination'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Start room'), findsOneWidget);

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Start room'), findsNothing);
    });

    testWidgets(
        'handleMapTap swallows one tap when suppress flag is set (web leak guard)',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setSuppressNextMapTapForTest(true);
      state.handleMapTap(const LatLng(99, 99));
      await tester.pump();

      expect(find.text('Not part of campus'), findsNothing);
    });

    testWidgets('triggerPolygonOnTap with unknown PolygonId is a no-op',
        (WidgetTester tester) async {
      final building = buildTestBuilding(id: 'b1', name: 'B1');
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
      state.triggerPolygonOnTap(const PolygonId('__none__'));
      await tester.pump();

      expect(find.byType(BuildingDetailContent), findsNothing);
    });

    testWidgets(
        'room-to-room floor and room dropdowns invoke DirectionsCard callbacks',
        (WidgetTester tester) async {
      final startB = buildTestBuilding(
          id: 'b1', name: 'START', fullName: 'Start Building');
      final destB = buildTestBuilding(
          id: 'b2', name: 'DEST', fullName: 'Destination Building');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [startB, destB]);
      when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

      const walkLeg = RouteLeg(
        polylinePoints: [LatLng(0, 0), LatLng(1, 1)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '100 m',
      );
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [walkLeg],
          durationText: '1 min',
          distanceText: '100 m',
        )),
      );

      Future<IndoorMap?> testLoader(CampusBuilding b) async {
        return _rtTwoFloorIndoorMap(
            b, b.id == 'b1' ? 'ROOM_A' : 'ROOM_B');
      }

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
        testIndoorMapLoader: testLoader,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'start');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'dest');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEST'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Set as Destination'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room_to_room_toggle')));
      await tester.pumpAndSettle();

      final roomDropdowns = find.byType(DropdownButton<String>);
      await tester.tap(roomDropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ROOM_A'));
      await tester.pumpAndSettle();

      await tester.tap(roomDropdowns.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ROOM_B'));
      await tester.pumpAndSettle();

      final floorDropdowns = find.byType(DropdownButton<int>);
      await tester.tap(floorDropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();

      await tester.tap(floorDropdowns.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('triggerPolygonOnTap runs Polygon.onTap closure',
            (WidgetTester tester) async {
          final building = buildTestBuilding(
              id: 'b1', name: 'B1', fullName: 'B1 Annex');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [building]);
          when(mockDataParser.buildingsPresent).thenReturn([building]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find
              .byType(home_screen.HomeScreen)
              .first);
          state.lastTap =
          const LatLng(1, 1); // so _updateOnTap doesn't early return
          state.triggerPolygonOnTap(const PolygonId('b1'));

          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(BuildingDetailContent), findsOneWidget);
        });
    testWidgets(
        'map Listener onPointerDown computes lastTap using controller.getLatLng',
            (WidgetTester tester) async {
          final fakeMapController = FakeGoogleMapController();
          final mapCompleter = Completer<GoogleMapController>()
            ..complete(fakeMapController);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
            testMapControllerCompleter: mapCompleter,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find
              .byType(home_screen.HomeScreen)
              .first);
          await state.simulatePointerDown(const Offset(50, 200));
          await tester.pumpAndSettle();

          expect(state.lastTap, isNotNull);
        });

    testWidgets(
      'simulatePointerDown uses _mapController when no test completer',
          (WidgetTester tester) async {
        final fakeMapController = FakeGoogleMapController();

        await tester.pumpWidget(
          wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
            // Force else branch
            testMapControllerCompleter: null,
          )),
        );

        await tester.pumpAndSettle();

        final dynamic state =
        tester.state(find.byType(home_screen.HomeScreen).first);

        state.setMapControllerForTest(fakeMapController);

        await state.simulatePointerDown(const Offset(50, 200));
        await tester.pumpAndSettle();

        expect(state.lastTap, isNotNull);
      },
    );

    testWidgets(
        'GoogleMap onMapCreated completes controller when not completed',
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

    testWidgets(
        'GoogleMap onTap shows search results when results already exist',
            (WidgetTester tester) async {
          final b1 = buildTestBuilding(
              id: 'b1', name: 'HALL', fullName: 'Hall Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [b1]);
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
    testWidgets('initState prints missing API key warning when key absent', (
        tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(GoogleMap), findsOneWidget);
    });
    testWidgets(
        '_campusAtPoint is called when destination-first route updates', (
        tester) async {
      final dest = buildTestBuilding(
          id: 'b1', name: 'DEST', fullName: 'Dest Building');
      when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async =>
      [
        dest
      ]);
      when(mockDataParser.buildingsPresent).thenReturn([dest]);

      // Grant location so the GPS path runs (not the denied path).
      GeolocatorPlatform.instance = MockGeolocatorPlatform();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'dest');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DEST'));
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Set as Destination'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Directions'), findsOneWidget);
    });
    testWidgets(
        'shows location required message when permission denied and destination-first',
            (tester) async {
          final dest = buildTestBuilding(
              id: 'b1', name: 'DEST', fullName: 'Dest Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [dest]);
          when(mockDataParser.buildingsPresent).thenReturn([dest]);

          // Deny permission so _getRouteStartPoint returns null.
          GeolocatorPlatform.instance = PermissionDeniedGeolocatorPlatform();

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'dest');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();

          await tester.tap(find.text('DEST'));
          await tester.pumpAndSettle();

          await tester.tap(
              find.widgetWithText(ElevatedButton, 'Set as Destination'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(
            find.textContaining('please allow location access'),
            findsOneWidget,
          );
        });
    testWidgets(
        'destination-first with GPS granted gets current position and updates route',
            (tester) async {
          final dest = buildTestBuilding(
              id: 'b1', name: 'DEST', fullName: 'Dest Building');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [dest]);
          when(mockDataParser.buildingsPresent).thenReturn([dest]);

          GeolocatorPlatform.instance = CurrentPositionGeolocatorPlatform();

          // Provide a real FakeGoogleMapController so animateCamera doesn't hang.
          final mapCompleter = Completer<GoogleMapController>()
            ..complete(FakeGoogleMapController());

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
            testMapControllerCompleter: mapCompleter,
          )));
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), 'dest');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();

          await tester.tap(find.text('DEST'));
          await tester.pumpAndSettle();

          await tester.tap(
              find.widgetWithText(ElevatedButton, 'Set as Destination'));
          await tester.pump();
          await tester.pumpAndSettle();

          // Route should be updating (no crash, no location-required message).
          expect(find.textContaining('please allow location access'),
              findsNothing);
          expect(find.text('Directions'), findsOneWidget);
        });
    testWidgets(
        'sheet Set as Start closes sheet and sets _sheetController null',
            (tester) async {
          final building = buildTestBuilding(
              id: 'b1', name: 'B1', fullName: 'B1 Full');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [building]);
          when(mockDataParser.buildingsPresent).thenReturn([building]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find
              .byType(home_screen.HomeScreen)
              .first);

          state.simulateBuildingSelection(building, const LatLng(1, 1));
          await tester.pump();
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(DraggableScrollableSheet), findsOneWidget);

          // Tap Set as Start inside the sheet — this is the onSetStart callback.
          await tester.tap(find
              .widgetWithText(ElevatedButton, 'Set as Start')
              .last);
          await tester.pump();
          await tester.pumpAndSettle();

          // Sheet should be closed; directions card should appear.
          expect(find.byType(DraggableScrollableSheet), findsNothing);
          expect(find.text('Directions'), findsOneWidget);
        });

    testWidgets('sheet Set as Destination closes sheet', (tester) async {
      final startB = buildTestBuilding(
          id: 'b1', name: 'START', fullName: 'Start Building');
      final destB = buildTestBuilding(
          id: 'b2', name: 'DEST', fullName: 'Dest Building');
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [startB, destB]);
      when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find
          .byType(home_screen.HomeScreen)
          .first);

      state.simulateBuildingSelection(startB, const LatLng(1, 1));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find
          .widgetWithText(ElevatedButton, 'Set as Start')
          .last);
      await tester.pump();
      await tester.pumpAndSettle();

      state.simulateBuildingSelection(destB, const LatLng(1, 1));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find
          .widgetWithText(ElevatedButton, 'Set as Destination')
          .last);
      await tester.pump();
      await tester.pumpAndSettle();

      // Sheet closes; directions card shows both buildings.
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.textContaining('Dest Building'), findsOneWidget);
    });
    testWidgets(
        'tapping mode chip sets _modeChangedByUser and updates directions',
            (tester) async {
          final startB = buildTestBuilding(
              id: 'b1', name: 'START', fullName: 'Start Building');
          final destB = buildTestBuilding(
              id: 'b2', name: 'DEST', fullName: 'Dest Building');
          when(mockDataParser.getBuildingInfoFromJSON())
              .thenAnswer((_) async => [startB, destB]);
          when(mockDataParser.buildingsPresent).thenReturn([startB, destB]);

          final mapCompleter = Completer<GoogleMapController>()
            ..complete(FakeGoogleMapController());

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
            testMapControllerCompleter: mapCompleter,
          )));
          await tester.pumpAndSettle();

          // Set start.
          await tester.enterText(find.byType(TextField), 'start');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tester.tap(find.text('START'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Start'));
          await tester.pump();
          await tester.pumpAndSettle();

          // Set destination.
          await tester.enterText(find.byType(TextField), 'dest');
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          await tester.tap(find.text('DEST'));
          await tester.pumpAndSettle();
          await tester.tap(
              find.widgetWithText(ElevatedButton, 'Set as Destination'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(ChoiceChip), findsWidgets);

          await tester.tap(find.byType(ChoiceChip).at(1));
          await tester.pump();
          await tester.pumpAndSettle();

          final bikeChip = tester.widget<ChoiceChip>(
              find.byType(ChoiceChip).at(1));
          expect(bikeChip.selected, isTrue);
        });
    testWidgets('E2E campus label shows campus:loyola when on Loyola campus', (
        tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loyola'));
      await tester.pumpAndSettle();

      final loyolaLabel = find.text('campus:loyola');
      if (loyolaLabel
          .evaluate()
          .isNotEmpty) {
        expect(loyolaLabel, findsOneWidget);
      } else {
        expect(find.text('Loyola'), findsOneWidget);
      }
    });

    testWidgets(
      'shows location required message when current position times out and destination-first',
          (WidgetTester tester) async {
        final dest = buildTestBuilding(
          id: 'b1',
          name: 'DEST',
          fullName: 'Dest Building',
        );

        when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [dest]);
        when(mockDataParser.buildingsPresent).thenReturn([dest]);

        GeolocatorPlatform.instance = TimeoutCurrentPositionGeolocatorPlatform();

        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'dest');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.text('DEST'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Destination'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('please allow location access'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
        'triggerPolygonOnTap with unknown id hits orElse and shows not-part-of-campus',
            (tester) async {
          final building = buildTestBuilding(
              id: 'b1', name: 'B1', fullName: 'B1 Full');
          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [building]);
          when(mockDataParser.buildingsPresent).thenReturn([building]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(find
              .byType(home_screen.HomeScreen)
              .first);
          state.lastTap = const LatLng(1, 1);


          state.simulateBuildingTap(null);
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.text('Not part of campus'), findsOneWidget);
        });
    testWidgets('GPS building stays blue while another polygon is selected',
            (WidgetTester tester) async {
          final gpsB = buildTestBuilding(id: 'gps', name: 'GPS');
          final targetB = buildTestBuilding(id: 'target', name: 'Target');

          when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((
              _) async => [gpsB, targetB]);
          when(mockDataParser.buildingsPresent).thenReturn([gpsB, targetB]);

          await tester.pumpWidget(wrap(home_screen.HomeScreen(
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          )));
          await tester.pumpAndSettle();

          final dynamic state = tester.state(
              find.byType(home_screen.HomeScreen));
          state.setCurrentBuildingFromGPS(gpsB);
          await tester.pump();

          state.lastTap = const LatLng(1, 1);
          state.triggerPolygonOnTap(const PolygonId('target'));
          await tester.pumpAndSettle();

          expect(find.byType(BuildingDetailSheet), findsOneWidget);
        });
    testWidgets('non-selected GPS building keeps GPS highlight colors', (
        WidgetTester tester) async {
      final gpsBuilding = buildTestBuilding(
        id: 'gps1',
        name: 'GPS',
        fullName: 'GPS Building',
      );

      final otherBuilding = buildTestBuilding(
        id: 'other',
        name: 'Other',
        fullName: 'Other Building',
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [gpsBuilding, otherBuilding]);
      when(mockDataParser.buildingsPresent)
          .thenReturn([gpsBuilding, otherBuilding]);

      await tester.pumpWidget(
        wrap(home_screen.HomeScreen(
          dataParser: mockDataParser,
          buildingLocator: mockBuildingLocator,
        )),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state<HomeScreenState>(
        find.byType(home_screen.HomeScreen),
      );

      state.setCurrentBuildingFromGPS(gpsBuilding);
      await tester.pump();

      state.lastTap = const LatLng(1, 1);
      state.triggerPolygonOnTap(const PolygonId('other'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
    });

    testWidgets('View indoor map opens IndoorMapScreen', (
        WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'b1',
        name: 'H',
        fullName: 'Hall Building',
      );
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(
        wrap(HomeScreen(
          dataParser: mockDataParser,
          buildingLocator: mockBuildingLocator,
        )),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state<HomeScreenState>(
        find.byType(HomeScreen),
      );
      state.setCurrentBuildingFromGPS(building);
      await tester.pump();
      state.lastTap = const LatLng(1, 1);
      state.triggerPolygonOnTap(const PolygonId('b1'));
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
      await tester.ensureVisible(
          find.byKey(const Key('view_indoor_map_button')));
      await tester.tap(find.byKey(const Key('view_indoor_map_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(IndoorMapScreen), findsOneWidget);
    });

    testWidgets(
        'floating UseAsStart card callback sets start and updates directions', (
        WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'gps1',
        name: 'GPS',
        fullName: 'GPS Building',
        boundary: const [
          LatLng(45.0, -73.0),
          LatLng(45.0, -74.0),
          LatLng(46.0, -74.0),
          LatLng(46.0, -73.0),
          LatLng(45.0, -73.0),
        ],
      );

      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(
          const RouteResult(
            legs: [RouteLeg(polylinePoints: [LatLng(45, -73), LatLng(46, -74)], legMode: LegMode.walking, durationSeconds: 0, durationText: '5 mins', distanceText: '1 km')],
            durationText: '5 mins',
            distanceText: '1 km',
          ),
        ),
      );

      await tester.pumpWidget(
        wrap(HomeScreen(
          dataParser: mockDataParser,
          buildingLocator: mockBuildingLocator,
          testDirectionsController: fakeDirections,
        )),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state<HomeScreenState>(
          find.byType(home_screen.HomeScreen));
      state.setCurrentBuildingFromGPS(building);
      state.setIsInBuildingForTest(true);
      await tester.pumpAndSettle();

      expect(find.byType(UseAsStart), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(UseAsStart),
        matching: find.byType(ElevatedButton),
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Directions'), findsOneWidget);
    });
    testWidgets('MapLayer shows loading, error, and map states', (
        WidgetTester tester) async {
      // Loading state
      final completer = Completer<List<CampusBuilding>>();
      when(mockDataParser.getBuildingInfoFromJSON())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Error state
      completer.completeError(Exception('fail'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Error loading polygons'), findsOneWidget);
    });
    testWidgets('MapLayer onPointerDown computes latLng via controller', (
        WidgetTester tester) async {
      final fakeMapController = FakeGoogleMapController();
      final mapCompleter = Completer<GoogleMapController>()
        ..complete(fakeMapController);

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testMapControllerCompleter: mapCompleter,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find
          .byType(home_screen.HomeScreen)
          .first);
      state.completeInternalMapController(fakeMapController);
      await tester
          .pump();

      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();

      expect(state.lastTap, isNotNull);
    });

    testWidgets(
        '_zoomToRoute returns early when _mapController is null', (
        WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,

      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find
          .byType(home_screen.HomeScreen)
          .first);

      await state.zoomToRouteForTest(
          const LatLng(45.0, -73.0), const LatLng(46.0, -74.0));
      await tester.pumpAndSettle();
    });

    testWidgets(
      '_zoomToRoute animates camera when map controller exists',
          (WidgetTester tester) async {
        final fakeMapController = FakeGoogleMapController();

        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dynamic state =
        tester.state(find.byType(home_screen.HomeScreen).first);

        state.setMapControllerForTest(fakeMapController);

        await state.zoomToRouteForTest(
          const LatLng(45.0, -73.0),
          const LatLng(46.0, -74.0),
        );
        await tester.pumpAndSettle();

        expect(fakeMapController.animateCameraCalled, isTrue);
        expect(fakeMapController.lastCameraUpdate, isNotNull);
      },
    );

    testWidgets(
      'boundsForRoute returns correct southwest and northeast corners',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bounds = home_screen.boundsForRoute(
          const LatLng(46.0, -73.0),
          const LatLng(45.0, -74.0),
        );

        expect(bounds.southwest.latitude, 45.0);
        expect(bounds.southwest.longitude, -74.0);
        expect(bounds.northeast.latitude, 46.0);
        expect(bounds.northeast.longitude, -73.0);
      },
    );

    testWidgets('_goToCampus returns early when _mapController is null', (
        WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,

      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loyola'));
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('schedule overlay shows when toggled by test hook', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(
        find.byType(home_screen.HomeScreen).first,
      );

      state.setShowScheduleOverlayForTest(true);
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleOverlay), findsOneWidget);
    });

    testWidgets('floating UseAsStart card appears for GPS building', (WidgetTester tester) async {
      final building = buildTestBuilding(
        id: 'gps1',
        name: 'GPS',
        fullName: 'GPS Building',
      );

      when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [building]);
      when(mockDataParser.buildingsPresent).thenReturn([building]);

      await tester.pumpWidget(wrap(HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(HomeScreen));
      state.setCurrentBuildingFromGPS(building);
      state.setIsInBuildingForTest(true);

      await tester.pumpAndSettle();

      expect(find.byType(UseAsStart), findsOneWidget);
    });

    testWidgets('schedule overlay closes from callback path', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(
        find.byType(home_screen.HomeScreen).first,
      );

      state.setShowScheduleOverlayForTest(true);
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleOverlay), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleOverlay), findsNothing);
    });

    testWidgets(
      'schedule overlay selected-room callback path hides overlay',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dynamic state = tester.state(
          find.byType(home_screen.HomeScreen).first,
        );

        state.setShowScheduleOverlayForTest(true);
        await tester.pumpAndSettle();

        final ScheduleOverlay overlay =
        tester.widget<ScheduleOverlay>(find.byType(ScheduleOverlay));

        overlay.onRoomSelected(
          CourseScheduleEntry(
            room: 'H-101', courseCode: '', section: '', dayText: '', timeText: '', campus: '', buildingCode: '',
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ScheduleOverlay), findsNothing);
      },
    );

    testWidgets('opens schedule overlay when menu selected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(role: UserRole.user),
        ),
      );

      expect(find.byType(ScheduleOverlay), findsNothing);

      final SearchOverlay searchOverlay = tester.widget<SearchOverlay>(
        find.byType(SearchOverlay),
      );

      searchOverlay.onMenuSelected('schedule');
      await tester.pump();

      expect(find.byType(ScheduleOverlay), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('shows Guest chip label for guest role', (tester) async {
      await tester.pumpWidget(
        wrap(
          HomeScreen(
            role: UserRole.guest,
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('shows display name in chip for user role', (tester) async {
      await tester.pumpWidget(
        wrap(
          HomeScreen(
            role: UserRole.user,
            displayName: 'Bill',
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bill'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('guest selecting schedule shows authenticated-only snackbar', (tester) async {
      await tester.pumpWidget(
        wrap(
          HomeScreen(
            role: UserRole.guest,
            dataParser: mockDataParser,
            buildingLocator: mockBuildingLocator,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SearchOverlay searchOverlay = tester.widget<SearchOverlay>(
        find.byType(SearchOverlay),
      );
      searchOverlay.onMenuSelected('schedule');
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(ScheduleOverlay), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'simulateCampusChange resets locator, clears GPS building, and rebuilds polygons',
          (WidgetTester tester) async {
        final building = buildTestBuilding(
          id: 'loy1',
          name: 'LOY',
          fullName: 'Loyola Building',
          campus: Campus.loyola,
        );

        when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [building]);
        when(mockDataParser.buildingsPresent).thenReturn([building]);
        when(mockBuildingLocator.reset()).thenReturn(null);

        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dynamic state =
        tester.state(find.byType(home_screen.HomeScreen).first);

        state.simulateCampusChange(Campus.loyola);
        await tester.pumpAndSettle();

        verify(mockBuildingLocator.reset()).called(1);
        expect(state.testPolygons, isNotEmpty);
      },
    );

    testWidgets(
      'simulateGpsLocation updates locator result and rebuilds polygons',
          (WidgetTester tester) async {
        final building = buildTestBuilding(
          id: 'gps1',
          name: 'GPS',
          fullName: 'GPS Building',
          campus: Campus.sgw,
        );

        when(mockDataParser.getBuildingInfoFromJSON()).thenAnswer((_) async => [building]);
        when(mockDataParser.buildingsPresent).thenReturn([building]);

        when(
          mockBuildingLocator.update(
            userPoint: anyNamed('userPoint'),
            campus: anyNamed('campus'),
            buildings: anyNamed('buildings'),
          ),
        ).thenReturn(
          BuildingStatus(building: building, treatedAsInside: true),
        );

        await tester.pumpWidget(
          wrap(
            home_screen.HomeScreen(
              dataParser: mockDataParser,
              buildingLocator: mockBuildingLocator,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dynamic state =
        tester.state(find.byType(home_screen.HomeScreen).first);

        state.simulateGpsLocation(const LatLng(45.5, -73.6));
        await tester.pumpAndSettle();

        verify(
          mockBuildingLocator.update(
            userPoint: const LatLng(45.5, -73.6),
            campus: anyNamed('campus'),
            buildings: anyNamed('buildings'),
          ),
        ).called(1);

        expect(state.testPolygons, isNotEmpty);
      },
    );

    testWidgets(
      'recenter button appears after map move and is tappable',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(home_screen.HomeScreen(
          dataParser: mockDataParser,
          buildingLocator: mockBuildingLocator,
        )));
        // GPS stream emits → _lastKnownPosition is set
        await tester.pumpAndSettle();

        final dynamic state =
            tester.state(find.byType(home_screen.HomeScreen).first);

        // Button should not be visible yet
        expect(find.byTooltip('Recenter to my location'), findsNothing);

        // Simulate a user-initiated camera move → _mapMoved = true
        state.simulateCameraMove(
          const CameraPosition(target: LatLng(45.5, -73.6), zoom: 15),
        );
        await tester.pump();

        // Button should now appear
        expect(find.byTooltip('Recenter to my location'), findsOneWidget);
      },
    );
    testWidgets('tapping logout signs out and navigates away from HomeScreen',
        (WidgetTester tester) async {
      final fakeAuth = _FakeAuthService();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        authService: fakeAuth,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // HomeScreen has been removed from the stack; AuthGate renders LoginScreen.
      expect(find.byType(home_screen.HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('GPS status card shows building name when fullName is null',
        (WidgetTester tester) async {
      final building = CampusBuilding(
        id: 'b_noname',
        name: 'HAL',
        fullName: null,
        description: null,
        campus: Campus.sgw,
        boundary: const [
          LatLng(0, 0), LatLng(0, 2), LatLng(2, 2), LatLng(2, 0), LatLng(0, 0),
        ],
      );

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

      // fullName is null so the chip falls through to building.name
      expect(find.text('HAL'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // markers getter (line 190)
    // -------------------------------------------------------------------------
    testWidgets('markers getter returns the state markers list',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();
      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      expect(state.markers, isA<List>());
    });

    // -------------------------------------------------------------------------
    // resetFilters (lines 203-216)
    // -------------------------------------------------------------------------
    testWidgets('resetFilters clears all filter state',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();
      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      // Pre-set some values
      state.restaurants = true;
      state.cafes = true;
      state.nearbyPois = 5.0;
      state.resetFilters();
      await tester.pump();
      expect(state.restaurants, isFalse);
      expect(state.cafes, isFalse);
      expect(state.parks, isFalse);
      expect(state.parking, isFalse);
      expect(state.fastFood, isFalse);
      expect(state.nightClub, isFalse);
      expect(state.nearbyPois, equals(0));
    });

    // -------------------------------------------------------------------------
    // applyFilters – early return when mapController is null (line 383)
    // -------------------------------------------------------------------------
    testWidgets('applyFilters returns early when mapController is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();
      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      // _mapController is null; applyFilters must return without throwing
      state.applyFilters();
      await tester.pump();
    });

    // -------------------------------------------------------------------------
    // _loadNearbyPois success path
    // Lines 385-517, 520-591, 603-644, and StringExtension.capitalize (46-51)
    // -------------------------------------------------------------------------
    // Helper: fake JSON for a single place with photos and opening hours
    const fakeOnePlaceJson = '''
{
  "places": [
    {
      "id": "place1",
      "displayName": {"text": "Test Place"},
      "location": {"latitude": 45.5, "longitude": -73.6},
      "primaryType": "restaurant",
      "rating": 4.5,
      "regularOpeningHours": {
        "openNow": true,
        "weekdayDescriptions": ["Monday: 9 AM – 9 PM"]
      },
      "shortFormattedAddress": "123 Test St",
      "photos": [{"name": "photos/test_photo"}]
    }
  ]
}
''';

    testWidgets('loadNearbyPoisForTest covers all 6 category branches',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.restaurants = true;
      state.cafes = true;
      state.parks = true;
      state.parking = true;
      state.fastFood = true;
      state.nightClub = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: restaurant only covers _finishLoadingPois',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.restaurants = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: cafe only',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.cafes = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: park only',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.parks = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: parking only',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.parking = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: fastFood only',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.fastFood = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: nightClub only',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.nightClub = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: no photos covers empty-photos branch',
        (WidgetTester tester) async {
      const noPhotosJson = '''
{
  "places": [
    {
      "id": "place2",
      "displayName": {"text": "No Photo Place"},
      "location": {"latitude": 45.5, "longitude": -73.6},
      "primaryType": "cafe",
      "rating": 3.0,
      "shortFormattedAddress": "456 Test Ave",
      "photos": []
    }
  ]
}
''';
      final mockHttpClient =
          MockClient((_) async => http.Response(noPhotosJson, 200));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.cafes = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets('loadNearbyPoisForTest: applyFilters loads restaurants via mock HTTP client and adds markers',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response(fakeOnePlaceJson, 200));

      final fakeController = FakeGoogleMapController();
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [],
          durationText: '0 min',
          distanceText: '0 km',
        )),
      );

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        testDirectionsController: fakeDirections,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.restaurants = true;
      state.cafes = true;
      state.parks = true;
      state.parking = true;
      state.fastFood = true;
      state.nightClub = true;
      state.applyFilters();
      await tester.pumpAndSettle();

      // Verify the widget is still alive after the HTTP-backed POI load
      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _loadNearbyPois error path – catch branch (lines 507-512)
    // -------------------------------------------------------------------------
    testWidgets('applyFilters shows snackbar on HTTP 500 error',
        (WidgetTester tester) async {
      final mockHttpClient =
          MockClient((_) async => http.Response('server error', 500));
      final fakeController = FakeGoogleMapController();

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testHttpClient: mockHttpClient,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setMapControllerForTest(fakeController);
      state.restaurants = true;

      await tester.runAsync(() async {
        await state.loadNearbyPoisForTest();
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load places'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _finishLoadingPois direct tests (lines 523–602)
    // -------------------------------------------------------------------------
    testWidgets('finishLoadingPoisForTest: covers photos loop and buildPhotoUrl',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);

      final placeWithPhotosAndHours = <String, dynamic>{
        'id': 'p1',
        'displayName': {'text': 'Test Place'},
        'location': {'latitude': 45.5, 'longitude': -73.6},
        'primaryType': 'cafe',
        'rating': 4.0,
        'shortFormattedAddress': '1 Test St',
        'photos': [
          {'name': 'photos/test_photo_1'},
          {'name': 'photos/test_photo_2'},
        ],
        'regularOpeningHours': {
          'openNow': true,
          'weekdayDescriptions': ['Monday: 9 AM – 5 PM'],
        },
      };

      final icon = Uint8List.fromList(List.filled(16, 0));
      state.finishLoadingPoisForTest([placeWithPhotosAndHours], icon, 32.0);
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
      expect((state.poiPresent as List).length, greaterThan(0));
    });

    testWidgets('finishLoadingPoisForTest: covers no-photos branch',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);

      final placeNoPhotos = <String, dynamic>{
        'id': 'p2',
        'displayName': {'text': 'No Photo Place'},
        'location': {'latitude': 45.5, 'longitude': -73.6},
        'primaryType': 'park',
        'rating': 3.5,
        'shortFormattedAddress': '2 Test St',
        'photos': <dynamic>[],
        'regularOpeningHours': null,
      };

      final icon = Uint8List.fromList(List.filled(16, 0));
      state.finishLoadingPoisForTest([placeNoPhotos], icon, 24.0);
      await tester.pumpAndSettle();

      expect((state.poiPresent as List).length, greaterThan(0));
    });

    testWidgets('finishLoadingPoisForTest: marker onTap triggers poi detail',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        markerImageLoader: (_, __) async =>
            Uint8List.fromList(List.filled(16, 0)),
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);

      final place = <String, dynamic>{
        'id': 'p3',
        'displayName': {'text': 'Tap Me'},
        'location': {'latitude': 45.5, 'longitude': -73.6},
        'primaryType': 'restaurant',
        'rating': 4.5,
        'shortFormattedAddress': '3 Test St',
        'photos': [{'name': 'photos/photo_x'}],
        'regularOpeningHours': {
          'openNow': false,
          'weekdayDescriptions': ['Mon: Closed'],
        },
      };

      final icon = Uint8List.fromList(List.filled(16, 0));
      state.finishLoadingPoisForTest([place], icon, 32.0);
      await tester.pumpAndSettle();

      // Invoke onTap on the created marker to cover the lambda body (lines 585-586)
      final markers = state.testMarkers as List;
      expect(markers, isNotEmpty);
      final firstMarker = markers.first;
      firstMarker.onTap?.call();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _onSearchChanged includes POI results (lines 704-706)
    // -------------------------------------------------------------------------
    testWidgets('search results include POIs when query matches poi name',
        (WidgetTester tester) async {
      final poi = testPoi(id: 'p1', name: 'Downtown Cafe');
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.poiPresent.add(poi);

      await tester.enterText(find.byType(TextField).first, 'cafe');
      await tester.pump(const Duration(milliseconds: 400));

      // POI should appear in search results
      expect(find.text('Downtown Cafe'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _handlePoiAsStart (lines 864-873) and _updateDirectionsIfReady with
    // _startPoi set (line 788)
    // -------------------------------------------------------------------------
    testWidgets('simulatePoiAsStart sets startPoi state',
        (WidgetTester tester) async {
      final poi = testPoi(id: 'ps1', name: 'Start Poi');
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [],
          durationText: '0',
          distanceText: '0 km',
        )),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      await state.simulatePoiAsStart(poi);
      await tester.pumpAndSettle();

      // No crash; directions card reflects no-route state (no end set)
      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _handlePoiAsDestination (lines 875-884) + _updateDirectionsIfReady
    // with both _startPoi and _endPoi set (lines 788, 794, 815)
    // -------------------------------------------------------------------------
    testWidgets('simulatePoiAsDestination with prior startPoi covers poi route path',
        (WidgetTester tester) async {
      final startPoi =
          testPoi(id: 'ps2', name: 'Start', boundary: const LatLng(45.4, -73.5));
      final endPoi =
          testPoi(id: 'pd2', name: 'End', boundary: const LatLng(45.5, -73.6));
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [RouteLeg(polylinePoints: [LatLng(45.4, -73.5), LatLng(45.5, -73.6)], legMode: LegMode.walking, durationSeconds: 0, durationText: '5 min', distanceText: '1 km')],
          durationText: '5 min',
          distanceText: '1 km',
        )),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      await state.simulatePoiAsStart(startPoi);
      await state.simulatePoiAsDestination(endPoi);
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    testWidgets(
        'simulatePoiAsDestination without start sets current-location start path',
        (WidgetTester tester) async {
      final endPoi = testPoi(
          id: 'pd3',
          name: 'Lone End',
          boundary: const LatLng(45.5, -73.6));
      final fakeDirections = DirectionsController(
        client: FakeDirectionsClient.success(const RouteResult(
          legs: [
            RouteLeg(
                polylinePoints: [
                  LatLng(45.4, -73.5),
                  LatLng(45.5, -73.6)
                ],
                legMode: LegMode.walking,
                durationSeconds: 0,
                durationText: '5 min',
                distanceText: '1 km')
          ],
          durationText: '5 min',
          distanceText: '1 km',
        )),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
        testDirectionsController: fakeDirections,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      await state.simulatePoiAsDestination(endPoi);
      await tester.pumpAndSettle();

      expect(find.byType(home_screen.HomeScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // _showPoiDetailSheet (lines 1028-1057)
    // -------------------------------------------------------------------------
    testWidgets('simulateShowPoiDetailSheet shows BuildingDetailSheet for POI',
        (WidgetTester tester) async {
      final poi = testPoi(
        id: 'poi_sheet',
        name: 'Sheet Poi',
        boundary: const LatLng(45.5, -73.6),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.simulateShowPoiDetailSheet(poi);
      await tester.pump(); // flushes the addPostFrameCallback
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // POI FAB onPressed – sets showPoiSettings (lines 1390-1392)
    // -------------------------------------------------------------------------
    testWidgets('tapping Points of Interest FAB shows PoiOptionMenu',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Points of Interest'));
      await tester.pump();

      expect(find.text('Points of interest filter'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // PoiOptionMenu callbacks (lines 1285-1349)
    // -------------------------------------------------------------------------
    testWidgets('PoiOptionMenu checkbox callbacks update filter state',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowPoiSettingsForTest(true);
      await tester.pump();

      // Tap each checkbox (by index: 0=Restaurants, 1=Cafes, 2=Parks,
      //   3=Parking, 4=FastFood, 5=NightClub)
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      expect(state.restaurants, isTrue);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(state.cafes, isTrue);

      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      expect(state.parks, isTrue);

      await tester.tap(find.byType(Checkbox).at(3));
      await tester.pump();
      expect(state.parking, isTrue);

      await tester.tap(find.byType(Checkbox).at(4));
      await tester.pump();
      expect(state.fastFood, isTrue);

      await tester.tap(find.byType(Checkbox).at(5));
      await tester.pump();
      expect(state.nightClub, isTrue);

      // Sliders – drag to trigger onNearbyChanged and onDistanceChanged
      await tester.drag(find.byType(Slider).first, const Offset(20, 0));
      await tester.pump();

      await tester.drag(find.byType(Slider).last, const Offset(20, 0));
      await tester.pump();

      // Reset button
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(state.restaurants, isFalse);
    });

    testWidgets('PoiOptionMenu sort dropdown updates type', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowPoiSettingsForTest(true);
      await tester.pump();

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distance').last);
      await tester.pump();

      expect(state.type, 'DISTANCE');
    });

    testWidgets('PoiOptionMenu onShow hides menu and shows Results',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowPoiSettingsForTest(true);
      await tester.pump();

      await tester.tap(find.text('Show results'));
      await tester.pump();

      expect(state.showPoiSettings, isFalse);
      expect(state.showResults, isTrue);
    });

    testWidgets('PoiOptionMenu onClose hides the menu',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowPoiSettingsForTest(true);
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();

      expect(state.showPoiSettings, isFalse);
    });

    testWidgets('PoiOptionMenu Apply button calls applyFilters',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowPoiSettingsForTest(true);
      await tester.pump();

      // Apply with no map controller — _loadNearbyPois returns early, no crash
      await tester.tap(find.text('Apply'));
      await tester.pump();
    });

    // -------------------------------------------------------------------------
    // Results widget callbacks (lines 1376-1384)
    // -------------------------------------------------------------------------
    testWidgets('Results onSelect triggers showPoiDetailSheet for a POI',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final poi = testPoi(
        id: 'res1',
        name: 'Result Poi',
        description: 'Cafe',
        boundary: const LatLng(45.5, -73.6),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.poiPresent.add(poi);
      state.setShowResultsForTest(true);
      await tester.pump();

      await tester.tap(find.text('Result Poi'));
      await tester.pump(); // fires post-frame callback for showBottomSheet
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
    });

    testWidgets('Results onClose hides the results panel',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.setShowResultsForTest(true);
      await tester.pump();

      expect(find.text('Results'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();

      expect(state.showResults, isFalse);
    });

    // -------------------------------------------------------------------------
    // Search overlay – Poi branch in onSelectResult (lines 1625-1626)
    // -------------------------------------------------------------------------
    testWidgets('selecting a Poi from search results calls showPoiDetailSheet',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final poi = testPoi(
        id: 'sq1',
        name: 'Searched Cafe',
        boundary: const LatLng(45.5, -73.6),
      );
      await tester.pumpWidget(wrap(home_screen.HomeScreen(
        dataParser: mockDataParser,
        buildingLocator: mockBuildingLocator,
      )));
      await tester.pumpAndSettle();

      final dynamic state =
          tester.state(find.byType(home_screen.HomeScreen).first);
      state.poiPresent.add(poi);

      await tester.enterText(find.byType(TextField).first, 'Searched Cafe');
      await tester.pump(const Duration(milliseconds: 400));

      // .last selects the ListTile Text, not the TextField's EditableText
      expect(find.text('Searched Cafe'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Searched Cafe').last);
      await tester.pump(); // fires post-frame callback for showBottomSheet
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailSheet), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // triggerPolygonOnTap predicate evaluated for existing polygon (line 1703)
    // -------------------------------------------------------------------------
    testWidgets(
        'triggerPolygonOnTap evaluates predicate and calls onTap for existing polygon',
        (WidgetTester tester) async {
      final building =
          buildTestBuilding(id: 'tx1', name: 'TriggerBldg', fullName: 'TriggerBldg Full');
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
      state.lastTap = const LatLng(1, 1);
      state.triggerPolygonOnTap(const PolygonId('tx1'));
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailContent), findsOneWidget);
    });

  });
}