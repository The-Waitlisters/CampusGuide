import 'dart:math' show sqrt;
import 'dart:ui' show Offset;

import '../models/floor.dart';
import '../models/nav_graph.dart';
import '../models/room.dart';

class FloorPlanEditorLoader {
  /// Parses one floor. [level] overrides the floor field on nodes when set.
  static Floor parseFloor(
      Map<String, dynamic> json, {
        int? level,
        String floorLabelPrefix = 'Floor ',
        String? imagePath,
      }) {
    final imgW = (json['imageWidth'] as num?)?.toDouble() ?? 1024.0;
    final imgH = (json['imageHeight'] as num?)?.toDouble() ?? 1024.0;

    final nodeList = _extractNodeList(json);
    final rawEdges = _extractEdgeList(json);

    final floorLevel = _resolveFloorLevel(level, nodeList);
    final label = _resolveLabel(json, floorLevel, floorLabelPrefix);

    final navNodes = _buildNavNodes(nodeList, imgW, imgH);
    final navEdges = _buildNavEdges(rawEdges, navNodes, imgW, imgH);

    final navGraph = NavGraph(nodes: navNodes, edges: navEdges)
        .withAutoConnections(pixelScale: imgW);

    final rooms = _buildRooms(navNodes);

    return Floor(
      level: floorLevel,
      label: label,
      rooms: rooms,
      imagePath: imagePath,
      navGraph: navGraph,
      imageAspectRatio: imgW / imgH,
    );
  }

  static List<dynamic> _extractNodeList(Map<String, dynamic> json) {
    final nodes = json['nodes'];
    if (nodes is List) return nodes;
    if (nodes is Map) return nodes.values.toList();
    return <dynamic>[];
  }

  static List<dynamic> _extractEdgeList(Map<String, dynamic> json) {
    final edgeList = json['edges'];
    return edgeList is List ? edgeList : <dynamic>[];
  }

  static int _resolveFloorLevel(int? level, List<dynamic> nodeList) {
    return level ??
        _readInt(nodeList.isNotEmpty ? nodeList.first : null, 'floor', 1) ??
        1;
  }

  static String _resolveLabel(
      Map<String, dynamic> json, int floorLevel, String prefix) {
    final customLabel = (json['label'] as String?)?.trim();
    final hasCustom = customLabel != null && customLabel.isNotEmpty;
    return hasCustom ? customLabel! : '$prefix$floorLevel';
  }

  static List<NavNode> _buildNavNodes(
      List<dynamic> nodeList, double imgW, double imgH) {
    final navNodes = <NavNode>[];
    for (final n in nodeList) {
      if (n is! Map) continue;
      final id = n['id'] as String? ?? 'node_${navNodes.length}';
      final raw = (n['label'] as String? ?? '').trim();
      navNodes.add(NavNode(
        id: id,
        type: n['type'] as String? ?? 'room',
        x: _readDouble(n, 'x', 0.0) / imgW,
        y: _readDouble(n, 'y', 0.0) / imgH,
        name: raw.isNotEmpty ? raw : id,
      ));
    }
    return navNodes;
  }

  static List<NavEdge> _buildNavEdges(
      List<dynamic> rawEdges, List<NavNode> navNodes, double imgW, double imgH) {
    final navEdges = <NavEdge>[];
    for (final e in rawEdges) {
      if (e is! Map) continue;
      final from = e['source'] as String?;
      final to = e['target'] as String?;
      if (from == null || to == null) continue;
      navEdges.add(NavEdge(
        from: from,
        to: to,
        weight: (e['weight'] as num?)?.toDouble() ??
            _euclidean(navNodes, from, to, imgW, imgH),
      ));
    }
    return navEdges;
  }

  static List<Room> _buildRooms(List<NavNode> navNodes) {
    const h = 0.025;
    return navNodes
        .where((n) => n.isRoom)
        .map((n) => Room(
      id: n.id,
      name: n.name,
      boundary: [
        Offset(n.x - h, n.y - h),
        Offset(n.x + h, n.y - h),
        Offset(n.x + h, n.y + h),
        Offset(n.x - h, n.y + h),
      ],
    ))
        .toList();
  }

  static List<Floor> parseMultiFloor(
      Map<String, dynamic> json, {
        String floorLabelPrefix = 'Floor ',
        String? imageAssetPrefix,
        String imageAssetSeparator = '_',
      }) {
    final floorsList = json['floors'];

    if (floorsList is List && floorsList.isNotEmpty) {
      return _parseExplicitFloors(
          floorsList, floorLabelPrefix, imageAssetPrefix, imageAssetSeparator);
    }

    final nodeList = _extractNodeList(json);
    final rawEdges = _extractEdgeList(json);
    final nodeFloorById = _buildNodeFloorMap(nodeList);

    if (nodeFloorById.isNotEmpty) {
      return _parseFloorsByNodeMap(
        json, nodeList, rawEdges, nodeFloorById,
        floorLabelPrefix, imageAssetPrefix, imageAssetSeparator,
      );
    }

    return _parseSingleFloor(
        json, nodeList, floorLabelPrefix, imageAssetPrefix, imageAssetSeparator);
  }

  static List<Floor> _parseExplicitFloors(
      List<dynamic> floorsList,
      String floorLabelPrefix,
      String? imageAssetPrefix,
      String imageAssetSeparator,
      ) {
    return [
      for (final f in floorsList)
        if (f is Map)
          parseFloor(
            Map<String, dynamic>.from(f),
            level: _readInt(f, 'level', null),
            floorLabelPrefix: floorLabelPrefix,
            imagePath: _buildImagePath(
                imageAssetPrefix, imageAssetSeparator, _readInt(f, 'level', 1)),
          ),
    ];
  }

  static Map<String, int> _buildNodeFloorMap(List<dynamic> nodeList) {
    final result = <String, int>{};
    for (final n in nodeList) {
      if (n is! Map) continue;
      final id = n['id'] as String?;
      if (id == null) continue;
      final fl = _readInt(n, 'floor', 0) ?? 0;
      if (fl == 0) continue;
      result[id] = fl;
    }
    return result;
  }

  static List<Floor> _parseFloorsByNodeMap(
      Map<String, dynamic> json,
      List<dynamic> nodeList,
      List<dynamic> rawEdges,
      Map<String, int> nodeFloorById,
      String floorLabelPrefix,
      String? imageAssetPrefix,
      String imageAssetSeparator,
      ) {
    final floorsSorted = nodeFloorById.values.toSet().toList()..sort();
    return [
      for (final fl in floorsSorted)
        parseFloor(
          _buildFloorJson(json, nodeList, rawEdges, nodeFloorById, fl),
          level: fl,
          floorLabelPrefix: floorLabelPrefix,
          imagePath: _buildImagePath(imageAssetPrefix, imageAssetSeparator, fl),
        ),
    ];
  }

  static List<Floor> _parseSingleFloor(
      Map<String, dynamic> json,
      List<dynamic> nodeList,
      String floorLabelPrefix,
      String? imageAssetPrefix,
      String imageAssetSeparator,
      ) {
    final floorLevel =
        _readInt(nodeList.isNotEmpty ? nodeList.first : null, 'floor', 1) ?? 1;
    return [
      parseFloor(
        json,
        floorLabelPrefix: floorLabelPrefix,
        imagePath: _buildImagePath(imageAssetPrefix, imageAssetSeparator, floorLevel),
      ),
    ];
  }

  static Map<String, dynamic> _buildFloorJson(
      Map<String, dynamic> json,
      List<dynamic> nodeList,
      List<dynamic> rawEdges,
      Map<String, int> nodeFloorById,
      int fl,
      ) {
    final floorJson = Map<String, dynamic>.from(json);
    floorJson['nodes'] = _nodesForFloor(nodeList, fl);
    floorJson['edges'] = _edgesForFloor(rawEdges, nodeFloorById, fl);
    return floorJson;
  }

  static List<dynamic> _nodesForFloor(List<dynamic> nodeList, int fl) {
    return [
      for (final n in nodeList)
        if (n is Map)
          if (n['id'] is String)
            if ((_readInt(n, 'floor', null) ?? fl) == fl) n,
    ];
  }

  static List<dynamic> _edgesForFloor(
      List<dynamic> rawEdges, Map<String, int> nodeFloorById, int fl) {
    return [
      for (final e in rawEdges)
        if (e is Map)
          if (e['source'] is String && e['target'] is String)
            if (_edgeBelongsToFloor(e, nodeFloorById, fl)) e,
    ];
  }

  static bool _edgeBelongsToFloor(
      Map e, Map<String, int> nodeFloorById, int fl) {
    final fromFloor = nodeFloorById[e['source'] as String];
    final toFloor = nodeFloorById[e['target'] as String];
    return (fromFloor == null || fromFloor == fl) &&
        (toFloor == null || toFloor == fl);
  }

  static String? _buildImagePath(
      String? prefix, String separator, int? level) {
    if (prefix == null) return null;
    return '$prefix$separator$level.png';
  }
  static double _euclidean(
      List<NavNode> nodes, String fromId, String toId, double w, double h) {
    final a = nodes.where((n) => n.id == fromId).firstOrNull;
    final b = nodes.where((n) => n.id == toId).firstOrNull;
    if (a == null || b == null) return 1.0;
    final dx = (a.x - b.x) * w;
    final dy = (a.y - b.y) * h;
    return sqrt(dx * dx + dy * dy);
  }

  static double _readDouble(dynamic map, String key, double def) {
    if (map is! Map) return def;
    final v = map[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? def;
    return def;
  }

  static int? _readInt(dynamic map, String key, int? def) {
    if (map is! Map) return def;
    final v = map[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }
}