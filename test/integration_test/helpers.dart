import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus_building.dart';

/// Returns the centroid of a polygon boundary.
/// Used in tests to produce a point that is reliably inside a building shape.
LatLng polygonCenter(List<LatLng> points) {
  double lat = 0;
  double lng = 0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}

/// Returns the first building matching [campus] that also has a non-null,
/// non-empty fullName. Useful for tests that assert on fullName display.
CampusBuilding firstBuildingWithFullName(
    List<CampusBuilding> buildings, dynamic campus) {
  return buildings.firstWhere(
        (b) => b.campus == campus && (b.fullName ?? '').trim().isNotEmpty,
  );
}