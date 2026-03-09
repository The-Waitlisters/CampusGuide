import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';
import '../utilities/polygon_helper.dart';

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

    if (_shouldStayInCurrent(userPoint, campus)) {
      return BuildingStatus(building: _current, treatedAsInside: true);
    }

    _current = _findBestCandidate(userPoint, campus, buildings);
    return _current == null
        ? BuildingStatus.none()
        : BuildingStatus(building: _current, treatedAsInside: true);
  }

  // 1) If we have a current building on this campus, apply EXIT hysteresis
  bool _shouldStayInCurrent(LatLng userPoint, Campus campus) {
    if (_current == null || _current!.campus != campus) return false;

    final inside = isPointInPolygon(userPoint, _current!.boundary);
    final dist = inside ? 0.0 : distanceToPolygonMeters(userPoint, _current!.boundary);

    return inside || dist <= exitThresholdMeters;
  }

  // 2) Find best candidate (inside > near; otherwise closest boundary)
  CampusBuilding? _findBestCandidate(LatLng userPoint, Campus campus, List<CampusBuilding> buildings) {
    CampusBuilding? best;
    double bestDist = double.infinity;

    for (final b in buildings) {
      if (b.campus != campus) continue;

      final inside = isPointInPolygon(userPoint, b.boundary);
      final dist = inside ? 0.0 : distanceToPolygonMeters(userPoint, b.boundary);

      if ((inside || dist <= enterThresholdMeters) && dist < bestDist) {
        best = b;
        bestDist = dist;
      }
    }

    return best;
  }

}
