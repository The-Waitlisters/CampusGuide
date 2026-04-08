import 'package:flutter/material.dart';

enum IndoorPoiType {
  bathroom,
  cafeteria,
  library,
  emergency,
  vending;

  IconData get icon => switch (this) {
        IndoorPoiType.bathroom  => Icons.wc,
        IndoorPoiType.cafeteria => Icons.restaurant,
        IndoorPoiType.library   => Icons.menu_book,
        IndoorPoiType.emergency => Icons.local_hospital,
        IndoorPoiType.vending   => Icons.local_cafe,
      };

  Color get color => switch (this) {
        IndoorPoiType.bathroom  => Colors.blue,
        IndoorPoiType.cafeteria => Colors.orange,
        IndoorPoiType.library   => Colors.purple,
        IndoorPoiType.emergency => Colors.red,
        IndoorPoiType.vending   => Colors.brown,
      };

  String get label => switch (this) {
        IndoorPoiType.bathroom  => 'Bathroom',
        IndoorPoiType.cafeteria => 'Cafeteria',
        IndoorPoiType.library   => 'Library',
        IndoorPoiType.emergency => 'Emergency',
        IndoorPoiType.vending   => 'Vending',
      };
}

/// A point of interest displayed on an indoor floor plan.
///
/// [x] and [y] are normalised coordinates (0..1) matching the floor plan
/// image dimensions, consistent with how [Room.boundary] is expressed.
class IndoorPoi {
  final String id;
  final String name;
  final IndoorPoiType type;
  final double x;
  final double y;

  const IndoorPoi({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
  });
}
