import 'campus_building.dart';
import 'floor.dart';
import 'vertical_link.dart';

class IndoorMap {
  final CampusBuilding building;
  final List<Floor> floors;
  final List<VerticalLink> verticalLinks;

  const IndoorMap({
    required this.building,
    required this.floors,
    this.verticalLinks = const [],
  });

  Floor? getFloorByLevel(int level) {
    try {
      return floors.firstWhere((f) => f.level == level);
    } catch (_) {
      return null;
    }
  }

  List<int> get floorLevels => floors.map((f) => f.level).toList()..sort();
}