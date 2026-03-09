import 'campus_building.dart';
import 'floor.dart';

class IndoorMap {
  final CampusBuilding building;
  final List<Floor> floors;

  const IndoorMap({
    required this.building,
    required this.floors,
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
