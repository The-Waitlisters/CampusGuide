import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:proj/data/data_parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import 'package:proj/services/building_locator.dart';
import 'package:proj/widgets/home/campus_map.dart';
import '../config/secrets.dart';
import '../main.dart';
import '../services/directions/directions_controller.dart';
import '../services/directions/transport_mode_strategy.dart';
import '../utilities/polygon_helper.dart';
import '../widgets/home/building_detail_sheet.dart';
import '../widgets/home/directions_card.dart';
import '../widgets/home/map_layer.dart';
import '../widgets/home/search_overlay.dart';

class HomeScreen extends StatefulWidget {
  final DataParser? dataParser;
  final BuildingLocator? buildingLocator;
  /// For tests: when non-null, used instead of the map's controller future
  /// so [ _goToCampus ] can complete without a real map.
  final Completer<GoogleMapController>? testMapControllerCompleter;

  const HomeScreen({
    super.key,
    this.dataParser,
    this.buildingLocator,
    this.testMapControllerCompleter
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Public state type so tests can call [handleMapTap] to cover map-tap logic.
abstract class HomeScreenState extends State<HomeScreen> {
  /// Called when the map is tapped. Exposed for tests; production code calls
  /// this from [GoogleMap.onTap]. [sheetContext] should have a [Scaffold]
  /// ancestor (e.g. from LayoutBuilder in build); if null, [context] is used.
  void handleMapTap(LatLng point, [BuildContext? sheetContext]);
}

class _HomeScreenState extends HomeScreenState {
  bool? isAnnex;
  late DataParser data;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Campus _campus = Campus.sgw;
  LatLng? _cursorPoint;
  LatLng? lastTap;
  CampusBuilding? _cursorBuilding;
  CampusBuilding? _startBuilding;
  CampusBuilding? _endBuilding;
  /// True when user chose destination first; route start is current GPS location.
  bool _startFromCurrentLocation = false;
  /// Shown when destination-first but location is unavailable.
  String? _locationRequiredMessage;
  /// When true, do not auto-apply default transport mode (user chose manually).
  bool _modeChangedByUser = false;
  late Future<List<CampusBuilding>> _buildingsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<CampusBuilding> buildingsPresent = [];
  Set<Polygon> _polygons = {};
  PolygonId? _selectedId;
  Timer? _searchDebounce;
  final Map<PolygonId, CampusBuilding> _polygonToBuilding = {};
  bool campusChange = false;
  final GlobalKey _mapKey = GlobalKey();
  final List<CampusBuilding> _searchResults = <CampusBuilding>[];
  bool _showSearchResults = false;
  late final DirectionsController _directions;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _sheetController;

  late BuildingLocator _buildingLocator;

  StreamSubscription<Position>? _gpsSub;
  CampusBuilding? _currentBuildingFromGPS;

  @override
  void initState() {
    super.initState();

    _initDependencies();
    _initDirections();
    _tryInitLocationTracking();
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
    _directions = DirectionsController(
      client: GoogleDirectionsClient(apiKey: Secrets.directionsApiKey),
    );
    assert(() {
      if (Secrets.directionsApiKey.isEmpty) {
        debugPrint('Directions API key is missing (DIRECTIONS_API_KEY not set).');
      }
      return true;
    }());
    _directions.addListener(() {
      if (!mounted) return;
      setState(() {}); // reflect polyline/loading/error in UI
    });
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

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
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

      if(placemarks.isNotEmpty) {
        address = '${placemarks[0].street ?? ''}, ' '${placemarks[0].locality ?? ''}, ' '${placemarks[0].postalCode ?? ''}';
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
  Campus? _campusAtPoint(LatLng point) {
    if (findBuildingAtPoint(point, buildingsPresent, Campus.sgw) != null) {
      return Campus.sgw;
    }
    if (findBuildingAtPoint(point, buildingsPresent, Campus.loyola) != null) {
      return Campus.loyola;
    }
    return null;
  }

  static const double _currentLocationDefaultModeThresholdMeters = 2500;

  /// Applies default transport mode. No-op if user changed mode or no destination.
  /// - Building-to-building: same campus → Walk, different campuses → Shuttle.
  /// - Current-location start: distance < 2.5 km → Walk, else → Shuttle.
  void _applyDefaultTransportMode({
    required Campus? endCampus,
    Campus? startCampus,
    LatLng? startPoint,
    LatLng? endPoint,
    required bool isCurrentLocationStart,
  }) {
    if (_modeChangedByUser || endCampus == null) return;

    if (isCurrentLocationStart && startPoint != null && endPoint != null) {
      final distanceMeters = Geolocator.distanceBetween(
        startPoint.latitude,
        startPoint.longitude,
        endPoint.latitude,
        endPoint.longitude,
      );
      if (distanceMeters < _currentLocationDefaultModeThresholdMeters) {
        _directions.setMode(WalkStrategy());
      } else {
        _directions.setMode(ShuttleStrategy());
      }
      return;
    }

    if (startCampus == null) return;
    if (startCampus == endCampus) {
      _directions.setMode(WalkStrategy());
    } else {
      _directions.setMode(ShuttleStrategy());
    }
  }

  /// Resolves the route start point: from selected building or from current GPS when destination-first.
  Future<LatLng?> _getRouteStartPoint() async {
    if (_startBuilding != null) {
      return polygonCenter(_startBuilding!.boundary);
    }
    if (!_startFromCurrentLocation) return null;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
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
    debugPrint('_updateDirectionsIfReady start=${_startBuilding?.name} end=${_endBuilding?.name}');

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

    final startCampus = _startBuilding?.campus ?? (start != null ? _campusAtPoint(start!) : null);
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
      await _zoomToRoute(start, end);
    }
  }

  Future<void> _zoomToRoute(LatLng a, LatLng b) async {
    final controller = await _controller.future;

    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
  }

  void _onBuildingTapped(CampusBuilding? building)
  {
    debugPrint('_onBuildingTapped called with: ${building?.name}');
    if (building == null)
    {
      showModalBottomSheet(
        context: context,
        builder: (context)
        {
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
      builder: (context)
      {
        //final bool canSetStart = _startBuilding == null || (_startBuilding?.id != building.id);
        //final bool canSetEnd = _endBuilding == null || (_endBuilding?.id != building.id);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${building.campus.name.toUpperCase()} - ${building.name} - ${building.fullName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            debugPrint('Pressed Set as Start for: ${building.name}');
                            setState(() {
                              _startBuilding = building;
                              _endBuilding = null;
                              _startFromCurrentLocation = false;
                              _locationRequiredMessage = null;
                            });
                            Navigator.pop(context);
                            await _updateDirectionsIfReady();
                          },
                    child: const Text('Set as Start'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _endBuilding?.id == building.id
                        ? null
                        : () async {
                            debugPrint('Pressed Set as Destination for: ${building.name}');
                            setState(() {
                              _endBuilding = building;
                              if (_startBuilding == null) _startFromCurrentLocation = true;
                            });
                            Navigator.pop(context);
                            await _updateDirectionsIfReady();
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
    final completer = widget.testMapControllerCompleter ?? _controller;
    final controller = await completer.future;
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
          (_) => const Padding(
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
      _polygons = _polygons.map((p) {
        final isSelected = (p.polygonId == _selectedId);
        return p.copyWith(
          fillColorParam: isSelected
              ? const Color.fromARGB(255, 124, 115, 29)
              : const Color(0x80912338),
          strokeColorParam: isSelected
              ? Colors.yellow
              : const Color(0xFF741C2C),
        );
      }).toSet();
    });
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
            debugPrint('Sheet: Set as Start pressed for ${building.name}');
            setState(() {
              _startBuilding = building;
              _endBuilding = null;
              _startFromCurrentLocation = false;
              _locationRequiredMessage = null;
            });
            await _updateDirectionsIfReady();
            _sheetController?.close();
            _sheetController = null;
          },
          onSetDestination: () async {
            debugPrint('Sheet: Set as Destination pressed for ${building.name}');
            setState(() {
              _endBuilding = building;
              if (_startBuilding == null) _startFromCurrentLocation = true;
            });
            await _updateDirectionsIfReady();
            _sheetController?.close();
            _sheetController = null;
          },
        );
      });

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
          _buildMapLayer(),
          _buildGpsStatusCard(),
          _buildCampusToggleCard(),
          _buildDirectionsCard(),
          _buildSearchOverlay(),
          if (isE2EMode) _buildE2ECampusLabel(),
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
      controllerFuture: _controller.future,
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
      markers: <Marker>{
        if (_cursorPoint != null)
          Marker(
            markerId: const MarkerId('cursor'),
            position: _cursorPoint!,
            infoWindow: InfoWindow(
              title: _cursorBuilding?.name ?? 'No building',
            ),
          ),
      },
      myLocationEnabled: !isE2EMode,
      myLocationButtonEnabled: !isE2EMode,
      onMapCreated: (GoogleMapController controller) {
        if (!_controller.isCompleted) {
          _controller.complete(controller);
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
      },
    );
  }

  Widget _buildGpsStatusCard() {final text = _currentBuildingFromGPS?.fullName ?? _currentBuildingFromGPS?.name ?? 'Not in a building';
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

  Widget _topCard({required double top, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(12), double? elevation,}) {
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
      useCurrentLocationAsStart: _startFromCurrentLocation && _startBuilding == null,
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
    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }
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

}
