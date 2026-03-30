import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';

class Poi {
  final String id;
  final String name;
  final String? fullName; // Optional full name
  final String? description; // Optional description
  final LatLng boundary;
  final Campus campus;
  final List<String> openingHours;
  final String poiType;

  Poi({
    required this.id,
    required this.name,
    required this.boundary,
    required this.fullName,
    required this.description,
    required this.campus,
    this.openingHours = const [],
    required this.poiType
  });
}