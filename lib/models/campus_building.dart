import 'package:google_maps_flutter/google_maps_flutter.dart';
import './campus.dart';

class CampusBuilding {
  final String id;
  final String name;
  final String? fullName; // Optional full name
  final String? description; // Optional description
  final Campus campus;
  final List<LatLng> boundary;

  CampusBuilding({
    required this.id,
    required this.name,
    required this.campus,
    required this.boundary,
    this.fullName,
    this.description,
  });
}
