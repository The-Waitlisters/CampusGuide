import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/location.dart';

class CampusBuilding extends MapLocation{

  final String? fullName; // Optional full name
  final List<LatLng> boundary;
  final List<String> openingHours;
  final bool isWheelchairAccessible;
  final bool hasBikeParking;
  final bool hasCarParking;
  final bool hasMetroAccess;
  final List<String> departments;
  final List<String> services;

  CampusBuilding({
    required super.id,
    required super.name,
    required super.campus,
    required super.description,
    required this.boundary,
    required this.fullName,
    this.openingHours = const [],
    this.isWheelchairAccessible = false,
    this.hasBikeParking = false,
    this.hasCarParking = false,
    this.hasMetroAccess = false,
    this.departments = const [],
    this.services = const [],
  });
}
