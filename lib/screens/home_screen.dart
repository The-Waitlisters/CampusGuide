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
import '../main.dart';
import '../services/directions/directions_controller.dart';
import '../services/directions/transport_mode_strategy.dart';
import 'package:proj/config/secrets.dart';

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
    this.testMapControllerCompleter,
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
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  Campus _campus = Campus.sgw;
  LatLng? _cursorPoint;
  LatLng? lastTap;
  CampusBuilding? _cursorBuilding;
  CampusBuilding? _startBuilding;
  CampusBuilding? _endBuilding;
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
    data = widget.dataParser ?? DataParser();
    _buildingLocator = widget.buildingLocator ?? BuildingLocator(
      enterThresholdMeters: 15,
      exitThresholdMeters: 25,
    );

    _buildingsFuture = data.getBuildingInfoFromJSON();
    buildingsPresent = data.buildingsPresent;

    if (!isE2EMode) {
      _startLocationTracking();
    }

    _directions = DirectionsController(
      client: GoogleDirectionsClient(apiKey: Secrets.directionsApiKey),
    );
    _directions.addListener(() {
      if (!mounted) return;
      setState(() {}); // reflect polyline/loading/error in UI
    });
  }

  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
  }

  Future<String> getPlaceMarks(LatLng coords) async { /// To be fixed in sprint 2
    try {

      double x = coords.latitude;
      double y = coords.longitude;
      List<Placemark> placemarks = [];
      //List<Location> loc = [];

      if (_cursorBuilding != null &&
          isPointInPolygon(coords, _cursorBuilding!.boundary)) {
        placemarks = await placemarkFromCoordinates(x, y);
      }

      String address = '';

      if(placemarks.isNotEmpty) {

        address = '${placemarks[0].street ?? ''}, ' '${placemarks[0].locality ?? ''}, ' '${placemarks[0].postalCode ?? ''}';

        /* var streets = placemarks.reversed.map((placemark) => placemark.street).where((street) => street != null);

        streets = streets.where((street) => street!.toLowerCase() != placemarks.reversed.last.locality!.toLowerCase());

        streets = streets.where((street) => !street!.contains('+'));

        address += streets.first!;

        address += ', ${placemarks.reversed.last.subAdministrativeArea ?? ''}';
        address += ', ${placemarks.reversed.last.administrativeArea ?? ''}';
        address += ', ${placemarks.reversed.last.postalCode ?? ''}'; */
      }

      //debugPrint("Your Address for ($x , $y) is: $address");

      return address;

    } catch (e) {

      debugPrint("Error getting placemarks: $e");
      return "No Address";
      
    }
    
  }

  /*void _handleSearch(String query)//
  {
    CampusBuilding? building;

    try
    {
      building = campusBuildings.firstWhere(
            (b) =>
        b.name.toLowerCase().contains(query.toLowerCase()) ||
            (b.fullName ?? "").toLowerCase().contains(query.toLowerCase()),
      );
    }
    catch (_)
    {
      building = null;
    }

    if (building == null)
    {
      debugPrint("Search: no match for '$query'");
      return;
    }

    debugPrint("Search match: ${building.name}");

    _onBuildingTapped(building);
  }*/

  void _onSearchChanged(String value)
  {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), ()
    {
      final String q = value.trim().toLowerCase();

      if (q.isEmpty)
      {
        setState(() {
          _searchResults.clear();
          _showSearchResults = false;
        });
        return;
      }

      final results = buildingsPresent
          .where((b) =>
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

  LatLng _buildingAnchor(CampusBuilding b) {
    final pts = b.boundary;
    if (pts.isEmpty) return const LatLng(0, 0);

    double lat = 0;
    double lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  Future<void> _updateDirectionsIfReady() async {
    print('_updateDirectionsIfReady start=${_startBuilding?.name} end=${_endBuilding?.name}');

    final start = _startBuilding == null ? null : _buildingAnchor(_startBuilding!);
    final end = _endBuilding == null ? null : _buildingAnchor(_endBuilding!);

    await _directions.updateRoute(start: start, end: end);

    print('Directions done: err=${_directions.state.errorMessage} '
        'points=${_directions.state.polyline?.points.length}');

    if (start != null && end != null && _directions.state.polyline != null) {
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
    print('_onBuildingTapped called with: ${building?.name}');
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

              if (_startBuilding == null)
                ElevatedButton(
                  onPressed: () async {
                    print('Pressed Set as Start for: ${building.name}');
                    setState(() {
                      _startBuilding = building;
                      _endBuilding = null;
                    });
                    await _updateDirectionsIfReady();
                    Navigator.pop(context);
                  },
                  child: const Text('Set as Start'),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    print('Pressed Set as Destination for: ${building.name}');
                    setState(() {
                      _endBuilding = building;
                    });
                    await _updateDirectionsIfReady();
                    Navigator.pop(context);
                  },
                  child: const Text('Set as Destination'),
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /*Future<Set<Polygon>> _buildPolygonsForCampus(Campus campus) async
  {
    // Optional delay if they were using this to simulate async loading
    await Future.delayed(const Duration(milliseconds: 100));

    final Set<Polygon> polys = <Polygon>{};

    for (final CampusBuilding b in buildingsPresent)
    {
      if (b.campus != campus)
      {
        continue;
      }

      final bool isActiveGps = _currentBuildingFromGPS?.id == b.id;

      polys.add(
        Polygon(
          polygonId: PolygonId(b.id),
          points: b.boundary,
          fillColor: isActiveGps
              ? const Color(0x803197F6) // highlighted fill
              : const Color(0x80912338), // default fill
          strokeColor: isActiveGps
              ? Colors.blue
              : const Color(0xFF741C2C),
          strokeWidth: isActiveGps ? 3 : 2,
          consumeTapEvents: false,
          onTap: ()
          {
            debugPrint('Polygon tapped: ${b.name} (id=${b.id})');
            setState(()
            {
              _cursorBuilding = b;
            });
          },
        ),
      );
    }

    return polys;
  }*/


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

  Future<void> _startLocationTracking() async {
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

            if (oldId != newId) {
              _buildingsFuture = data.getBuildingInfoFromJSON(
              );
              buildingsPresent = data.buildingsPresent;
            }
          });
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
      _showNotCampusSheet(sheetContext ?? context);
    } else {
      _cursorBuilding = building;
      _updateOnTap(PolygonId(building.id));
    }

    setState(() {
      _cursorPoint = point;
    });
  }
  //logic seperated
  void _showNotCampusSheet(BuildContext ctx) {
    _sheetController = Scaffold.of(ctx).showBottomSheet(
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

  void _showBuildingDetailSheet(CampusBuilding building, bool isAnnex,) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;
      _sheetController?.close();
      _sheetController = null;

      _sheetController = scaffoldState.showBottomSheet((context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.15,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: BuildingDetailContent(
                  building: building,
                  isAnnex: isAnnex,
                  startBuilding: _startBuilding,
                  endBuilding: _endBuilding,
                  onSetStart: () async {
                    print('Sheet: Set as Start pressed for ${building.name}');
                    setState(() {
                      _startBuilding = building;
                      _endBuilding = null;
                    });
                    await _updateDirectionsIfReady();
                    _sheetController?.close();
                    _sheetController = null;
                  },
                  onSetDestination: () async {
                    print('Sheet: Set as Destination pressed for ${building.name}');
                    setState(() {
                      _endBuilding = building;
                    });
                    await _updateDirectionsIfReady();
                    _sheetController?.close();
                    _sheetController = null;
                  },
                ),
              ),
            );
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
          FutureBuilder<List<CampusBuilding>>(
            future: _buildingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading polygons: ${snapshot.error}'),
                );
              }

              if (_polygons.isEmpty && snapshot.hasData) {
                _polygons = _buildPolygons(snapshot.data!);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) async {
                      final controller = await _controller.future;
                      final box =
                          _mapKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (box == null) return;

                      final local = box.globalToLocal(event.position);

                      if (context.mounted) {
                        final pixelRatio = MediaQuery.of(
                          context,
                        ).devicePixelRatio;

                        final screenCoordinate = ScreenCoordinate(
                          x: (local.dx * pixelRatio).round(),
                          y: (local.dy * pixelRatio).round(),
                        );
                        final latLng = await controller.getLatLng(
                          screenCoordinate,
                        );
                        lastTap = latLng;
                      }
                    },
                    child: SizedBox(
                      key: _mapKey,
                      width: double.infinity,
                      height: double.infinity,
                      child: GoogleMap(
                        key: const Key("google_map"),
                        initialCameraPosition: _initialCamera,
                        onMapCreated: (GoogleMapController controller) {
                          if (!_controller.isCompleted) {
                            _controller.complete(controller);
                          }
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: !isE2EMode,
                        myLocationEnabled: !isE2EMode,
                        polygons: _polygons,
                        polylines: _directions.state.polyline == null
                            ? <Polyline>{}
                            : <Polyline>{_directions.state.polyline!},
                        mapToolbarEnabled: false,
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
                        onTap: (LatLng point) {
                          handleMapTap(point, context);

                          if (_searchResults.isNotEmpty) {
                            setState(() {
                              _showSearchResults = true;
                          });
                          }
                          FocusScope.of(context).unfocus();

                        }

                      ),
                    ),
                  );
                },
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      _currentBuildingFromGPS?.fullName ??
                          _currentBuildingFromGPS?.name ??
                          'Not in a building',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 70, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CampusToggle(
                      selected: _campus,
                      onChanged: _goToCampus,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_startBuilding != null)
            Positioned(
              top: 150,
              left: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Directions",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: ()
                            {
                              setState(() {
                                _startBuilding = null;
                                _endBuilding = null;
                              });
                              _directions.updateRoute(start: null, end: null);
                              print('Directions cancelled');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text("Start: ${_startBuilding!.fullName ?? _startBuilding!.name}"),

                      const SizedBox(height: 6),

                      Text("Destination: ${_endBuilding?.fullName ?? "Not set"}"),
                      Text('Route pts: ${_directions.state.polyline?.points.length ?? 0}'),
                      if (_directions.state.errorMessage != null)
                        Text(
                          'ERR: ${_directions.state.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),


          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search building...",
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: ()
                          {
                            _searchController.clear();
                            setState(() {
                              _searchResults.clear();
                              _showSearchResults = false;
                            });
                          },
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onTap: ()
                      {
                        if (_searchResults.isNotEmpty)
                        {
                          setState(() {
                            _showSearchResults = true;
                          });
                        }
                      },
                    ),
                  ),
                ),

                if (_showSearchResults)
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i)
                      {
                        final b = _searchResults[i];

                        return ListTile(
                          dense: true,
                          title: Text(b.name),
                          subtitle: (b.fullName != null && b.fullName!.trim().isNotEmpty)
                              ? Text(b.fullName!)
                              : null,
                          onTap: ()
                          {
                            print('Tapped search result: ${b.name}');
                            _searchController.text = b.name;

                            setState(() {
                              _showSearchResults = false;
                              _searchResults.clear();
                            });
                            _onBuildingTapped(b);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
  if (isE2EMode)
  Text(
  _campus == Campus.loyola ? "campus:loyola" : "campus:sgw",
  key: const Key("campus_label"),
  ),
        ],
      ),
    );
  }

  @override
  void dispose()
        {
    _gpsSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
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

class BuildingDetailContent extends StatelessWidget {
  const BuildingDetailContent({
    super.key,
    required this.building,
    required this.isAnnex,
    required this.startBuilding,
    required this.endBuilding,
    required this.onSetStart,
    required this.onSetDestination,
  });

  final CampusBuilding building;
  final bool isAnnex;

  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;

  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${building.name} ${isAnnex ? 'Annex' : '- ${building.fullName}'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Direction selection buttons
        if (startBuilding == null)
          ElevatedButton(
            onPressed: onSetStart,

            child: const Text('Set as Start'),
          )
        else
          ElevatedButton(
            onPressed: (startBuilding?.id == building.id)
                ? null
                : onSetDestination,
            child: const Text('Set as Destination'),
          ),

        const SizedBox(height: 12),
        if (building.isWheelchairAccessible ||
            building.hasBikeParking ||
            building.hasCarParking)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (building.isWheelchairAccessible)
                const Icon(Icons.accessible),
              if (building.hasBikeParking)
                const Icon(Icons.pedal_bike),
              if (building.hasCarParking)
                const Icon(Icons.local_parking),
            ],
          ),
        const SizedBox(height: 12),
        Text(building.description ?? ''),
        const SizedBox(height: 12),
        const Text(
          'Opening Hours:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.openingHours.map(
          (e) => Text((e == '-') ? 'None' : e),
        ),
        const SizedBox(height: 12),
        const Text(
          'Departments:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.departments.map(
          (e) => Text((e == '-') ? 'None' : e),
        ),
        const SizedBox(height: 12),
        const Text(
          'Services:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.services.map(
          (e) => Text((e == '-') ? 'None' : e),
        ),
      ],
    );
  }
}

bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  double x = point.longitude;
  double y = point.latitude;

  bool inside = false;
  int j = polygon.length - 1;

  for (int i = 0; i < polygon.length; i++) {
    double xi = polygon[i].longitude;
    double yi = polygon[i].latitude;

    double xj = polygon[j].longitude;
    double yj = polygon[j].latitude;

    double denom = (yj - yi);
    if (denom == 0.0) {
      denom = 1e-12;
    }

    bool intersect =
        ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / denom + xi);

    if (intersect) {
      inside = !inside;
    }

    j = i;
  }

  return inside;
}

CampusBuilding? findBuildingAtPoint(
  LatLng point,
  List<CampusBuilding> buildings,
  Campus campus,
) {
  for (CampusBuilding b in buildings) {
    if (b.campus != campus) {
      continue;
    }

    if (isPointInPolygon(point, b.boundary)) {
      return b;
    }
  }

  return null;
}
