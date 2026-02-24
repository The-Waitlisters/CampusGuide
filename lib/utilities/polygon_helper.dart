import 'package:google_maps_flutter/google_maps_flutter.dart';

bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  double x = point.longitude;
  double y = point.latitude;

  bool inside = false;
  int j = polygon.length - 1;

  for (int i = 0; i < polygon.length; i++) {
    double xi = polygon[i].longitude;
    double yi = polygon[i].latitude;

    double xj = polygon[j].longitude;
    double yj = polygon[j].latitude;

    double denom = (yj - yi);
    if (denom == 0.0) {
      denom = 1e-12;
    }

    bool intersect =
        ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / denom + xi);

    if (intersect) {
      inside = !inside;
    }

    j = i;
  }

  return inside;
}