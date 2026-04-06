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

  List<String> get allDirections => segments.expand(_segmentDirections).toList();

  List<String> _segmentDirections(MultiBuildingSegment seg) {
    return switch (seg.type) {
      MultiBuildingSegmentType.indoor    => _indoorDirections(seg),
      MultiBuildingSegmentType.outdoor   => _outdoorDirections(seg),
      MultiBuildingSegmentType.transition => [seg.instruction],
    };
  }

  List<String> _indoorDirections(MultiBuildingSegment seg) {
    final bldg = seg.building?.name ?? '?';
    return [
      'In $bldg: ${seg.instruction}',
      ...?seg.indoorRoute?.directions,
    ];
  }

  List<String> _outdoorDirections(MultiBuildingSegment seg) {
    final summary = [seg.durationText, seg.distanceText]
        .nonNulls
        .join(' - ');
    return [
      seg.instruction,
      if (summary.isNotEmpty) summary,
    ];
  }
}
