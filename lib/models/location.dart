/// Marker interface for items that appear in map search results.
/// Both [CampusBuilding] and [Poi] implement this interface.
abstract class MapLocation {
  String get name;
  String? get description;
}
