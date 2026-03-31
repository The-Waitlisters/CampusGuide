import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';

class Poi {
  final String id;
  final String name;
  final String? description; 
  final LatLng boundary;
  final bool? openNow;
  final List<String?> photoName;
  final List<String> openingHours;
  final double rating;
  final String address;
  final Campus campus;

  Poi({
    required this.id,
    required this.name,
    required this.boundary,
    required this.description,
    this.openNow,
    required this.openingHours, required this.photoName, required this.rating, required this.address, required this.campus
    
  });
}