import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/building_data.dart';
import '../models/campus.dart';
import '../widgets/campus_toggle.dart';

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

  Future<Set<Polygon>> _buildPolygonsForCampus(Campus campus) async {

    await Future.delayed(const Duration(milliseconds: 100));

    return campusBuildings
        .where((building) => building.campus == campus)
        .map((building) {
      return Polygon(
        polygonId: PolygonId(building.id),
        points: building.boundary,
        fillColor: const Color(0x80912338),
        strokeColor: const Color(0xFF741C2C),
        strokeWidth: 2,
      );
    }).toSet();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Waitlisters'),
      ),
      body: Stack(
        children: [
          FutureBuilder<Set<Polygon>>(
            future: _polygonsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Show map without polygons while loading
                return GoogleMap(
                  initialCameraPosition: _initialCamera,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                    }
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading polygons: ${snapshot.error}'));
              }
              // When polygons are loaded, show them on the map
              return GoogleMap(
                initialCameraPosition: _initialCamera,
                onMapCreated: (GoogleMapController controller) {
                  if (!_controller.isCompleted) {
                    _controller.complete(controller);
                  }
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                polygons: snapshot.data ?? {},
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
