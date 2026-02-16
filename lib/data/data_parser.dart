import '../models/campus_building.dart';
import '../models/campus.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataParser {
  List<CampusBuilding> buildingsPresent = [];
  
  Future<List<CampusBuilding>> getBuildingInfoFromJSON(
    Campus campus,
    bool campusChange,
  ) async {
    // Optional delay if they were using this to simulate async loading
    await Future.delayed(const Duration(milliseconds: 100));

    final String rawData = await rootBundle.loadString(
      'assets/building_data.geojson',
    );

    final Map<String, dynamic> jsonFile = jsonDecode(rawData);

    final List features = jsonFile['features'] ?? [];
    final List<CampusBuilding> buildings = [];

    for (final f in features) {
      final geometry = (f['geometry'] ?? {}) as Map<String, dynamic>;
      final properties = (f['properties'] ?? {}) as Map<String, dynamic>;

      final id = (properties['id'] ?? '').toString();

      final name = properties['name'].toString();
      final description = properties['description'].toString();
      final fullName = properties['fullName'].toString();
      final isWheelchairAccessible = properties['isWheelchairAccessible'];
      final hasBikeParking = properties['hasBikeParking'];
      final hasCarParking = properties['hasCarParking'];

      final openingHoursRaw = properties['openingHours'];
      final departmentsRaw = properties['departments'];
      final servicesRaw = properties['services'];

      final openingHours = (openingHoursRaw is List)
          ? openingHoursRaw.map((e) => e.toString()).toList()
          : <String>[];
      final departments = (departmentsRaw is List)
          ? departmentsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final services = (servicesRaw is List)
          ? servicesRaw.map((e) => e.toString()).toList()
          : <String>[];

      final type = geometry['type'].toString();
      final coords = geometry['coordinates'];

      List<LatLng> polyPoints = [];

      if (type == 'Polygon') {
        final ring = coords[0] as List;
        polyPoints = ring.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
      } else {
        continue;
      }

      buildings.add(
        CampusBuilding(
          id: id,
          name: name,
          campus: campus,
          boundary: polyPoints,
          fullName: fullName,
          description: description,
          openingHours: openingHours,
          isWheelchairAccessible: isWheelchairAccessible,
          hasBikeParking: hasBikeParking,
          hasCarParking: hasCarParking,
          departments: departments,
          services: services,
        ),
      );
      buildingsPresent = setPresentBuilding(buildings);
    }
    return buildings;
  }

  List<CampusBuilding> setPresentBuilding(List<CampusBuilding> buildings) {
    buildingsPresent = buildings;

    return buildingsPresent;
  }


}

