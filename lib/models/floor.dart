import 'indoor_poi.dart';
import 'nav_graph.dart';
import 'room.dart';

class Floor {
  final int level;
  final String label;
  final List<Room> rooms;
  final String? imagePath;
  final NavGraph? navGraph;
  /// Width / height of the source image (used to avoid stretching).
  final double imageAspectRatio;
  /// Points of interest displayed on this floor's map.
  final List<IndoorPoi> pois;

  const Floor({
    required this.level,
    required this.label,
    required this.rooms,
    this.imagePath,
    this.navGraph,
    this.imageAspectRatio = 1.0,
    this.pois = const [],
  });

  Room? roomById(String id) {
    try {
      return rooms.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Room> searchByNameOrNumber(String query) {
    if (query.trim().isEmpty) return rooms;
    final q = query.trim().toLowerCase();
    return rooms.where((r) => r.name.toLowerCase().contains(q)).toList();
  }
}
