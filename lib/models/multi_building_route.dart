import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'campus_building.dart';
import '../services/indoor_multifloor_route.dart';

enum MultiBuildingSegmentType { indoor, outdoor, transition }

class MultiBuildingSegment {
  final MultiBuildingSegmentType type;
  final CampusBuilding? building;
  final IndoorRoute? indoorRoute;

  /// Polyline for outdoor walking/transit between buildings.
  final List<LatLng>? outdoorPolyline;
  final String? durationText;
  final String? distanceText;

  final String instruction;

  const MultiBuildingSegment({
    required this.type,
    required this.instruction,
    this.building,
    this.indoorRoute,
    this.outdoorPolyline,
    this.durationText,
    this.distanceText,
  });
}

class MultiBuildingRoute {
  final CampusBuilding startBuilding;
  final String startRoomId;
  final CampusBuilding endBuilding;
  final String endRoomId;
  final List<MultiBuildingSegment> segments;
  final bool isCrossCampus;

  const MultiBuildingRoute({
    required this.startBuilding,
    required this.startRoomId,
    required this.endBuilding,
    required this.endRoomId,
    required this.segments,
    required this.isCrossCampus,
  });

  List<String> get allDirections {
    final dirs = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      switch (seg.type) {
        case MultiBuildingSegmentType.indoor:
          final bldg = seg.building?.name ?? '?';
          dirs.add('In $bldg: ${seg.instruction}');
          if (seg.indoorRoute != null) {
            dirs.addAll(seg.indoorRoute!.directions);
          }
        case MultiBuildingSegmentType.outdoor:
          dirs.add(seg.instruction);
          if (seg.durationText != null || seg.distanceText != null) {
            final parts = <String>[];
            if (seg.durationText != null) parts.add(seg.durationText!);
            if (seg.distanceText != null) parts.add(seg.distanceText!);
            dirs.add(parts.join(' - '));
          }
        case MultiBuildingSegmentType.transition:
          dirs.add(seg.instruction);
      }
    }
    return dirs;
  }
}
