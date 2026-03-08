import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';
import '../services/building_locator.dart';
import '../services/directions/transport_mode_strategy.dart';
import '../utilities/polygon_helper.dart';


abstract final class RouteLogic {
  static const double defaultModeThresholdMeters = 2500;

  static Campus? campusAtPoint(LatLng point, List<CampusBuilding> buildings) {
    if (findBuildingAtPoint(point, buildings, Campus.sgw) != null) {
      return Campus.sgw;
    }
    if (findBuildingAtPoint(point, buildings, Campus.loyola) != null) {
      return Campus.loyola;
    }
    return null;
  }

  static TransportModeStrategy? defaultMode({
    required Campus? endCampus,
    Campus? startCampus,
    LatLng? startPoint,
    LatLng? endPoint,
    required bool isCurrentLocationStart,
  }) {
    if (endCampus == null) return null;

    if (isCurrentLocationStart && startPoint != null && endPoint != null) {
      final distanceMeters = Geolocator.distanceBetween(
        startPoint.latitude,
        startPoint.longitude,
        endPoint.latitude,
        endPoint.longitude,
      );
      return distanceMeters < defaultModeThresholdMeters
          ? WalkStrategy()
          : ShuttleStrategy();
    }

    if (startCampus == null) return null;
    return startCampus == endCampus ? WalkStrategy() : ShuttleStrategy();
  }
}