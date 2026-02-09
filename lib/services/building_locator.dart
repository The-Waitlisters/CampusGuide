import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';

class BuildingStatus {
  final CampusBuilding? building;
  final bool treatedAsInside;

  const BuildingStatus({required this.building, required this.treatedAsInside});

  factory BuildingStatus.none() =>
      const BuildingStatus(building: null, treatedAsInside: false);
}

/// Hysteresis-based building selection:
/// - Enter if inside OR within enterThreshold
/// - If already in a building, stay until beyond exitThreshold
class BuildingLocator {
  final double enterThresholdMeters;
  final double exitThresholdMeters;

  CampusBuilding? _current;

  BuildingLocator({
    this.enterThresholdMeters = 15,
    this.exitThresholdMeters = 25,
  }) : assert(exitThresholdMeters >= enterThresholdMeters);

  /// Clears internal hysteresis state.
  /// Call this when campus/context changes.
  void reset() {
    _current = null;
  }

  BuildingStatus update({
    required LatLng userPoint,
    required Campus campus,
    required List<CampusBuilding> buildings,
  }) {
    // 1) If we have a current building on this campus, apply EXIT hysteresis
    if (_current != null && _current!.campus == campus) {
      final inside = isPointInPolygon(userPoint, _current!.boundary);
      final dist = inside ? 0.0 : distanceToPolygonMeters(userPoint, _current!.boundary);

      if (inside || dist <= exitThresholdMeters) {
        return BuildingStatus(building: _current, treatedAsInside: true);
      }
    }

    // 2) Find best candidate (inside > near; otherwise closest boundary)
    CampusBuilding? best;
    double bestDist = double.infinity;

    for (final b in buildings) {
      if (b.campus != campus) continue;

      final inside = isPointInPolygon(userPoint, b.boundary);
      final dist = inside ? 0.0 : distanceToPolygonMeters(userPoint, b.boundary);

      if (inside || dist <= enterThresholdMeters) {
        if (dist < bestDist) {
          best = b;
          bestDist = dist;
        }
      }
    }

    _current = best;
    return best == null
        ? BuildingStatus.none()
        : BuildingStatus(building: best, treatedAsInside: true);
  }
}

/* ---------------- Geometry helpers ---------------- */

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
