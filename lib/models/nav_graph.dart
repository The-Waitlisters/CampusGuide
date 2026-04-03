import 'dart:collection';
import 'dart:math';

/// Type of edge — only [hallway] and [autoWaypoint] edges are drawn visually.
enum NavEdgeType { hallway, roomToWaypoint, autoWaypoint }

class NavNode {
  final String id;
  final String type;
  final double x;
  final double y;
  final String name;

  const NavNode({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.name = '',
  });

  bool get isRoom => switch (type) {
    'room' ||
    'stair_landing' ||
    'elevator_door' ||
    'building_entry_exit' =>
    true,
    _ => false,
  };

  bool get isWaypoint => type == 'hallway_waypoint' || type == 'doorway';
}

class NavEdge {
  final String from;
  final String to;
  final double weight;
  final NavEdgeType edgeType;

//for vertical preference
  final String? rawType;

  const NavEdge({
    required this.from,
    required this.to,
    required this.weight,
    this.edgeType = NavEdgeType.hallway,
    this.rawType,
  });
}

class NavGraph {
  final List<NavNode> nodes;
  final List<NavEdge> edges;

  late final Map<String, NavNode> _nodeMap;
  late final Map<String, List<_Nb>> _adj;

  NavGraph({required this.nodes, required this.edges}) {
    _nodeMap = {for (final n in nodes) n.id: n};
    final adj = <String, List<_Nb>>{for (final n in nodes) n.id: []};
    for (final e in edges) {
      adj.putIfAbsent(e.from, () => []).add(_Nb(e.to, e.weight));
      adj.putIfAbsent(e.to, () => []).add(_Nb(e.from, e.weight));
    }
    _adj = adj;
  }

  NavNode? nodeById(String id) => _nodeMap[id];

  /// Shortest path via Dijkstra. Returns ordered list of node IDs, or null.
  List<String>? findPath(String fromId, String toId) {
    if (fromId == toId) return [fromId];
    if (!_nodeMap.containsKey(fromId) || !_nodeMap.containsKey(toId)) {
      return null;
    }

    final dist = <String, double>{
      for (final n in nodes) n.id: double.infinity,
    };
    final prev = <String, String?>{for (final n in nodes) n.id: null};
    dist[fromId] = 0;

    final pq = SplayTreeSet<_Pq>(
          (a, b) => a.d != b.d ? a.d.compareTo(b.d) : a.id.compareTo(b.id),
    );
    pq.add(_Pq(fromId, 0));

    while (pq.isNotEmpty) {
      final cur = pq.first;
      pq.remove(cur);
      if (cur.d > dist[cur.id]!) continue;
      if (cur.id == toId) break;
      for (final nb in _adj[cur.id] ?? <_Nb>[]) {
        final alt = dist[cur.id]! + nb.w;
        if (alt < dist[nb.id]!) {
          dist[nb.id] = alt;
          prev[nb.id] = cur.id;
          pq.add(_Pq(nb.id, alt));
        }
      }
    }

    if (dist[toId]! == double.infinity) return null;
    final path = <String>[];
    String? c = toId;
    while (c != null) {
      path.add(c);
      c = prev[c];
    }
    return path.reversed.toList();
  }

  /// Returns a new graph with rooms auto-connected to nearest waypoints,
  /// and orphaned waypoints stitched into the main corridor network.
  ///
  /// [pixelScale] must match the `imageWidth`/`imageHeight` used by the
  /// explicit JSON edges so all weights are in the same unit.
  NavGraph withAutoConnections({
    double pixelScale = 2000.0,
    Set<String> excludeFromAutoConnect = const {},
  }) {
    final waypoints = nodes.where((n) => n.isWaypoint).toList();
    if (waypoints.isEmpty) return this;

    final connectedIds = <String>{};
    for (final e in edges) {
      connectedIds.add(e.from);
      connectedIds.add(e.to);
    }

    final extra = <NavEdge>[];

    // Connect each room to its nearest waypoint.
    for (final room in nodes.where((n) => n.isRoom)) {
      final candidates = waypoints
          .where((w) => !(excludeFromAutoConnect.contains(room.id) &&
          excludeFromAutoConnect.contains(w.id)))
          .toList();
      final nearest = _nearest(room, candidates);
      if (nearest != null) {
        extra.add(NavEdge(
          from: room.id,
          to: nearest.id,
          weight: _dist(room, nearest) * pixelScale,
          edgeType: NavEdgeType.roomToWaypoint,
        ));
      }
    }

    // Connect orphaned waypoints to the nearest connected waypoint. Safety net if we forgot to link something.
    final connectedWps =
    waypoints.where((n) => connectedIds.contains(n.id)).toList();
    for (final orphan in waypoints.where((n) => !connectedIds.contains(n.id))) {
      final candidates = connectedWps
          .where((w) => !(excludeFromAutoConnect.contains(orphan.id) &&
          excludeFromAutoConnect.contains(w.id)))
          .toList();
      final nearest = _nearest(orphan, candidates);
      if (nearest != null) {
        extra.add(NavEdge(
          from: orphan.id,
          to: nearest.id,
          weight: _dist(orphan, nearest) * pixelScale,
          edgeType: NavEdgeType.autoWaypoint,
        ));
      }
    }

    return NavGraph(nodes: nodes, edges: [...edges, ...extra]);
  }

  static NavNode? _nearest(NavNode from, List<NavNode> candidates) {
    NavNode? best;
    double bestDist = double.infinity;
    for (final c in candidates) {
      if (c.id == from.id) continue;
      final d = _dist(from, c);
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  static double _dist(NavNode a, NavNode b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }
}

class _Nb {
  final String id;
  final double w;
  const _Nb(this.id, this.w);
}

class _Pq {
  final String id;
  final double d;
  const _Pq(this.id, this.d);
}