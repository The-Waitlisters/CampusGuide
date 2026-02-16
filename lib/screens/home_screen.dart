import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/building_data.dart';
import '../models/campus.dart';
import '../widgets/campus_toggle.dart';
import '../models/campus_building.dart';

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

  @override
  void initState() {
    super.initState();
    // Start loading polygons for the initial campus
    _polygonsFuture = _buildPolygonsForCampus(_campus);
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

      polys.add(
        Polygon(
          polygonId: PolygonId(b.id),
          points: b.boundary,
          fillColor: const Color(0x80912338),
          strokeColor: const Color(0xFF741C2C),
          strokeWidth: 2,
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
      _polygonsFuture = _buildPolygonsForCampus(campus);
    });
  }

  // Hugo - added a method to remove the need for code duplication
  void _handleMapTap(
      LatLng point,
      List<CampusBuilding> campusBuildings,
      ) {
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

    setState(() {
      _cursorPoint = point;
      _cursorBuilding = building;
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
                  onTap: (point) => _handleMapTap(point, campusBuildings), // hugo - call to method (fix)
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
                onTap: (point) => _handleMapTap(point, campusBuildings), // hugo - call to method (fix)/
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
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

