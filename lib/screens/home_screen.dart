import 'dart:async';
import 'package:flutter/material.dart';
import 'package:proj/data/data_parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import 'package:proj/services/building_locator.dart';
import '../main.dart';

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
  late Future<List<CampusBuilding>> _buildingsFuture;
  List<CampusBuilding> buildingsPresent = [];
  Set<Polygon> _polygons = {};
  PolygonId? _selectedId;
  final Map<PolygonId, CampusBuilding> _polygonToBuilding = {};
  bool campusChange = false;
  final GlobalKey _mapKey = GlobalKey();

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
  }

  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
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
                        onTap: (LatLng point) => handleMapTap(point, context),
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
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }
  //to call _updateOnTap() in tests.
  @visibleForTesting
  void simulatePolygonTap(PolygonId id, LatLng tapPoint) {
    lastTap = tapPoint;
    _updateOnTap(id);
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
  const BuildingDetailContent({super.key,
    required this.building,
    required this.isAnnex,
  });

  final CampusBuilding building;
  final bool isAnnex;

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
