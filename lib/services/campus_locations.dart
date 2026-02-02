import '../models/campus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CampusLocation {
  const CampusLocation({
    required this.name,
    required this.center,
    required this.zoom,
  });

  final String name;
  final LatLng center;
  final double zoom;
}

const Map<Campus, CampusLocation> campusInfo = {
  Campus.sgw: CampusLocation(
    name: 'SGW',
    center: LatLng(45.4973, -73.5789),
    zoom: 16,
  ),
  Campus.loyola: CampusLocation(
    name: 'Loyola',
    center: LatLng(45.4582, -73.6405),
    zoom: 16,
  ),
};
