import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/location.dart';

class Poi extends MapLocation{
  final LatLng boundary;
  final bool? openNow;
  final List<String?> photoName;
  final List<String> openingHours;
  final double rating;
  final String address;

  // Extended fields used by the Results / POI-details UI
  final bool? openNow;
  final List<String?>? photoName;
  final double? rating;
  final String? address;

  Poi({
    required super.id,
    required super.name,
    required super.campus,
    required super.description,
    required this.boundary,
    this.openNow,
    required this.openingHours, required this.photoName, required this.rating, required this.address
    
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Poi && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
