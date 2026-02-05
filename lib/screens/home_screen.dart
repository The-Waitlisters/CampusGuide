import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/building_data.dart'; // Import building data
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

  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
  }

  // This method creates the set of polygons to display on the map.
  // It filters the buildings based on the currently selected campus.
  Set<Polygon> _buildPolygons() {
    return campusBuildings
        .where((building) => building.campus == _campus) // Filter by campus
        .map((building) {
      return Polygon(
        polygonId: PolygonId(building.id),
        points: building.boundary,
        fillColor: const Color(0x80912338), // Corrected fill color with alpha
        strokeColor: const Color(0xFF741C2C), // Corrected stroke color with alpha
        strokeWidth: 2,
      );
    }).toSet();
  }

  Future<void> _goToCampus(Campus campus) async {
    setState(() {
      _campus = campus;
    });

    final controller = await _controller.future;
    final info = campusInfo[campus]!;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: info.center, zoom: info.zoom),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Waitlisters'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polygons: _buildPolygons(), // Add the polygons to the map
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
