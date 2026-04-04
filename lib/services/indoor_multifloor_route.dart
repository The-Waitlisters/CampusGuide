import '../models/indoor_map.dart';
import '../models/nav_graph.dart';
import '../models/vertical_link.dart';



enum VerticalPreference { either, elevatorOnly, stairsOnly }

class RouteSegment {
  const RouteSegment({
    required this.floorLevel,
    required this.nodeIds,
    this.transitionInstruction,
  });

  final int floorLevel;
  final List<String> nodeIds;
  final String? transitionInstruction;
}

class IndoorRoute {
  const IndoorRoute({
    required this.segments,
    required this.directions,
  });

  final List<RouteSegment> segments;
  final List<String> directions;
}

class _FloorNodeRef {
  const _FloorNodeRef({
    required this.floorLevel,
    required this.localNodeId,
    required this.displayName,
    this.connectorKind,
  });

  final int floorLevel;
  final String localNodeId;
  final String displayName;
  final VerticalLinkKind? connectorKind;
}

class IndoorMultifloorRoutePlanner {
  static const double _verticalTransitionWeight = 25.0;

  static IndoorRoute? buildRoute({
    required IndoorMap map,
    required int startFloorLevel,
    required String startRoomId,
    required int destinationFloorLevel,
    required String destinationRoomId,
    required VerticalPreference preference,
  }) {
    final startKey = _globalNodeId(startFloorLevel, startRoomId);
    final destKey = _globalNodeId(destinationFloorLevel, destinationRoomId);

    final globalNodes = <NavNode>[];
    final globalEdges = <NavEdge>[];
    final globalToLocal = <String, _FloorNodeRef>{};

    for (final floor in map.floors) {
      final graph = floor.navGraph;
      if (graph == null) continue;

      for (final n in graph.nodes) {
        final gid = _globalNodeId(floor.level, n.id);
        globalNodes.add(NavNode(
          id: gid,
          type: n.type,
          x: n.x,
          y: n.y,
          name: n.name,
        ));
        globalToLocal[gid] = _FloorNodeRef(
          floorLevel: floor.level,
          localNodeId: n.id,
          displayName: n.name.isNotEmpty ? n.name : n.id,
          connectorKind: _detectConnectorKind(n.name.isNotEmpty ? n.name : n.id),
        );
      }

      for (final e in graph.edges) {
        globalEdges.add(NavEdge(
          from: _globalNodeId(floor.level, e.from),
          to: _globalNodeId(floor.level, e.to),
          weight: e.weight,
          edgeType: e.edgeType,
        ));
      }
    }

    final allVerticalLinks = _inferVerticalLinks(map);
    final allowedLinks = allVerticalLinks.where((l) {
      if (preference == VerticalPreference.elevatorOnly) {
        return l.kind == VerticalLinkKind.elevator;
      }
      else if (preference == VerticalPreference.stairsOnly) {
        return l.kind == VerticalLinkKind.stairs ||
            l.kind == VerticalLinkKind.escalator;
      }
      return true; // VerticalPreference.either
    });

    for (final l in allowedLinks) {
      globalEdges.add(NavEdge(
        from: _globalNodeId(l.fromFloor, l.fromNodeId),
        to: _globalNodeId(l.toFloor, l.toNodeId),
        weight: _verticalTransitionWeight,
        oneWay: l.oneWay,
      ));
    }

    final globalGraph = NavGraph(nodes: globalNodes, edges: globalEdges);
    final globalPath = globalGraph.findPath(startKey, destKey);
    if (globalPath == null || globalPath.isEmpty) {
      return null;
    }

    final refs = globalPath.map((id) => globalToLocal[id]).whereType<_FloorNodeRef>().toList();
    if (refs.isEmpty) return null;

    final segments = <RouteSegment>[];
    var currentFloor = refs.first.floorLevel;
    var currentNodes = <String>[refs.first.localNodeId];

    for (var i = 1; i < refs.length; i++) {
      final prev = refs[i - 1];
      final cur = refs[i];
      if (cur.floorLevel == currentFloor) {
        currentNodes.add(cur.localNodeId);
        continue;
      }

      final transitionText = _transitionInstruction(prev, cur);
      segments.add(RouteSegment(
        floorLevel: currentFloor,
        nodeIds: List<String>.from(currentNodes),
        transitionInstruction: transitionText,
      ));

      currentFloor = cur.floorLevel;
      currentNodes = <String>[cur.localNodeId];
    }

    segments.add(RouteSegment(
      floorLevel: currentFloor,
      nodeIds: List<String>.from(currentNodes),
    ));

    final directions = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final endRef = refs.firstWhere(
            (r) => r.floorLevel == seg.floorLevel && r.localNodeId == seg.nodeIds.last,
        orElse: () => _FloorNodeRef(
          floorLevel: seg.floorLevel,
          localNodeId: seg.nodeIds.last,
          displayName: seg.nodeIds.last,
        ),
      );
      directions.add('Floor ${seg.floorLevel}: follow the highlighted path to ${endRef.displayName}.');
      if (seg.transitionInstruction != null) {
        directions.add(seg.transitionInstruction!);
      } else if (i == segments.length - 1) {
        directions.add('Arrive at destination.');
      }
    }

    return IndoorRoute(segments: segments, directions: directions);
  }
  static List<VerticalLink> _inferVerticalLinks(IndoorMap map) {
    // Use explicit verticalLinks from JSON if provided
    if (map.verticalLinks.isNotEmpty) {
      final result = <VerticalLink>[];
      for (final l in map.verticalLinks) {
        // Both directions — Dijkstra needs edges both ways
        result.add(VerticalLink(
          fromFloor: l.fromFloor, fromNodeId: l.fromNodeId,
          toFloor: l.toFloor,   toNodeId: l.toNodeId,
          kind: l.kind,
        ));
        if(!l.oneWay) {
          result.add(VerticalLink(
            fromFloor: l.toFloor,
            fromNodeId: l.toNodeId,
            toFloor: l.fromFloor,
            toNodeId: l.fromNodeId,
            kind: l.kind,
          ));
        }
      }
      return result;
    }
    // Fallback: name-based inference for buildings without explicit links
    return _inferVerticalLinksByName(map);
  }

  static List<VerticalLink> _inferVerticalLinksByName(IndoorMap map) {
    final byKey = <String, List<_FloorNodeRef>>{};
    for (final floor in map.floors) {
      final graph = floor.navGraph;
      if (graph == null) continue;
      for (final n in graph.nodes) {
        final label = n.name.isNotEmpty ? n.name : n.id;
        final key = _canonicalConnectorKey(label);
        if (key == null) continue;
        byKey.putIfAbsent(key, () => []).add(_FloorNodeRef(
          floorLevel: floor.level,
          localNodeId: n.id,
          displayName: label,
        ));
      }
    }

    final links = <VerticalLink>[];
    for (final entry in byKey.entries) {
      final key  = entry.key;
      final refs = entry.value
        ..sort((a, b) => a.floorLevel.compareTo(b.floorLevel));

      final kind = key.contains('elevator')
              ? VerticalLinkKind.elevator
              : key.contains('escalator')
                ? VerticalLinkKind.escalator
                : VerticalLinkKind.stairs;
      for (var i = 0; i < refs.length; i++) {
        for (var j = i + 1; j < refs.length; j++) {
          final a = refs[i];
          final b = refs[j];
          links.add(VerticalLink(
            fromFloor: a.floorLevel, fromNodeId: a.localNodeId,
            toFloor:   b.floorLevel, toNodeId:   b.localNodeId,
            kind:      kind,
          ));
          links.add(VerticalLink(
            fromFloor: b.floorLevel, fromNodeId: b.localNodeId,
            toFloor:   a.floorLevel, toNodeId:   a.localNodeId,
            kind:      kind,
          ));
        }
      }
    }
    return links;
  }

  static String _transitionInstruction(_FloorNodeRef from, _FloorNodeRef to) {
    final kind = from.connectorKind ?? to.connectorKind;
    final mode = switch (kind) {
      VerticalLinkKind.elevator => 'elevator',
      VerticalLinkKind.escalator => 'escalator',
      VerticalLinkKind.stairs => 'stairs',
      null => 'vertical connector',
    };
    return 'Take the $mode from floor ${from.floorLevel} to floor ${to.floorLevel}.';
  }

  static String _globalNodeId(int floorLevel, String localId) => 'f$floorLevel::$localId';

  static String? _canonicalConnectorKey(String raw) {
    final s = raw.toLowerCase();
    if (!s.contains('elevator') &&
        !s.contains('stair') &&
        !s.contains('escalator')) return null;

    var key = s.replaceAll(RegExp(r'\d+'), ' ');
    for (final word in const ['floor', 'th', 'st', 'nd', 'rd', 'up', 'down']) {
      key = key.replaceAll(word, ' ');
    }
    key = key.replaceAll(RegExp(r'[^a-z]+'), ' ').trim();

    if (key.contains('elevator'))  return 'elevator';
    if (key.contains('escalator')) return 'escalator';
    if (key.contains('stair'))     return 'stairs';
    return null;
  }

  static VerticalLinkKind? _detectConnectorKind(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('elevator')) return VerticalLinkKind.elevator;
    if (s.contains('escalator')) return VerticalLinkKind.escalator;
    if (s.contains('stair')) return VerticalLinkKind.stairs;
    return null;
  }

  static int? floorForRoom(IndoorMap map, String roomId) {
    for (final floor in map.floors) {
      if (floor.roomById(roomId) != null) return floor.level;
    }
    return null;
  }
}
