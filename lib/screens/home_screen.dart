import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:proj/data/data_parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/widgets/home/poi_option_menu.dart';
import 'package:proj/services/markerIconLoader.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import 'package:proj/services/building_locator.dart';
import 'package:proj/widgets/home/campus_map.dart';
import 'package:proj/widgets/home/poi_detail_sheet.dart';
import 'package:proj/widgets/poi_toggle.dart';
import '../config/secrets.dart';
import '../main.dart';
import '../services/directions/directions_controller.dart';
import '../services/directions/transport_mode_strategy.dart';
import '../services/route_logic.dart';
import '../utilities/polygon_helper.dart';
import '../widgets/home/building_detail_sheet.dart';
import '../widgets/home/directions_card.dart';
import '../widgets/home/map_layer.dart';
import '../widgets/home/search_overlay.dart';
import 'indoor_map_screen.dart';
import '../widgets/use_as_start.dart';
import '../models/poi.dart';
import '../widgets/schedule/schedule_overlay.dart';
import '../models/course_schedule_entry.dart';
import '../services/concordia_api.dart';
import '../services/schedule_lookup.dart';

typedef MarkerImageLoader = Future<Uint8List> Function(String path, int width);

class HomeScreen extends StatefulWidget {
  final DataParser? dataParser;
  final BuildingLocator? buildingLocator;
  /// For tests: when non-null, used instead of the map's controller future
  /// so [ _goToCampus ] can complete without a real map.
  final Completer<GoogleMapController>? testMapControllerCompleter;

  final DirectionsController? testDirectionsController;

  const HomeScreen({
    super.key,
    this.dataParser,
    this.buildingLocator,
    this.testMapControllerCompleter,
    this.testDirectionsController,
    MarkerImageLoader? markerImageLoader,
  }) : markerImageLoader = markerImageLoader ?? defaultMarkerImageLoader;

  final MarkerImageLoader markerImageLoader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Public state type so tests can call [handleMapTap] to cover map-tap logic.
abstract class HomeScreenState extends State<HomeScreen> {
  get markers => [];

  /// Called when the map is tapped. Exposed for tests; production code calls
  /// this from [GoogleMap.onTap]. [sheetContext] should have a [Scaffold]
  /// ancestor (e.g. from LayoutBuilder in build); if null, [context] is used.
  void handleMapTap(LatLng point, [BuildContext? sheetContext]);

}

class _HomeScreenState extends HomeScreenState {
  bool? isAnnex;
  late DataParser data;
  GoogleMapController? _mapController;
  Campus _campus = Campus.sgw;
  // ignore: unused_field
  LatLng? _cursorPoint;
  LatLng? lastTap;
  CampusBuilding? _cursorBuilding;
  CampusBuilding? _startBuilding;
  CampusBuilding? _endBuilding;
  Poi? _startPoi;
  Poi? _endPoi;

  /// True when user chose destination first; route start is current GPS location.
  bool _startFromCurrentLocation = false;

  /// Shown when destination-first but location is unavailable.
  String? _locationRequiredMessage;

  /// When true, do not auto-apply default transport mode (user chose manually).
  bool _modeChangedByUser = false;
  late Future<List<CampusBuilding>> _buildingsFuture;
  List<Poi> poiPresent = [];
  final TextEditingController _searchController = TextEditingController();
  List<CampusBuilding> buildingsPresent = [];
  Set<Polygon> _polygons = {};
  PolygonId? _selectedId;
  Timer? _searchDebounce;
  Timer? _markerRebuildDebounce;
  final Map<PolygonId, CampusBuilding> _polygonToBuilding = {};
  bool campusChange = false;
  final GlobalKey _mapKey = GlobalKey();
  final List<CampusBuilding> _searchResults = <CampusBuilding>[];
  bool _showSearchResults = false;
  late final DirectionsController _directions;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _sheetController;
  static const double _sheetLiftMax = 210.0;

  late BuildingLocator _buildingLocator;

  StreamSubscription<Position>? _gpsSub;
  CampusBuilding? _currentBuildingFromGPS;

  bool isInBuilding = false;
  bool _showScheduleOverlay = false;

  final List<Marker> _markers = <Marker>[];

  LatLng? locationPoint;

  bool _showPOIOptionMenu = false;

  int _currentPOICount = 0;

  bool firstRun = false;

  @visibleForTesting
  List<Marker> get markers => _markers;

  @override
  void initState() {
    super.initState();

    _initDependencies();
    _initDirections();
    _tryInitLocationTracking();
    _initMarkers();
  }

  double _iconSizeForZoom(double zoom) {
    const double minZoom = 13.0;
    const double maxZoom = 20.0;
    const double minSize = 24.0;
    const double maxSize = 56.0;
    final t = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minSize + t * (maxSize - minSize);
  }

  Future<void> _rebuildMarkers() async {
    final double zoom = _mapController != null
        ? await _mapController!.getZoomLevel()
        : 15.0;
    final double logicalSize = _iconSizeForZoom(zoom);
    final List<Marker> newMarkers = [];

    for (int i = 0; i < poiPresent.length; i++) {
      final Uint8List markIcons = await widget.markerImageLoader(
        poiPresent.elementAt(i).poiType,
        logicalSize.round(),
      );
      newMarkers.add(Marker(
        markerId: MarkerId(i.toString()),
        icon: BitmapDescriptor.fromBytes(markIcons, size: Size(logicalSize, logicalSize)),
        position: poiPresent.elementAt(i).boundary,
        onTap: () => setState(() {
          _showPoiDetailSheet(poiPresent.elementAt(i));
        }),
      ));
    }

    if (!mounted) return;
    setState(() {
      _markers..clear()..addAll(newMarkers);
      if(!firstRun) {
        _currentPOICount = _markers.length;
        firstRun = true;
      }

      if (_markers.isEmpty) {
        _markers..clear()..addAll(newMarkers);
      }

      _markers.sort((m1, m2) {
        return _computeDistance(m1.position, locationPoint!).compareTo(_computeDistance(m2.position, locationPoint!));
      });
    });
  }

  void _onCameraMove(CameraPosition _) {
    _markerRebuildDebounce?.cancel();
    _markerRebuildDebounce = Timer(const Duration(milliseconds: 300), _rebuildMarkers);
  }

  @visibleForTesting
  Future<void> simulatePointerDown(Offset position) async {
    GoogleMapController? controller;
    if (widget.testMapControllerCompleter != null) {
      controller = await widget.testMapControllerCompleter!.future;
    } else {
      controller = _mapController;
    }
    if (controller == null) return;
    final latLng = await controller.getLatLng(
      ScreenCoordinate(x: position.dx.round(), y: position.dy.round()),
    );
    setState(() {
      lastTap = latLng;
    });
  }

  void _initDependencies() {
    data = widget.dataParser ?? DataParser();
    _buildingLocator = widget.buildingLocator ?? BuildingLocator(
      enterThresholdMeters: 15,
      exitThresholdMeters: 25,
    );

    _refreshBuildingsFromParser();
  }

  void _initDirections() {
    _directions = widget.testDirectionsController ?? DirectionsController(
      client: GoogleDirectionsClient(apiKey: Secrets.directionsApiKey),
    );
    // coverage:ignore-line
    assert(() {
      if (Secrets.directionsApiKey.isEmpty) {
        debugPrint(
            'Directions API key is missing (DIRECTIONS_API_KEY not set).');
      }
      return true;
    }());
    _directions.addListener(() {
      if (!mounted) return;
      setState(() {}); // reflect polyline/loading/error in UI
    });
  }

  bool _isLocationPermissionDenied(LocationPermission permission) {
    return permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
  }

  Future<LocationPermission> _checkAndMaybeRequestLocationPermission({
    required bool requestIfDenied,
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (requestIfDenied && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<void> _tryInitLocationTracking() async {
    if (isE2EMode) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    final permission = await _checkAndMaybeRequestLocationPermission(
      requestIfDenied: true,
    );

    if (_isLocationPermissionDenied(permission)) {
      debugPrint('Location permission denied.');
      return;
    }

    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position pos) {
          final userPoint = LatLng(pos.latitude, pos.longitude);
          locationPoint = userPoint;
          final result = _buildingLocator.update(
            userPoint: userPoint,
            campus: _campus,
            buildings: buildingsPresent,
          );

          if (!mounted) return;

          final oldId = _currentBuildingFromGPS?.id;
          final newId = result.building?.id;

          setState(() {
            _currentBuildingFromGPS = result.building;

            final CampusBuilding? b = result.building;
            isInBuilding = b != null && isPointInPolygon(userPoint, b.boundary);
          });

          if (oldId != newId) {
            _refreshBuildingsFromParser();
          }
        });
  }

  void _refreshBuildingsFromParser() {
    _buildingsFuture = data.getBuildingInfoFromJSON().then((list) {
      if (!mounted) {
        return list;
      }

      setState(() {
        buildingsPresent = list;
        _polygons = _buildPolygons(list);
      });

      return list;
    }); 
  }

  void _initMarkers() {
    data.getMarkersFromJSON().then((list) {
      if(!mounted) {
        return list;
      }

      setState(() {
        poiPresent = list;
      });
      _rebuildMarkers();

      return list;
    });
  }

  double _computeDistance(LatLng point1, LatLng point2) {

    //distance in km
    double R = 6356;

    double x = R*(pi/180)*(point2.latitude - point1.latitude);
    double y = R*(pi/180)*(point2.longitude - point1.longitude)*cos(point1.latitude);

    double distance = sqrt(pow(x, 2) + pow(y, 2));

    return distance;
  }

  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
  }

  Future<String> getPlaceMarks(LatLng coords) async {
    try {
      double x = coords.latitude;
      double y = coords.longitude;
      List<Placemark> placemarks = [];

      if (_cursorBuilding != null &&
          isPointInPolygon(coords, _cursorBuilding!.boundary)) {
        placemarks = await placemarkFromCoordinates(x, y);
      }

      String address = '';

      if (placemarks.isNotEmpty) {
        address = '${placemarks[0].street ?? ''}, ' '${placemarks[0].locality ??
            ''}, ' '${placemarks[0].postalCode ?? ''}';
      }

      return address;
    } catch (e) {
      debugPrint("Error getting placemarks: $e");
      return "No Address";
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final String q = value.trim().toLowerCase();

      if (q.isEmpty) {
        setState(() {
          _searchResults.clear();
          _showSearchResults = false;
        });
        return;
      }

      final results = buildingsPresent.where((b) =>
      b.name.toLowerCase().contains(q) ||
          (b.fullName ?? "").toLowerCase().contains(q))
          .take(8)
          .toList();

      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
        _showSearchResults = results.isNotEmpty;
      });
    });
  }

  /// Returns which campus (if any) contains [point] using building boundaries.
  Campus? _campusAtPoint(LatLng point) =>
      RouteLogic.campusAtPoint(point, buildingsPresent);


  /// Applies default transport mode. No-op if user changed mode or no destination.
  /// - Building-to-building: same campus → Walk, different campuses → Shuttle.
  /// - Current-location start: distance < 2.5 km → Walk, else → Shuttle.
  void _applyDefaultTransportMode({
    required Campus? endCampus,
    required Campus? startCampus,
    required LatLng? startPoint,
    required LatLng? endPoint,
    required bool isCurrentLocationStart,
  }) {
    if (_modeChangedByUser) return;
    final mode = RouteLogic.defaultMode(
      endCampus: endCampus,
      startCampus: startCampus,
      startPoint: startPoint,
      endPoint: endPoint,
      isCurrentLocationStart: isCurrentLocationStart,
    );
    if (mode != null) _directions.setMode(mode);
  }


  /// Resolves the route start point: from selected building or from current GPS when destination-first.
  Future<LatLng?> _getRouteStartPoint() async {
    if (_startBuilding != null) {
      return polygonCenter(_startBuilding!.boundary);
    }
    if (!_startFromCurrentLocation) return null;
    try {
      final permission = await _checkAndMaybeRequestLocationPermission(
        requestIfDenied: false,
      );
      if (_isLocationPermissionDenied(permission)) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('location timeout'),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateDirectionsIfReady() async {
    debugPrint('_updateDirectionsIfReady start=${_startBuilding
        ?.name ?? _startPoi?.name} end=${_endBuilding?.name ?? _endPoi?.name}');

    if (_endBuilding == null && _endPoi == null) {
      setState(() => _locationRequiredMessage = null);
      await _directions.updateRoute(start: null, end: null);
      return;
    }

    // ignore: prefer_typing_uninitialized_variables
    var start;
    // ignore: prefer_typing_uninitialized_variables
    var end;

    if(_startPoi == null) {
      start = await _getRouteStartPoint();
    } else {
      start = _startPoi!.boundary;
    }

    if(_endPoi == null) {
    end = polygonCenter(_endBuilding!.boundary);
    } else {
      end = _endPoi!.boundary;
    }

    if (_startFromCurrentLocation && start == null) {
      setState(() {
        _locationRequiredMessage =
        'To create a route from your current location, please allow location access.';
      });
      await _directions.updateRoute(start: null, end: null);
      return;
    }

    setState(() => _locationRequiredMessage = null);

    final startCampus = _startBuilding?.campus ??
        (start != null ? _campusAtPoint(start) : null);
    // ignore: prefer_typing_uninitialized_variables
    var endCampus;
    if(_endPoi == null) {
      endCampus = _endBuilding!.campus;
    } else {
      endCampus = _endPoi!.campus;
    }
    _applyDefaultTransportMode(
      endCampus: endCampus,
      startCampus: startCampus,
      startPoint: start,
      endPoint: end,
      isCurrentLocationStart: _startFromCurrentLocation,
    );

    await _directions.updateRoute(
      start: start,
      end: end,
      startCampus: startCampus,
      endCampus: endCampus,
    );

    debugPrint('Directions done: err=${_directions.state.errorMessage} '
        'points=${_directions.state.polyline?.points.length}');

    if (start != null && _directions.state.polyline != null) {
      await _zoomToRoute(start, end);
    }
  }

  

  Future<void> _handleSetAsStart(CampusBuilding building) async {
    debugPrint('Set as Start: ${building.name}');
    setState(() {
      _startBuilding = building;
      _endBuilding = null;
      _startFromCurrentLocation = false;
      _locationRequiredMessage = null;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handleSetAsDestination(CampusBuilding building) async {
    debugPrint('Set as Destination: ${building.name}');
    setState(() {
      _endBuilding = building;
      if (_startBuilding == null && _startPoi == null) _startFromCurrentLocation = true;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handlePoiAsStart(Poi poi) async {
    debugPrint('Set as Start: ${poi.name}');
    setState(() {
      _startPoi = poi;
      _endPoi = null;
      _startFromCurrentLocation = true;
      _locationRequiredMessage = null;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handlePoiAsDestination(Poi poi) async {
    debugPrint('Set as Destination: ${poi.name}');
    setState(() {
      _endPoi = poi;
      if (_startPoi == null) _startFromCurrentLocation = true;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _zoomToRoute(LatLng a, LatLng b) async {
    final controller = widget.testMapControllerCompleter != null
        ? await widget.testMapControllerCompleter!.future
        : _mapController;
    if (controller == null) return;
    final bounds = boundsForRoute(a, b);

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _onBuildingTapped(CampusBuilding? building) {
    debugPrint('_onBuildingTapped called with: ${building?.name}');
    if (building == null) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not part of campus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Please select a shaded building'),
              ],
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        //final bool canSetStart = _startBuilding == null || (_startBuilding?.id != building.id);
        //final bool canSetEnd = _endBuilding == null || (_endBuilding?.id != building.id);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${building.campus.name.toUpperCase()} - ${building
                    .name} - ${building.fullName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(building.description ?? 'No description available'),

              const SizedBox(height: 16),

              Row(
                children: [
                  ElevatedButton(
                    onPressed: _startBuilding?.id == building.id
                        ? null
                        : () async {
                      Navigator.pop(context);
                      await _handleSetAsStart(building);
                    },
                    child: const Text('Set as Start'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _endBuilding?.id == building.id
                        ? null
                        : () async {
                      Navigator.pop(context);
                      await _handleSetAsDestination(building);
                    },
                    child: const Text('Set as Destination'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _goToCampus(Campus campus) async {
    final controller = widget.testMapControllerCompleter != null
        ? await widget.testMapControllerCompleter!.future
        : _mapController;
    if (controller == null) return;
    final info = campusInfo[campus]!;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: info.center, zoom: info.zoom),
      ),
    );

    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
    });
  }

  Set<Polygon> _buildPolygons(List<CampusBuilding> buildings) {
    _polygonToBuilding.clear();

    return buildings.map((e) {
      final pid = PolygonId(e.id);
      _polygonToBuilding[pid] = e;
      final bool isActiveGps = _currentBuildingFromGPS?.id == e.id;
      if (isActiveGps) {
        isInBuilding =
            isActiveGps; // As soon as there's a building we are in, global variable is set to true
      }
      return Polygon(
        polygonId: pid,
        points: e.boundary,
        consumeTapEvents: true,
        fillColor: isActiveGps
            ? const Color(0x803197F6)
            : const Color(0x80912338),
        strokeColor: isActiveGps ? Colors.blue : const Color(0xFF741C2C),
        strokeWidth: isActiveGps ? 3 : 2,
        onTap: () {
          _cursorBuilding = e;
          _updateOnTap(pid);
        },
      );
    }).toSet();
  }

  void _showPoiDetailSheet(Poi poi) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;

      _sheetController?.close();
      _sheetController = null;

      _sheetController = scaffoldState.showBottomSheet((context) {
        return PoiDetailSheet(
          building: poi,
          startBuilding: _startBuilding,
          endBuilding: _endBuilding,
          startPoi: _startPoi,
          endPoi: _endPoi,
          onSetStart: () async {
            await _handlePoiAsStart(poi);
            _sheetController?.close();
            _sheetController = null;
          },
          onSetDestination: () async {
            await _handlePoiAsDestination(poi);
            _sheetController?.close();
            _sheetController = null;
          },
        );
      });
      _attachSheetAnimation(_sheetController);

      _sheetController!.closed.then((_) {
        if (mounted) _sheetController = null;
      });
    });
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _cursorPoint = point;
      _cursorBuilding = findBuildingAtPoint(point, buildingsPresent, _campus);
    });
  }

  @override
  void handleMapTap(LatLng point, [BuildContext? sheetContext]) {
    if (_sheetController != null) {
      _sheetController?.close();
      _sheetController = null;
      return;
    }

    final CampusBuilding? building =
    findBuildingAtPoint(point, buildingsPresent, _campus);

    lastTap = point;

    if (building == null) {
      _showNotCampusSheet();
    } else {
      _cursorBuilding = building;
      _updateOnTap(PolygonId(building.id));
    }

    setState(() {
      _cursorPoint = point;
    });
  }

  //logic separated
  void _showNotCampusSheet() {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) {
      return;
    }

    _sheetController?.close();
    _sheetController = scaffoldState.showBottomSheet(
          (_) =>
      const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not part of campus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Please select a shaded building'),
          ],
        ),
      ),
    );
    _attachSheetAnimation(_sheetController);
  }

  void _attachSheetAnimation(PersistentBottomSheetController? controller) {
    if (mounted) {
      setState(() {});
    }
  }


  void _updateOnTap(PolygonId id) {
    final building = _polygonToBuilding[id];
    if (building == null) return;
    final bool isAnnex =
        building.fullName?.contains("Annex") ?? false;
    final tap = lastTap;
    if (tap == null) return;

    _handleMapTap(tap);
    _applyPolygonSelection(id, building);
    _showBuildingDetailSheet(building, isAnnex);
  }

  void _applyPolygonSelection(PolygonId id, CampusBuilding building) {
    setState(() {
      _selectedId = id;
      _cursorBuilding = building;
      _polygons = _polygons.map((p) => _recolorPolygon(p)).toSet();
    });
  }

  Polygon _recolorPolygon(Polygon p) {
    final isSelected = p.polygonId == _selectedId;
    final isGps = _currentBuildingFromGPS != null &&
        p.polygonId == PolygonId(_currentBuildingFromGPS!.id);

    const Color selectedFill = Color.fromARGB(255, 124, 115, 29);
    const Color gpsFill = Color(0x803197F6);
    const Color defaultFill = Color(0x80912338);

    const Color selectedStroke = Colors.yellow;
    const Color gpsStroke = Colors.blue;
    const Color defaultStroke = Color(0xFF741C2C);

    Color fillColor;
    if (isSelected) {
      fillColor = selectedFill;
    } else if (isGps) {
      fillColor = gpsFill;
    } else {
      fillColor = defaultFill;
    }

    Color strokeColor;
    if (isSelected) {
      strokeColor = selectedStroke;
    } else if (isGps) {
      strokeColor = gpsStroke;
    } else {
      strokeColor = defaultStroke;
    }

    return p.copyWith(
      fillColorParam: fillColor,
      strokeColorParam: strokeColor,
    );
  }

  void _showBuildingDetailSheet(CampusBuilding building, bool isAnnex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;

      _sheetController?.close();
      _sheetController = null;

      _sheetController = scaffoldState.showBottomSheet((context) {
        return BuildingDetailSheet(
          building: building,
          isAnnex: isAnnex,
          startBuilding: _startBuilding,
          endBuilding: _endBuilding,
          onSetStart: () async {
            await _handleSetAsStart(building);
            _sheetController?.close();
            _sheetController = null;
          },
          onSetDestination: () async {
            await _handleSetAsDestination(building);
            _sheetController?.close();
            _sheetController = null;
          },
          onViewIndoorMap: () {
            _sheetController?.close();
            _sheetController = null;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IndoorMapScreen(building: building),
              ),
            );
          },
        );
      });
      _attachSheetAnimation(_sheetController);

      _sheetController!.closed.then((_) {
        if (mounted) _sheetController = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('The Waitlisters')),
      body: Stack(
        children: [
          if (!isE2EMode) _buildMapLayer(),
          _buildGpsStatusCard(),
          _buildCampusToggleCard(),
          _buildDirectionsCard(),
          _buildSearchOverlay(),
          _buildPOISection(),
          if (_currentBuildingFromGPS != null &&
              _startBuilding == null) _buildSetCurrentAsStartCard(),
          if (isE2EMode) _buildE2ECampusLabel(),
          if(_showPOIOptionMenu)
            POIOptionMenu(
                position: locationPoint!,
                calcDist: _computeDistance,
                allPOIs: poiPresent..sort((p1, p2) {
                  return _computeDistance(p1.boundary, locationPoint!).compareTo(_computeDistance(p2.boundary, locationPoint!));
                })..toList(),
                onDistanceSubmit: (str){
                  double? distOfPOIs = double.tryParse(str);

                  if (distOfPOIs != null) {
                    _currentPOICount = 0;
                    for (var m in _markers) {
                      if(_computeDistance(m.position, locationPoint!) <= distOfPOIs) {
                        _currentPOICount ++;
                      }
                    }
                    debugPrint("$_currentPOICount ------------------- POI count1");
                  }
                },
                onAmountSubmit: (str){
                  int? numOfPOIs = int.tryParse(str);

                  if (numOfPOIs != null) { _currentPOICount = numOfPOIs; }
                  debugPrint("$_currentPOICount ------------------- POI count2");
                }, onTap: () { setState(() {
                  _showPOIOptionMenu = false;
                }); },
              ),
          if (_showScheduleOverlay)
            ScheduleOverlay(
              onClose: () {
                setState(() {
                  _showScheduleOverlay = false;
                });
              },
              onRoomSelected: (CourseScheduleEntry entry) {
                debugPrint('Selected room: ${entry.room}');

                setState(() {
                  _showScheduleOverlay = false;
                });
              },
              lookupService: ScheduleLookupService(
                api: ConcordiaApiService(
                  userId: dotenv.env['CONCORDIA_USER_ID'] ?? '',
                  apiKey: dotenv.env['CONCORDIA_API_KEY'] ?? '',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer() {
    debugPrint("$_currentPOICount ----------------------------- POIs should be displayed");
    return MapLayer<CampusBuilding>(
      future: _buildingsFuture,
      hasPolygons: _polygons.isNotEmpty,
      onDataReady: (data) {
        _polygons = _buildPolygons(data);
      },
      mapKey: _mapKey,
      controller: _mapController,
      onMapTapLatLng: (latLng) {
        lastTap = latLng;
      },
      map: _buildGoogleMapWidget(),
    );
  }

  Widget _buildGoogleMapWidget() {
    return CampusMap(
      initialCamera: _initialCamera,
      polygons: _polygons,
      polylines: _directions.state.polyline == null
          ? <Polyline>{}
          : <Polyline>{_directions.state.polyline!},
      markers: Set<Marker>.of(_markers).take(_currentPOICount).toSet(),
      myLocationEnabled: !isE2EMode,
      myLocationButtonEnabled: !isE2EMode,
      onMapCreated: (GoogleMapController controller) {
        // coverage:ignore-start
        setState(() {
          _mapController = controller;
        });
      },
      onTap: (LatLng point) {
        handleMapTap(point);

        if (_searchResults.isNotEmpty) {
          setState(() {
            _showSearchResults = true;
          });
        }

        FocusScope.of(context).unfocus();
        // coverage:ignore-end
      },
      onCameraMove: _onCameraMove,

    );
  }

  Widget _buildGpsStatusCard() {
    final text = _currentBuildingFromGPS?.fullName ??
        _currentBuildingFromGPS?.name ?? 'Not in a building';
    return _topCard(
      top: 12,
      elevation: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCampusToggleCard() {
    return _topCard(
      top: 70,
      padding: const EdgeInsets.all(8),
      child: CampusToggle(
        selected: _campus,
        onChanged: _goToCampus,
      ),
    );
  }

  Widget _buildSetCurrentAsStartCard() {
    if (_currentBuildingFromGPS == null || !isInBuilding ||
        _startBuilding != null) {
      return const SizedBox.shrink();
    }

    final bool sheetOpen = _sheetController != null;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 0,
      bottom: sheetOpen ? _sheetLiftMax : 0,
      child: UseAsStart(
        selected: _currentBuildingFromGPS!,
        onSetStart: () {
          debugPrint(
              'Set as Start pressed for ${_currentBuildingFromGPS?.name}');

          setState(() {
            _startBuilding = _currentBuildingFromGPS;
            _endBuilding = null;
          });

          _updateDirectionsIfReady();

          if (_sheetController != null) {
            _sheetController?.close();
            setState(() {
              _sheetController = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildPOISection() {
    

    final bool sheetOpen = _sheetController != null;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      right: 0,
      bottom: sheetOpen ? _sheetLiftMax : 0,
      child: PoiToggle(onOpenPoiOptions: () {
          setState(() {
            _showPOIOptionMenu = true;
            
            debugPrint(_showPOIOptionMenu.toString());
          });

          if (_sheetController != null) {
            _sheetController?.close();
            setState(() {
              _sheetController = null;
            });
          }
      })
    );

    
      
  }

  Widget _topCard(
      {required double top, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets
          .all(12), double? elevation,}) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top, 12, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Card(
            elevation: elevation,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsCard() {
    return DirectionsCard(
      startBuilding: _startBuilding,
      endBuilding: _endBuilding,
      endPoi: _endPoi,
      useCurrentLocationAsStart: _startFromCurrentLocation &&
          _startBuilding == null,
      locationRequiredMessage: _locationRequiredMessage,
      isLoading: _directions.state.isLoading,
      errorMessage: _directions.state.errorMessage,
      polyline: _directions.state.polyline,
      durationText: _directions.state.durationText,
      distanceText: _directions.state.distanceText,
      onCancel: () {
        setState(() {
          _startBuilding = null;
          _endBuilding = null;
          _endPoi = null;
          _startFromCurrentLocation = false;
          _locationRequiredMessage = null;
          _modeChangedByUser = false;
        });
        _directions.updateRoute(start: null, end: null);
        debugPrint('Directions cancelled');
      },
      onRetry: _updateDirectionsIfReady,
      placeholderMessage: _directions.state.placeholderMessage,
      selectedModeParam: _directions.mode.modeParam,
      onModeChanged: (modeParam) {
        setState(() => _modeChangedByUser = true);
        _directions.setMode(strategyForModeParam(modeParam));
        _updateDirectionsIfReady();
      },
    );
  }

  

  Widget _buildSearchOverlay() {
    return SearchOverlay(
      controller: _searchController,
      showResults: _showSearchResults,
      results: _searchResults,
      onChanged: _onSearchChanged,
      onTapField: () {
        if (_searchResults.isNotEmpty) {
          setState(() {
            _showSearchResults = true;
          });
        }
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchResults.clear();
          _showSearchResults = false;
        });
      },
      onMenuSelected: (String value) {
        if (value == 'schedule') {
          setState(() {
            _showScheduleOverlay = true;
          });
        }
      },
      onSelectResult: (b) {
        debugPrint('Tapped search result: ${b.name}');
        _searchController.text = b.name;

        setState(() {
          _showSearchResults = false;
          _searchResults.clear();
        });

        _onBuildingTapped(b);
      },
    );
  }

  Widget _buildE2ECampusLabel() {
    return Text(
      _campus == Campus.loyola ? "campus:loyola" : "campus:sgw",
      key: const Key("campus_label"),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _markerRebuildDebounce?.cancel();
    _searchController.dispose();
    _gpsSub?.cancel();
    _directions.dispose();
    super.dispose();
  }

  //to call _updateOnTap() in tests.
  @visibleForTesting
  void simulatePolygonTap(PolygonId id, LatLng tapPoint) {
    lastTap = tapPoint;
    _updateOnTap(id);
  }

  /// For tests: trigger the onTap handler of the Polygon built in `_buildPolygons`.
  /// This covers the `Polygon.onTap` closure (cursor building assignment + _updateOnTap).
  @visibleForTesting
  void triggerPolygonOnTap(PolygonId id) {
    final Polygon? poly = _polygons.cast<Polygon?>().firstWhere(
          (p) => p != null && p.polygonId == id,
      orElse: () => null,
    );
    poly?.onTap?.call();
  }

  /// For tests: invoke the private `_onBuildingTapped` method, including the null branch.
  @visibleForTesting
  void simulateBuildingTap(CampusBuilding? building) {
    _onBuildingTapped(building);
  }

  /// For tests: complete the internal map controller completer so the Listener
  /// `onPointerDown` logic can await `_controller.future`.
  @visibleForTesting
  void completeInternalMapController(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  //test sheet render and bypass calling the tap methods.
  @visibleForTesting
  void simulateBuildingSelection(CampusBuilding building, LatLng tapPoint,) {
    lastTap = tapPoint;
    final bool isAnnex =
        building.fullName?.contains("Annex") ?? false;

    _showBuildingDetailSheet(building, isAnnex);

    setState(() {
      _cursorBuilding = building;
      _cursorPoint = tapPoint;
    });
  }

  @visibleForTesting
  void setCurrentBuildingFromGPS(CampusBuilding building) {
    setState(() {
      _currentBuildingFromGPS = building;
    });
  }

  @visibleForTesting
  void simulateCampusChange(Campus campus) {
    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
      _polygons = _buildPolygons(buildingsPresent);
    });
  }

  @visibleForTesting
  void simulateGpsLocation(LatLng point) {
    final result = _buildingLocator.update(
      userPoint: point,
      campus: _campus,
      buildings: buildingsPresent,
    );
    setState(() {
      _currentBuildingFromGPS = result.building;
      _polygons = _buildPolygons(buildingsPresent);
    });
  }

  @visibleForTesting
  Set<Polygon> get testPolygons => _polygons;

  @visibleForTesting
  Future<void> zoomToRouteForTest(LatLng a, LatLng b) {
    return _zoomToRoute(a, b);
  }

  @visibleForTesting
  void setIsInBuildingForTest(bool value) {
    setState(() {
      isInBuilding = value;
    });
  }

  @visibleForTesting
  void setShowScheduleOverlayForTest(bool value) {
    setState(() {
      _showScheduleOverlay = value;
    });
  }

  @visibleForTesting
  void setMapControllerForTest(GoogleMapController controller) {
    _mapController = controller;
  }

  @visibleForTesting
  void simulateCameraMove(CameraPosition position) {
    _onCameraMove(position);
  }

}

// For tests: Make sure we cover route-zoom math without a real map
LatLngBounds boundsForRoute(LatLng a, LatLng b) {
  final sw = LatLng(
    a.latitude < b.latitude ? a.latitude : b.latitude,
    a.longitude < b.longitude ? a.longitude : b.longitude,
  );
  final ne = LatLng(
    a.latitude > b.latitude ? a.latitude : b.latitude,
    a.longitude > b.longitude ? a.longitude : b.longitude,
  );

  return LatLngBounds(southwest: sw, northeast: ne);
}
