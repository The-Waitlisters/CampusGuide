import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/building_data.dart';
import '../models/campus.dart';
import '../widgets/campus_toggle.dart';
import '../models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import '../services/building_locator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Campus _campus = Campus.sgw;
  LatLng? _cursorPoint;
  CampusBuilding? _cursorBuilding;
  late Future<Set<Polygon>> _polygonsFuture;

  // US-1.4: Current building from device location (keep existing tap/cursor logic)

  final BuildingLocator _buildingLocator = BuildingLocator(
    enterThresholdMeters: 15,
    exitThresholdMeters: 25,
  );

  StreamSubscription<Position>? _gpsSub;
  CampusBuilding? _currentBuildingFromGPS;

  @override
  void initState() {
    super.initState();
    // Start loading polygons for the initial campus
    _polygonsFuture = _buildPolygonsForCampus(_campus);

    // US-1.4: start listening to device location
    _startLocationTracking();
  }


  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
  }

  Future<Set<Polygon>> _buildPolygonsForCampus(Campus campus) async
  {
    // Optional delay if they were using this to simulate async loading
    await Future.delayed(const Duration(milliseconds: 100));

    final Set<Polygon> polys = <Polygon>{};

    for (final CampusBuilding b in campusBuildings)
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
  }


  Future<void> _goToCampus(Campus campus) async {
    final controller = await _controller.future;
    final info = campusInfo[campus]!;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: info.center, zoom: info.zoom),
      ),
    );
    // When campus changes, start loading the new set of polygons

    setState(() {
      _campus = campus;
      // Reset GPS building on campus change (prevents stale highlight)
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
      _polygonsFuture = _buildPolygonsForCampus(campus);
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

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      final userPoint = LatLng(pos.latitude, pos.longitude);

      final result = _buildingLocator.update(
        userPoint: userPoint,
        campus: _campus,
        buildings: campusBuildings,
      );

      if (!mounted) return;

      // Only rebuild polygons when the active building changes (avoid heavy redraw)
      final oldId = _currentBuildingFromGPS?.id;
      final newId = result.building?.id;

      setState(() {
        _currentBuildingFromGPS = result.building;

        if (oldId != newId) {
          _polygonsFuture = _buildPolygonsForCampus(_campus);
        }
      });
    });
  }


  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Waitlisters'),
      ),
      body: Stack(
        children: [
          FutureBuilder<Set<Polygon>>(
            future: _polygonsFuture,
            builder: (BuildContext context, AsyncSnapshot<Set<Polygon>> snapshot)
            {
              if (snapshot.connectionState == ConnectionState.waiting)
              {
                // Map without polygons while loading
                return GoogleMap(
                  initialCameraPosition: _initialCamera,
                  onMapCreated: (GoogleMapController controller)
                  {
                    if (!_controller.isCompleted)
                    {
                      _controller.complete(controller);
                    }
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: <Marker>
                  {
                    if (_cursorPoint != null)
                      Marker(
                        markerId: const MarkerId('cursor'),
                        position: _cursorPoint!,
                        infoWindow: InfoWindow(
                          title: _cursorBuilding?.name ?? 'No building',
                        ),
                      ),
                  },
                  onTap: (LatLng point)
                  {
                    final CampusBuilding? building = _findBuildingAtPoint(
                      point,
                      campusBuildings,
                      _campus,
                    );

                    debugPrint(
                      building != null
                          ? 'Selected building: ${building.name} (id=${building.id})'
                          : 'Selected building: none',
                    );

                    setState(()
                    {
                      _cursorPoint = point;
                      _cursorBuilding = building;
                    });
                  },
                );
              }

              if (snapshot.hasError)
              {
                return Center(
                  child: Text('Error loading polygons: ${snapshot.error}'),
                );
              }

              // Polygons loaded
              return GoogleMap(
                initialCameraPosition: _initialCamera,
                onMapCreated: (GoogleMapController controller)
                {
                  if (!_controller.isCompleted)
                  {
                    _controller.complete(controller);
                  }
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                polygons: snapshot.data ?? <Polygon>{},
                markers: <Marker>
                {
                  if (_cursorPoint != null)
                    Marker(
                      markerId: const MarkerId('cursor'),
                      position: _cursorPoint!,
                      infoWindow: InfoWindow(
                        title: _cursorBuilding?.name ?? 'No building',
                      ),
                    ),
                },
                onTap: (LatLng point)
                {
                  final CampusBuilding? building = _findBuildingAtPoint(
                    point,
                    campusBuildings,
                    _campus,
                  );

                  debugPrint(
                    building != null
                        ? 'Selected building: ${building.name} (id=${building.id})'
                        : 'Selected building: none',
                  );

                  setState(()
                  {
                    _cursorPoint = point;
                    _cursorBuilding = building;
                  });
                },
              );
            },
          ),

          // US-1.4 Status card (top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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


          // Pushed Campus toggle a bit lower to avoid overlap
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
        ],
      ),
    );
  }

  @override void dispose() { _gpsSub?.cancel(); super.dispose(); }
}

bool _isPointInPolygon(LatLng point, List<LatLng> polygon)
{
  double x = point.longitude;
  double y = point.latitude;

  bool inside = false;
  int j = polygon.length - 1;

  for (int i = 0; i < polygon.length; i++)
  {
    double xi = polygon[i].longitude;
    double yi = polygon[i].latitude;

    double xj = polygon[j].longitude;
    double yj = polygon[j].latitude;

    double denom = (yj - yi);
    if (denom == 0.0)
    {
      denom = 1e-12;
    }

    bool intersect =
        ((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / denom + xi);

    if (intersect)
    {
      inside = !inside;
    }

    j = i;
  }

  return inside;
}

CampusBuilding? _findBuildingAtPoint(
    LatLng point,
    List<CampusBuilding> buildings,
    Campus campus,
    )
{
  for (CampusBuilding b in buildings)
  {
    if (b.campus != campus)
    {
      continue;
    }

    if (_isPointInPolygon(point, b.boundary))
    {
      return b;
    }
  }

  return null;
}

