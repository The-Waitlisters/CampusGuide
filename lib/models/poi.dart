import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/location.dart';

class Poi implements MapLocation {
  final String id;
  @override final String name;
  final String? fullName;
  @override final String? description;
  final LatLng boundary;
  final Campus campus;
  final List<String> openingHours;
  final String poiType;

  // Extended fields used by the Results / POI-details UI
  final bool? openNow;
  final List<String?>? photoName;
  final double? rating;
  final String? address;

  Poi({
    required this.id,
    required this.name,
    required this.campus,
    required this.description,
    required this.boundary,
    this.fullName,
    this.openingHours = const [],
    this.poiType = '',
    this.openNow,
    this.photoName,
    this.rating,
    this.address,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Poi && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
