import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:proj/data/data_parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/services/markerIconLoader.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import 'package:proj/services/building_locator.dart';
import 'package:proj/widgets/home/campus_map.dart';
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
import '../models/user_role.dart';
import '../services/auth/auth_service.dart';
import 'auth/auth_gate.dart';

typedef MarkerImageLoader = Future<Uint8List> Function(String path, int width);

class HomeScreen extends StatefulWidget {
  final UserRole role;
  final String? displayName;
  final AuthService? authService;

  final DataParser? dataParser;
  final BuildingLocator? buildingLocator;
  /// For tests: when non-null, used instead of the map's controller future
  /// so [ _goToCampus ] can complete without a real map.
  final Completer<GoogleMapController>? testMapControllerCompleter;

  final DirectionsController? testDirectionsController;


  const HomeScreen({
    super.key,
    this.role = UserRole.guest,
    this.displayName,
    this.authService,
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
  get markers => []; // coverage:ignore-line

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

  bool get _isGuest => widget.role == UserRole.guest;

  String get _userChipLabel {
    if (_isGuest) return 'Guest';
    final displayName = widget.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return 'User';
  }

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
  static const double _sheetLiftSmall = 100.0;
  double _currentSheetLift = _sheetLiftMax;

  late BuildingLocator _buildingLocator;

  StreamSubscription<Position>? _gpsSub;
  CampusBuilding? _currentBuildingFromGPS;

  bool isInBuilding = false;
  bool _showScheduleOverlay = false;
  bool _mapMoved = false;
  bool _programmaticCameraMove = false;
  LatLng? _lastKnownPosition;

  final List<Marker> _markers = <Marker>[];

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
        icon: BytesMapBitmap(markIcons, width: logicalSize, height: logicalSize),
        position: poiPresent.elementAt(i).boundary,
        infoWindow: InfoWindow(title: 'Location: $i'),
      ));
    }

    if (!mounted) return;
    setState(() {
      _markers..clear()..addAll(newMarkers);
    });
  }

  void _onCameraMove(CameraPosition _) {
    _markerRebuildDebounce?.cancel();
    _markerRebuildDebounce = Timer(const Duration(milliseconds: 300), _rebuildMarkers);
    if (!_programmaticCameraMove && !_mapMoved) {
      setState(() {
        _mapMoved = true;
      });
    }
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
    String apiKey = '';
    try {
      apiKey = Secrets.directionsApiKey;
    } catch (_) {
      // dotenv not loaded (e.g. integration tests) — directions disabled
    }
    _directions = widget.testDirectionsController ?? DirectionsController(
      client: GoogleDirectionsClient(apiKey: apiKey),
    );
    assert(() {
      if (apiKey.isEmpty) {
        debugPrint( // coverage:ignore-line
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
          if (mounted) {
            setState(() {
              _lastKnownPosition = userPoint;
            });
          }
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
        ?.name} end=${_endBuilding?.name}');

    if (_endBuilding == null) {
      setState(() => _locationRequiredMessage = null);
      await _directions.updateRoute(start: null, end: null);
      return;
    }

    final start = await _getRouteStartPoint();
    final end = polygonCenter(_endBuilding!.boundary);

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
    final endCampus = _endBuilding!.campus;
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
      await _zoomToRoute(start, end); // coverage:ignore-line
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
      if (_startBuilding == null) _startFromCurrentLocation = true;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _zoomToRoute(LatLng a, LatLng b) async {
    final controller = widget.testMapControllerCompleter != null
        ? await widget.testMapControllerCompleter!.future // coverage:ignore-line
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
    setState(() {
      _programmaticCameraMove = true;
    });
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: info.center, zoom: info.zoom),
      ),
    );

    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
      _mapMoved = false;
      _programmaticCameraMove = false;
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
      setState(() { _sheetController = null; });
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
    _currentSheetLift = _sheetLiftSmall;
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
      _currentSheetLift = _sheetLiftMax;

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

      final attachedController = _sheetController!;
      attachedController.closed.then((_) {
        if (mounted && _sheetController == attachedController) {
          setState(() { _sheetController = null; }); // coverage:ignore-line
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('The Waitlisters'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text(_userChipLabel),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final svc = widget.authService ?? AuthService();
              await svc.signOut();

              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => AuthGate(authService: svc),
                ),
                    (route) => false,
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),


      body: Stack(
        children: [
          _buildMapLayer(),
          _buildGpsStatusCard(),
          _buildCampusToggleCard(),
          _buildDirectionsCard(),
          _buildSearchOverlay(),
          if (_mapMoved && _lastKnownPosition != null) _buildRecenterButton(),
          if (_currentBuildingFromGPS != null &&
              _startBuilding == null) _buildSetCurrentAsStartCard(),
          if (isE2EMode) _buildE2ECampusLabel(),

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
          : <Polyline>{_directions.state.polyline!}, // coverage:ignore-line
      markers: Set<Marker>.of(_markers),
      myLocationEnabled: !isE2EMode,
      myLocationButtonEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        // coverage:ignore-start
        setState(() {
          _mapController = controller;
        });
        if (widget.testMapControllerCompleter != null &&
            !widget.testMapControllerCompleter!.isCompleted) {
          widget.testMapControllerCompleter!.complete(controller);
        }
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
    final building = _currentBuildingFromGPS; // capture locally

    if (building == null || !isInBuilding || _startBuilding != null) {
      return const SizedBox.shrink();
    }

    final bool sheetOpen = _sheetController != null;

    return Positioned(
      left: 12,
      right: 12,
      bottom: sheetOpen ? _currentSheetLift : 12, // coverage:ignore-line
      child: UseAsStart(
        selected: building,
        onSetStart: () {
          debugPrint(
              'Set as Start pressed for ${_currentBuildingFromGPS?.name}');

          setState(() {
            _startBuilding = _currentBuildingFromGPS;
            _endBuilding = null;
          });

          _updateDirectionsIfReady();

          if (_sheetController != null) { // coverage:ignore-start
            _sheetController?.close();
            setState(() {
              _sheetController = null;
            });
          } // coverage:ignore-end
        },
      ),
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
          if (_isGuest) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Schedule is available for user-authenticated accounts only.',
                ),
              ),
            );
            return;
          }

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

  Widget _buildRecenterButton() {
    final bool sheetOpen = _sheetController != null;
    final bool setAsStartVisible =
        _currentBuildingFromGPS != null && isInBuilding && _startBuilding == null;
    const double setAsStartHeight = 48.0;
    const double gap = 8.0;
    final double setAsStartBottom = sheetOpen ? _currentSheetLift : 12; // coverage:ignore-line
    final double bottom = setAsStartVisible
        ? setAsStartBottom + setAsStartHeight + gap // coverage:ignore-line
        : (sheetOpen ? _currentSheetLift : 0); // coverage:ignore-line
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      right: 12,
      bottom: bottom,
      child: FloatingActionButton.small(
        heroTag: 'recenter',
        onPressed: () async {
          // coverage:ignore-start
          final pos = _lastKnownPosition;
          if (pos == null) return;
          final controller = _mapController;
          if (controller == null) return;
          setState(() {
            _programmaticCameraMove = true;
          });
          await controller.animateCamera(
            CameraUpdate.newLatLng(pos),
          );
          setState(() {
            _mapMoved = false;
            _programmaticCameraMove = false;
          });
          // coverage:ignore-end
        },
        tooltip: 'Recenter to my location',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildE2ECampusLabel() { // coverage:ignore-start
    return Text(
      _campus == Campus.loyola ? "campus:loyola" : "campus:sgw",
      key: const Key("campus_label"),
    );
  } // coverage:ignore-end

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
      orElse: () => null, // coverage:ignore-line
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
  Future<void> simulateCampusChange(Campus campus) async {
    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
      _polygons = _buildPolygons(buildingsPresent);
    });
    await _goToCampus(campus);
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
      _markers
        ..removeWhere((m) => m.markerId == const MarkerId('_simulated_gps'))
        ..add(Marker(
          markerId: const MarkerId('_simulated_gps'),
          position: point,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
    });
  }

  @visibleForTesting
  Future<List<CampusBuilding>> get testBuildingsFuture => _buildingsFuture;

  @visibleForTesting
  Set<Polygon> get testPolygons => _polygons;

  @visibleForTesting // coverage:ignore-line
  Polyline? get testPolyline => _directions.state.polyline; // coverage:ignore-line

  @visibleForTesting // coverage:ignore-line
  String get testSelectedModeParam => _directions.mode.modeParam; // coverage:ignore-line

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
