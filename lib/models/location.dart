import 'package:proj/models/campus.dart';

abstract class MapLocation{
  final String id;
  final String name;
  final String? description;
  final Campus campus;

  MapLocation({required this.id, required this.name, required this.description, required this.campus});
}