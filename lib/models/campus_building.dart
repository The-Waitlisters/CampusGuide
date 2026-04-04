import 'package:google_maps_flutter/google_maps_flutter.dart';
import './campus.dart';
import './location.dart';

class CampusBuilding implements MapLocation {
  final String id;
  @override final String name;
  final String? fullName;
  @override final String? description;
  final Campus campus;
  final List<LatLng> boundary;
  final List<String> openingHours;
  final bool isWheelchairAccessible;
  final bool hasBikeParking;
  final bool hasCarParking;
  final bool hasMetroAccess;
  final List<String> departments;
  final List<String> services;

  CampusBuilding({
    required this.id,
    required this.name,
    required this.campus,
    required this.boundary,
    required this.fullName,
    required this.description,
    this.openingHours = const [],
    this.isWheelchairAccessible = false,
    this.hasBikeParking = false,
    this.hasCarParking = false,
    this.hasMetroAccess = false,
    this.departments = const [],
    this.services = const [],
  });
}
