import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';

bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  bool inside = false;
  int j = polygon.length - 1;

  for (int i = 0; i < polygon.length; i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final denom = (yj - yi);
    final safeDenom = denom == 0 ? 1e-12 : denom;

    final intersect =
        ((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude <
                (xj - xi) * (point.latitude - yi) / safeDenom + xi);

    if (intersect) inside = !inside;
    j = i;
  }

  return inside;
}

double distanceToPolygonMeters(LatLng p, List<LatLng> poly) {
  double best = double.infinity;
  for (int i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final d = pointToSegmentMeters(p, a, b);
    if (d < best) best = d;
  }
  return best;
}

double pointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  const r = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180.0;

  // Local flat approximation around p
  final lat0 = toRad(p.latitude);

  double x(LatLng l) => toRad(l.longitude - p.longitude) * r * math.cos(lat0);
  double y(LatLng l) => toRad(l.latitude - p.latitude) * r;

  final ax = x(a), ay = y(a);
  final bx = x(b), by = y(b);

  final vx = bx - ax, vy = by - ay;

  // projection of origin (0,0) onto segment AB in this local system
  final c2 = vx * vx + vy * vy;
  if (c2 == 0) return math.sqrt(ax * ax + ay * ay);

  final t = (-(ax * vx + ay * vy)) / c2;
  final tt = t.clamp(0.0, 1.0);

  final px = ax + tt * vx;
  final py = ay + tt * vy;

  return math.sqrt(px * px + py * py);
}

CampusBuilding? findBuildingAtPoint(LatLng point, List<CampusBuilding> buildings, Campus campus) {
  for (final b in buildings) {
    if (b.campus != campus) {
      continue;
    }

    if (isPointInPolygon(point, b.boundary)) {
      return b;
    }
  }

  return null;
}

LatLng polygonCenter(List<LatLng> pts) {
  if (pts.isEmpty) return const LatLng(0, 0);

  double lat = 0;
  double lng = 0;
  for (final p in pts) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / pts.length, lng / pts.length);
}