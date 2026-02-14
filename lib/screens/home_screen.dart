import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/building_data.dart';
import '../models/campus.dart';
import '../widgets/campus_toggle.dart';
import '../models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import '../services/building_locator.dart';
import 'package:geocoding/geocoding.dart';

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
  late Future<List<CampusBuilding>> _polygonsFuture;
  Set<Polygon> _polygons = {};
  PolygonId? _selectedId;
  final Map<PolygonId, CampusBuilding> _polygonToBuilding = {};
  bool campusChange = false;
  

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
    _polygonsFuture = _getPolygonPointsFromJSON(_campus, campusChange);

    // US-1.4: start listening to device location
    _startLocationTracking();
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

      if(_isPointInPolygon(coords, _cursorBuilding!.boundary)) {
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

  Future<List<CampusBuilding>> _getPolygonPointsFromJSON(Campus campus, bool campusChange) async
  {
    // Optional delay if they were using this to simulate async loading
    await Future.delayed(const Duration(milliseconds: 100));
      
    final String rawData = await rootBundle.loadString('assets/building_data.geojson');

    final Map<String, dynamic> jsonFile = jsonDecode(rawData);
      
    final List features = jsonFile['features'] ?? [];
    debugPrint("aaaaaa");
    final List<CampusBuilding> buildings = [];

    
    for (final f in features)
    {
      
      //if(f['properties']['campus'] == campus.name) {
        final geometry = (f['geometry'] ?? {}) as Map<String, dynamic>;
        final properties = (f['properties'] ?? {}) as Map<String, dynamic>;

        final id = (properties['id'] ?? '').toString();

        //if(id.isEmpty) continue;

        final name = properties['name'].toString(); 
        final description = properties['description'].toString();
        final fullName = properties['fullName'].toString();
        final isWheelchairAccessible = properties['isWheelchairAccessible'];
        final hasBikeParking = properties['hasBikeParking'];
        final hasCarParking = properties['hasCarParking'];
        

        final openingHoursRaw = properties['openingHours'];
        final departmentsRaw = properties['departments'];
        final servicesRaw = properties['services'];

        final openingHours = (openingHoursRaw is List) ? openingHoursRaw.map((e) => e.toString()).toList() : <String>[];
        final departments = (departmentsRaw is List) ? departmentsRaw.map((e) => e.toString()).toList() : <String>[];
        final services = (servicesRaw is List) ? servicesRaw.map((e) => e.toString()).toList() : <String>[];

        final type = geometry['type'].toString();
        final coords = geometry['coordinates'];

        List<LatLng> polyPoints = [];

        if(type == 'Polygon') {
          final ring = coords[0] as List;
          polyPoints = ring.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
        } else {
          continue;
        }
        
        buildings.add(CampusBuilding(id: id, name: name, campus: campus, boundary: polyPoints, fullName: fullName, description: description, openingHours: openingHours, isWheelchairAccessible: isWheelchairAccessible, hasBikeParking: hasBikeParking, hasCarParking: hasCarParking, departments: departments, services: services));
        

      //}
      
      
    }


    return buildings;
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
      //campusChange = true;
      //_polygonsFuture = _getPolygonPointsFromJSON(campus, campusChange);
      
      
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
          _polygonsFuture = _getPolygonPointsFromJSON(_campus, campusChange);
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
        fillColor: isActiveGps ? const Color(0x803197F6) : const Color(0x80912338),
        strokeColor: isActiveGps
              ? Colors.blue
              : const Color(0xFF741C2C),
        strokeWidth: isActiveGps ? 3 : 2,
        onTap: () {
          _cursorBuilding = e;
          _updateOnTap(pid);} 
        ,);

    }).toSet();
  }

  void _updateOnTap(PolygonId id) {

    final building = _polygonToBuilding[id];
    if (building == null) return;
    isAnnex = building.fullName!.contains("Annex");

    setState(() {
    _selectedId = id;
    _cursorBuilding = building;
    _polygons = _polygons.map((p) {
      final isSelected = (p.polygonId == _selectedId);
      return p.copyWith(
        fillColorParam: isSelected ? const Color.fromARGB(255, 124, 115, 29) : const Color(0x80912338),
        strokeColorParam: isSelected ? Colors.yellow : const Color(0xFF741C2C),
      );
      }).toSet();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      
      showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      //backgroundColor: const Color.fromARGB(0, 0, 0, 0),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.25,
        minChildSize: 0.15,
        maxChildSize: 0.6,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cursorBuilding?.name} ${(isAnnex == true) ? ('Annex') : ('- ${_cursorBuilding?.fullName}')}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),
                  if(_cursorBuilding?.isWheelchairAccessible == true || _cursorBuilding?.hasBikeParking == true || _cursorBuilding?.hasCarParking == true) 
                    (Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if(_cursorBuilding?.isWheelchairAccessible == true) (Icon(Icons.accessible)), 
                        if(_cursorBuilding?.hasBikeParking == true) (Icon(Icons.pedal_bike)), 
                        if(_cursorBuilding?.hasCarParking == true) (Icon(Icons.local_parking)), 
                        
                        ],
                        )
                        ),
                  
                  const SizedBox(height:12),

                  Text(_cursorBuilding?.description ?? ''),

                  const SizedBox(height: 12),

                  const Text(
                    'Departments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  ..._cursorBuilding!.departments.map((e) => Text((e == "-") ? ("None") : (e))),

                  const SizedBox(height: 12),

                  const Text(
                    'Services:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  ..._cursorBuilding!.services.map((e) => Text((e == "-") ? ("None") : (e))),
                ],
              ),
            ),
          );
        },
      ),
    );

                  
  });
  }

  Set<Marker> _buildMarker(CampusBuilding building) {
    return {
    Marker(
      markerId: MarkerId('selected_${building.id}'),
      position: _cursorPoint!,
      infoWindow: InfoWindow(
        title: building.name,
      ),
    )
  };
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
          FutureBuilder<List<CampusBuilding>>(
            future: _polygonsFuture,
            builder: (context, snapshot)
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
                          title: _cursorBuilding?.fullName ?? 'No building',
                          snippet: _cursorBuilding?.description ?? 'No address'
                        ),
                      ),
                  },
                  onTap: (LatLng point)
                  {
                  }
                );
              }

              if(_polygons.isEmpty) {
                _polygons = _buildPolygons(snapshot.data!);
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
                polygons: _polygons,
                mapToolbarEnabled: false,
                markers: <Marker>
                {
                  if (_cursorPoint != null)
                    Marker(
                      markerId: const MarkerId('cursor'),
                      position: _cursorPoint!,
                      infoWindow: InfoWindow(
                        title: _cursorBuilding?.name ?? 'No building',
                        //snippet: _cursorBuilding?.description ?? 'No address'
                        
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

                  //Creates bottom sheet upon tapping polygon
                  
                  
                  //isSelected = true;

                    
                    showBottomSheet(
                      context: context,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Not part of campus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Please select a shaded building'),
                          ],
                        ),
                      ),
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

  

bool? isAnnex;

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
       isAnnex = b.fullName!.contains("Annex");
      return b;
    }
  }

  return null;
}

