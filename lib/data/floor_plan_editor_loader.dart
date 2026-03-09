import 'dart:math' show sqrt;
import 'dart:ui' show Offset;

import '../models/floor.dart';
import '../models/nav_graph.dart';
import '../models/room.dart';

/// Converts floor-plan-editor export JSON into [Floor] + [NavGraph].
///
/// Expected JSON shape (from https://github.com/gabrielshufelt/floor-plan-editor):
/// ```json
/// {
///   "imageWidth": 2000,
///   "imageHeight": 2000,
///   "nodes": [
///     { "id": "...", "type": "room", "floor": 8, "x": 100, "y": 200, "label": "H-801" }
///   ],
///   "edges": [ { "source": "...", "target": "...", "type": "hallway", "weight": 10 } ]
/// }
/// ```
class FloorPlanEditorLoader {
  /// Parses one floor. [level] overrides the floor field on nodes when set.
  static Floor parseFloor(
    Map<String, dynamic> json, {
    int? level,
    String floorLabelPrefix = 'Floor ',
    String? imagePath,
  }) {
    final nodes = json['nodes'];
    final nodeList = nodes is List
        ? nodes
        : (nodes is Map ? nodes.values.toList() : <dynamic>[]);

    final edgeList = json['edges'];
    final rawEdges = edgeList is List ? edgeList : <dynamic>[];

    final imgW = (json['imageWidth'] as num?)?.toDouble() ?? 1024.0;
    final imgH = (json['imageHeight'] as num?)?.toDouble() ?? 1024.0;

    final floorLevel =
        level ?? _readInt(nodeList.isNotEmpty ? nodeList.first : null, 'floor', 1) ?? 1;
    final customLabel = (json['label'] as String?)?.trim();
    final label = (customLabel != null && customLabel.isNotEmpty)
        ? customLabel
        : '$floorLabelPrefix$floorLevel';

    // --- Build NavGraph (all node types) ---
    final navNodes = <NavNode>[];
    for (final n in nodeList) {
      if (n is! Map) continue;
      final id = n['id'] as String? ?? 'node_${navNodes.length}';
      final type = n['type'] as String? ?? 'room';
      final x = _readDouble(n, 'x', 0.0) / imgW;
      final y = _readDouble(n, 'y', 0.0) / imgH;
      final raw = (n['label'] as String? ?? '').trim();
      // Fall back to the node ID so room numbers like "801" display correctly.
      final labelStr = raw.isNotEmpty ? raw : id;
      navNodes.add(NavNode(id: id, type: type, x: x, y: y, name: labelStr));
    }

    final navEdges = <NavEdge>[];
    for (final e in rawEdges) {
      if (e is! Map) continue;
      final from = e['source'] as String?;
      final to = e['target'] as String?;
      if (from == null || to == null) continue;
      final w = (e['weight'] as num?)?.toDouble() ??
          _euclidean(navNodes, from, to, imgW, imgH);
      navEdges.add(NavEdge(from: from, to: to, weight: w));
    }

    final rawGraph = NavGraph(nodes: navNodes, edges: navEdges);
    final navGraph = rawGraph.withAutoConnections(pixelScale: imgW);

    // --- Build displayable Room list (room-type nodes only) ---
    final rooms = <Room>[];
    for (final n in navNodes) {
      if (!n.isRoom) continue;
      final nx = n.x;
      final ny = n.y;
      const h = 0.025; // touch half-size (larger than drawn indicator)
      rooms.add(Room(
        id: n.id,
        name: n.name,
        boundary: [
          Offset(nx - h, ny - h),
          Offset(nx + h, ny - h),
          Offset(nx + h, ny + h),
          Offset(nx - h, ny + h),
        ],
      ));
    }

    return Floor(
      level: floorLevel,
      label: label,
      rooms: rooms,
      imagePath: imagePath,
      navGraph: navGraph,
      imageAspectRatio: imgW / imgH,
    );
  }

  /// Parses a multi-floor file.
  /// [imageAssetPrefix] produces per-floor images, e.g. `assets/indoor/H` → `assets/indoor/H_8.png`.
  static List<Floor> parseMultiFloor(
    Map<String, dynamic> json, {
    String floorLabelPrefix = 'Floor ',
    String? imageAssetPrefix,
  }) {
    final floorsList = json['floors'];
    if (floorsList is! List || floorsList.isEmpty) {
      return [parseFloor(json, floorLabelPrefix: floorLabelPrefix)];
    }

    return [
      for (final f in floorsList)
        if (f is Map)
          parseFloor(
            Map<String, dynamic>.from(f),
            level: _readInt(f, 'level', null),
            floorLabelPrefix: floorLabelPrefix,
            imagePath: imageAssetPrefix != null
                ? '${imageAssetPrefix}_${_readInt(f, 'level', 1)}.png'
                : null,
          ),
    ];
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
