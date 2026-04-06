import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../data/indoor_map_data.dart';
import '../models/campus_building.dart';
import '../models/floor.dart';
import '../models/indoor_map.dart';
import '../models/nav_graph.dart';
import '../models/room.dart';
import '../services/indoor_multifloor_route.dart';

/// Indoor map screen — view floor plan, select rooms, find a route.
class IndoorMapScreen extends StatefulWidget {
  const IndoorMapScreen({
    super.key,
    required this.building,
    this.mapLoader,
    this.initialDestinationRoomId,
  });

  final CampusBuilding building;

  /// Override the data-loader; defaults to [loadIndoorMapForBuilding].
  /// Exposed for testing so tests can inject a synchronous stub.
  final Future<IndoorMap?> Function(CampusBuilding)? mapLoader;

  /// If provided, this room will be pre-set as the destination after the map loads.
  final String? initialDestinationRoomId;

  @override
  State<IndoorMapScreen> createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends State<IndoorMapScreen> {
  IndoorMap? _indoorMap;
  bool _loading = true;
  String? _error;
  int _selectedFloorLevel = 1;
  NavGraph? _navGraph;

  Room? _selectedRoom;
  Room? _startRoom;
  int? _startFloorLevel;
  Room? _destinationRoom;
  int? _destinationFloorLevel;
  List<String>? _path; // node IDs in Dijkstra result
  IndoorRoute? _route;
  int _activeSegmentIndex = 0;
  int _activeNodeIndex = 0;
  VerticalPreference _verticalPreference = VerticalPreference.either;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadIndoorMap();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIndoorMap() async {
    _beginIndoorMapLoad();

    try {
      final loader = widget.mapLoader ?? loadIndoorMapForBuilding;
      final IndoorMap? map = await loader(widget.building);

      if (!mounted) {
        return;
      }

      _applyLoadedIndoorMap(map);
    } catch (e) {
      _handleIndoorMapLoadError(e);
    }
  }

  void _beginIndoorMapLoad() {
    setState(() {
      _loading = true;
      _error = null;
    });
  }

  void _applyLoadedIndoorMap(IndoorMap? map) {
    setState(() {
      _indoorMap = map;
      _loading = false;

      if (map == null) {
        _error = 'No indoor map for this building';
        return;
      }

      if (map.floors.isEmpty) {
        return;
      }

      _selectedFloorLevel = map.floorLevels.first;
      _navGraph = _currentFloorOf(map)?.navGraph;
      _applyInitialDestinationRoom(map);
    });
  }

  void _applyInitialDestinationRoom(IndoorMap map) {
    final String? destId = widget.initialDestinationRoomId;
    if (destId == null) return;

    final _MatchedRoom? matched = _findInitialDestinationRoom(map, destId);
    if (matched == null) return;

    _destinationRoom = matched.room;
    _destinationFloorLevel = matched.floor.level;
    _selectedFloorLevel = matched.floor.level;
    _navGraph = matched.floor.navGraph;

    final _MatchedRoom? entrance = _findEntranceRoom(map);
    if (entrance != null) {
      _startRoom = entrance.room;
      _startFloorLevel = entrance.floor.level;
    }

    _computePath();
  }

  _MatchedRoom? _findEntranceRoom(IndoorMap map) {
    for (final floor in map.floors) {
      final graph = floor.navGraph;
      if (graph == null) continue;
      for (final node in graph.nodes) {
        final id = node.id.toLowerCase();
        final name = node.name.toLowerCase();
        if (id.contains('entry') || id.contains('entrance') ||
            name.contains('entry') || name.contains('entrance')) {
          // Check if it's also a proper Room (preferred)
          final room = floor.roomById(node.id);
          if (room != null) return _MatchedRoom(floor: floor, room: room);
          // Otherwise wrap the nav node as a minimal Room
          return _MatchedRoom(
            floor: floor,
            room: Room(id: node.id, name: node.name.isNotEmpty ? node.name : 'Entrance', boundary: []),
          );
        }
      }
    }
    return null;
  }

  _MatchedRoom? _findInitialDestinationRoom(IndoorMap map, String destId) {
    final String strippedDestId = _stripBuildingPrefix(destId);

    for (final Floor floor in map.floors) {
      final Room? match = floor.rooms.cast<Room?>().firstWhere((Room? room) {
        if (room == null) {
          return false;
        }

        return room.id == destId ||
            room.name == destId ||
            room.id == strippedDestId ||
            room.name == strippedDestId;
      }, orElse: () => null);

      if (match != null) {
        return _MatchedRoom(floor: floor, room: match);
      }
    }

    return null;
  }

  String _stripBuildingPrefix(String value) {
    return value.replaceAll(RegExp(r'^[A-Za-z]+-?'), '');
  }

  void _handleIndoorMapLoadError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _error = error.toString();
    });
  }

  Floor? _currentFloorOf(IndoorMap? m) =>
      m?.getFloorByLevel(_selectedFloorLevel);

  Floor? get _currentFloor => _currentFloorOf(_indoorMap);

  List<Room> get _filteredRooms {
    final floor = _currentFloor;
    // coverage:ignore-start
    if (floor == null) return [];
    // coverage:ignore-end
    final q = _searchQuery.trim();
    if (q.isEmpty) return floor.rooms;
    return floor.searchByNameOrNumber(q);
  }

  void _onFloorChanged(int level) {
    setState(() {
      _selectedFloorLevel = level;
      _navGraph = _indoorMap?.getFloorByLevel(level)?.navGraph;

      final route = _route;
      if (route == null) {
        _path = null;
        return;
      }

      // If the floor we're switching to has a segment, show it
      final segIndex = route.segments.indexWhere((s) => s.floorLevel == level);
      if (segIndex != -1) {
        _path = route.segments[segIndex].nodeIds;
      } else {
        _path = null;
      }
    });
  }

  void _onRoomSelected(Room room, {bool fromSearch = false}) {
    setState(() => _selectedRoom = room);
    if (fromSearch) {
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _setStart() {
    setState(() {
      _startRoom = _selectedRoom;
      _startFloorLevel = _selectedFloorLevel;
      _computePath();
    });
  }

  void _setDestination() {
    setState(() {
      _destinationRoom = _selectedRoom;
      _destinationFloorLevel = _selectedFloorLevel;
      _computePath();
    });
  }

  void _computePath() {
    final map = _indoorMap;
    if (_startRoom == null ||
        _destinationRoom == null ||
        _startFloorLevel == null ||
        _destinationFloorLevel == null ||
        map == null) {
      _route = null;
      _path = null;
      return;
    }
    // Verify both rooms actually exist as NavNodes on their respective floors
    final startGraph = map.getFloorByLevel(_startFloorLevel!)?.navGraph;
    final destGraph = map.getFloorByLevel(_destinationFloorLevel!)?.navGraph;

    if (startGraph == null || startGraph.nodeById(_startRoom!.id) == null) {
      debugPrint(
        'Route error: start room "${_startRoom!.id}" not found '
        'in navGraph for floor $_startFloorLevel',
      );
      setState(() {
        _route = null;
        _path = null;
      });
      return;
    }
    if (destGraph == null || destGraph.nodeById(_destinationRoom!.id) == null) {
      debugPrint(
        'Route error: destination room "${_destinationRoom!.id}" not found '
        'in navGraph for floor $_destinationFloorLevel',
      );
      setState(() {
        _route = null;
        _path = null;
      });
      return;
    }
    _route = IndoorMultifloorRoutePlanner.buildRoute(
      map: map,
      startFloorLevel: _startFloorLevel!,
      startRoomId: _startRoom!.id,
      destinationFloorLevel: _destinationFloorLevel!,
      destinationRoomId: _destinationRoom!.id,
      preference: _verticalPreference,
    );
    _activeSegmentIndex = 0;
    _activeNodeIndex = 0;
    _syncUiToActiveSegment();
  }

  void _clearRoute() {
    setState(() {
      _startRoom = null;
      _startFloorLevel = null;
      _destinationRoom = null;
      _destinationFloorLevel = null;
      _route = null;
      _activeSegmentIndex = 0;
      _activeNodeIndex = 0;
      _path = null;
    });
  }

  void _syncUiToActiveSegment() {
    final route = _route;
    if (route == null || route.segments.isEmpty) {
      _path = null;
      return;
    }
    final seg = route.segments[_activeSegmentIndex];
    _selectedFloorLevel = seg.floorLevel;
    _navGraph = _indoorMap?.getFloorByLevel(seg.floorLevel)?.navGraph;
    _path = seg.nodeIds;
  }

  String? get _currentMarkerNodeId {
    final route = _route;
    if (route == null || route.segments.isEmpty) return null;
    final seg = route.segments[_activeSegmentIndex];
    if (seg.nodeIds.isEmpty) return null;
    final idx = _activeNodeIndex.clamp(0, seg.nodeIds.length - 1);
    return seg.nodeIds[idx];
  }

  String get _currentStepText {
    final route = _route;
    if (route == null || route.segments.isEmpty) {
      return 'No route generated';
    }
    final seg = route.segments[_activeSegmentIndex];
    final nodeId = _currentMarkerNodeId;
    if (nodeId == null) return 'No active step';
    final atSegmentEnd = _activeNodeIndex >= seg.nodeIds.length - 1;
    if (atSegmentEnd && seg.transitionInstruction != null) {
      return seg.transitionInstruction!;
    }
    if (atSegmentEnd && _activeSegmentIndex == route.segments.length - 1) {
      return 'Arrive at destination.';
    }
    final nextIndex = (_activeNodeIndex + 1).clamp(0, seg.nodeIds.length - 1);
    final nextId = seg.nodeIds[nextIndex];
    final nextName = _navGraph?.nodeById(nextId)?.name;
    final label = (nextName != null && nextName.isNotEmpty) ? nextName : nextId;
    return 'Proceed to $label on floor ${seg.floorLevel}.';
  }

  bool get _canGoNext {
    final route = _route;
    if (route == null || route.segments.isEmpty) return false;
    final seg = route.segments[_activeSegmentIndex];
    final hasNodeAdvance = _activeNodeIndex < seg.nodeIds.length - 1;
    final hasSegmentAdvance = _activeSegmentIndex < route.segments.length - 1;
    return hasNodeAdvance || hasSegmentAdvance;
  }

  void _goToNextStep() {
    final route = _route;
    if (route == null || route.segments.isEmpty) return;
    setState(() {
      final seg = route.segments[_activeSegmentIndex];
      if (_activeNodeIndex < seg.nodeIds.length - 1) {
        _activeNodeIndex++;
      } else if (_activeSegmentIndex < route.segments.length - 1) {
        _activeSegmentIndex++;
        _activeNodeIndex = 0;
        _syncUiToActiveSegment();
      }
    });
  }

  void _setVerticalPreference(VerticalPreference preference) {
    setState(() {
      _verticalPreference = preference;
      _computePath();
    });
  }

  void _showRoomActions(BuildContext context, Room room) {
    final displayName = room.name.isNotEmpty ? room.name : room.id;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle, color: Colors.green),
              title: const Text('Set as Start'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedRoom = room;
                  _startRoom = room;
                  _startFloorLevel = _selectedFloorLevel;
                  _computePath();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.blue),
              title: const Text('Set as Destination'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedRoom = room;
                  _destinationRoom = room;
                  _destinationFloorLevel = _selectedFloorLevel;
                  _computePath();
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.building.fullName ?? widget.building.name),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _indoorMap == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.building.fullName ?? widget.building.name),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'No indoor map available',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final floorLevels = _indoorMap!.floorLevels;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.building.fullName ?? widget.building.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text('Floor:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedFloorLevel,
                  items: floorLevels.map((l) {
                    final f = _indoorMap!.getFloorByLevel(l);
                    return DropdownMenuItem(
                      value: l,
                      child: Text(f?.label ?? 'Floor $l'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) _onFloorChanged(v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search room by name or number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          // Map (Flexible so body doesn't overflow on small viewports)
          if (_currentFloor != null)
            Flexible(
              child: _MapView(
                floor: _currentFloor!,
                navGraph: _navGraph,
                selectedRoom: _selectedRoom,
                startRoom: _startRoom,
                destinationRoom: _destinationRoom,
                path: _path,
                currentNodeId: _currentMarkerNodeId,
                onRoomTap: _onRoomSelected,
              ),
            ),
          // Route controls
          _RouteControls(
            selectedRoom: _selectedRoom,
            startRoom: _startRoom,
            destinationRoom: _destinationRoom,
            path: _path,
            directions: _route?.directions ?? const <String>[],
            currentStepText: _currentStepText,
            hasNext: _canGoNext,
            verticalPreference: _verticalPreference,
            onSetStart: _setStart,
            onSetDestination: _setDestination,
            onClear: _clearRoute,
            onNextStep: _goToNextStep,
            onVerticalPreferenceChanged: _setVerticalPreference,
          ),
          // Room list
          Expanded(
            child: _currentFloor == null
                ? const Center(child: Text('No floor data'))
                : ListView.builder(
                    itemCount: _filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = _filteredRooms[index];
                      final isSelected = _selectedRoom?.id == room.id;
                      final isStart = _startRoom?.id == room.id;
                      final isDest = _destinationRoom?.id == room.id;
                      final displayName = room.name.isNotEmpty
                          ? room.name
                          : room.id;
                      return ListTile(
                        leading: Icon(
                          isStart
                              ? Icons.play_circle
                              : isDest
                              ? Icons.flag
                              : Icons.meeting_room_outlined,
                          color: isStart
                              ? Colors.green
                              : isDest
                              ? Colors.blue
                              : isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: isSelected
                              ? TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        subtitle: room.accessible
                            ? null
                            : const Text('Not accessible'),
                        selected: isSelected,
                        onTap: () => _onRoomSelected(room, fromSearch: true),
                        onLongPress: () => _showRoomActions(context, room),
                        trailing: isSelected
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    tooltip: 'Set as Start',
                                    onPressed: _setStart,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.flag,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    tooltip: 'Set as Destination',
                                    onPressed: _setDestination,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map view
// ---------------------------------------------------------------------------

class _MapView extends StatelessWidget {
  const _MapView({
    required this.floor,
    required this.navGraph,
    required this.selectedRoom,
    required this.startRoom,
    required this.destinationRoom,
    required this.path,
    required this.currentNodeId,
    required this.onRoomTap,
  });

  final Floor floor;
  final NavGraph? navGraph;
  final Room? selectedRoom;
  final Room? startRoom;
  final Room? destinationRoom;
  final List<String>? path;
  final String? currentNodeId;
  final ValueChanged<Room> onRoomTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: floor.imageAspectRatio,
      child: InteractiveViewer(
        minScale: 0.1,
        maxScale: 8,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return GestureDetector(
              // coverage:ignore-start
              onTapUp: (details) {
                final nx = details.localPosition.dx / w;
                final ny = details.localPosition.dy / h;
                _handleTap(nx, ny, w, h);
              },
              // coverage:ignore-end
              child: Stack(
                children: [
                  // Background floor plan image
                  if (floor.imagePath != null)
                    Positioned.fill(
                      child: Image.asset(
                        floor.imagePath!,
                        fit: BoxFit.fill,
                        // coverage:ignore-start
                        errorBuilder: (_, _, _) =>
                            Container(color: const Color(0xFF1A1A1A)),
                        // coverage:ignore-end
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(color: const Color(0xFF1A1A1A)),
                    ),
                  // Overlay: path + room indicators
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FloorOverlayPainter(
                        navGraph: navGraph,
                        selectedRoomId: selectedRoom?.id,
                        startRoomId: startRoom?.id,
                        destinationRoomId: destinationRoom?.id,
                        path: path,
                        currentNodeId: currentNodeId,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTap(double nx, double ny, double canvasW, double canvasH) {
    final nodes = navGraph?.nodes.where((n) => n.isRoom).toList() ?? [];
    if (nodes.isEmpty) return;

    // Use a fixed physical-pixel radius so tap accuracy is consistent on both
    // square (H, VE, MB) and wide (CC) canvases.
    const tapRadiusPx = 48.0;
    final rNX = tapRadiusPx / canvasW;
    final rNY = tapRadiusPx / canvasH;

    NavNode? best;
    double bestDist = double.infinity;
    for (final n in nodes) {
      // Scale deltas into "tap-radius units" — elliptical hit region
      final dx = (n.x - nx) / rNX;
      final dy = (n.y - ny) / rNY;
      final d = sqrt(dx * dx + dy * dy);
      if (d < 1.0 && d < bestDist) {
        bestDist = d;
        best = n;
      }
    }
    if (best == null) return;

    final room = floor.roomById(best.id);
    if (room != null) onRoomTap(room);
  }
}

// ---------------------------------------------------------------------------
// Overlay painter — draws the path + room indicators on top of the image
// ---------------------------------------------------------------------------

class _FloorOverlayPainter extends CustomPainter {
  const _FloorOverlayPainter({
    required this.navGraph,
    required this.selectedRoomId,
    required this.startRoomId,
    required this.destinationRoomId,
    required this.path,
    required this.currentNodeId,
  });

  final NavGraph? navGraph;
  final String? selectedRoomId;
  final String? startRoomId;
  final String? destinationRoomId;
  final List<String>? path;
  final String? currentNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    final graph = navGraph;
    if (graph == null) return;

    final sw = size.width;
    final sh = size.height;

    // --- Draw path corridor highlight ---
    final hasPath = path != null && path!.length > 1;
    if (hasPath) {
      final pathGlow = Paint()
        ..color = const Color(0x80FF9500)
        ..strokeWidth = size.shortestSide * 0.016
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final pathLine = Paint()
        ..color = const Color(0xFFFF9500)
        ..strokeWidth = size.shortestSide * 0.007
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final pathObj = Path();
      bool first = true;
      for (final id in path!) {
        final n = graph.nodeById(id);
        if (n == null) continue;
        final p = Offset(n.x * sw, n.y * sh);
        if (first) {
          pathObj.moveTo(p.dx, p.dy);
          first = false;
        } else {
          pathObj.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(pathObj, pathGlow);
      canvas.drawPath(pathObj, pathLine);

      // Draw step dots along path
      final dotPaint = Paint()..color = const Color(0xFFFF9500);
      // coverage:ignore-start
      for (final id in path!) {
        final n = graph.nodeById(id);
        if (n == null) {
          debugPrint(
            'Path drawing: nodeById("$id") returned null — ID missing from graph',
          );
          continue;
        }
        if (!n.isWaypoint) {
          continue; // rooms are drawn separately, skip silently
        }
        canvas.drawCircle(
          Offset(n.x * sw, n.y * sh),
          size.shortestSide * 0.005,
          dotPaint,
        );
      }
      // coverage:ignore-end
    }

    // --- Draw room indicators ---
    final pathIds = path != null ? path!.toSet() : <String>{};

    for (final n in graph.nodes.where((n) => n.isRoom)) {
      final cx = n.x * sw;
      final cy = n.y * sh;
      final r = size.shortestSide * 0.016;

      if (n.id == startRoomId) {
        _drawRoomDot(
          canvas,
          cx,
          cy,
          r * 1.4,
          const Color(0xFF27AE60),
          const Color(0xFFFFFFFF),
          label: 'A',
        );
      } else if (n.id == destinationRoomId) {
        _drawRoomDot(
          canvas,
          cx,
          cy,
          r * 1.4,
          const Color(0xFF2980B9),
          const Color(0xFFFFFFFF),
          label: 'B',
        );
      } else if (n.id == selectedRoomId) {
        _drawRoomDot(
          canvas,
          cx,
          cy,
          r * 1.2,
          const Color(0xFFE67E22),
          const Color(0xFFFFFFFF),
        );
      } else if (pathIds.contains(n.id)) {
        _drawRoomDot(
          canvas,
          cx,
          cy,
          r * 0.9,
          const Color(0xCCFF9500),
          Colors.white,
        );
      }
      // Unselected rooms: no indicator drawn — the floor plan image shows them
    }

    if (currentNodeId != null) {
      final current = graph.nodeById(currentNodeId!);
      if (current != null) {
        final cx = current.x * sw;
        final cy = current.y * sh;
        final r = size.shortestSide * 0.018;
        _drawRoomDot(
          canvas,
          cx,
          cy,
          r * 1.2,
          const Color(0xFFFF2D55),
          Colors.white,
          label: '•',
        );
      }
    }
  }

  void _drawRoomDot(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Color fill,
    Color border, {
    String? label,
  }) {
    // Shadow
    canvas.drawCircle(
      Offset(cx + 1, cy + 2),
      r,
      Paint()..color = Colors.black38,
    );
    // Fill
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);
    // Border
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18,
    );
    // Label
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: r * 1.1,
            fontWeight: FontWeight.bold,
            color: border,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FloorOverlayPainter old) {
    return old.selectedRoomId != selectedRoomId ||
        old.startRoomId != startRoomId ||
        old.destinationRoomId != destinationRoomId ||
        old.path != path ||
        old.currentNodeId != currentNodeId ||
        old.navGraph != navGraph;
  }
}

// ---------------------------------------------------------------------------
// Route controls bar
// ---------------------------------------------------------------------------

class _RouteControls extends StatelessWidget {
  const _RouteControls({
    required this.selectedRoom,
    required this.startRoom,
    required this.destinationRoom,
    required this.path,
    required this.directions,
    required this.currentStepText,
    required this.hasNext,
    required this.verticalPreference,
    required this.onSetStart,
    required this.onSetDestination,
    required this.onClear,
    required this.onNextStep,
    required this.onVerticalPreferenceChanged,
  });

  final Room? selectedRoom;
  final Room? startRoom;
  final Room? destinationRoom;
  final List<String>? path;
  final List<String> directions;
  final String currentStepText;
  final bool hasNext;
  final VerticalPreference verticalPreference;
  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback onClear;
  final VoidCallback onNextStep;
  final ValueChanged<VerticalPreference> onVerticalPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedRoom != null;
    final hasRoute = startRoom != null || destinationRoom != null;

    if (!hasSelection && !hasRoute) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'Tap a room on the map or in the list to select it',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSelection)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected: ${selectedRoom!.name.isNotEmpty ? selectedRoom!.name : selectedRoom!.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onSetStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                  ),
                  child: const Text('Set Start'),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  onPressed: onSetDestination,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                  ),
                  child: const Text('Set Dest'),
                ),
              ],
            ),
          if (hasRoute) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (startRoom != null)
                  _Chip(
                    icon: Icons.play_circle,
                    color: Colors.green,
                    label: startRoom!.name.isNotEmpty
                        ? startRoom!.name
                        : startRoom!.id,
                  ),
                if (startRoom != null && destinationRoom != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                if (destinationRoom != null)
                  _Chip(
                    icon: Icons.flag,
                    color: Colors.blue,
                    label: destinationRoom!.name.isNotEmpty
                        ? destinationRoom!.name
                        : destinationRoom!.id,
                  ),
                const Spacer(),
                if (path == null &&
                    startRoom != null &&
                    destinationRoom != null)
                  const Text(
                    'No route found',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                if (path != null)
                  Text(
                    '${path!.length} steps',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear route',
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: verticalPreference == VerticalPreference.either,
                  onSelected: (_) =>
                      onVerticalPreferenceChanged(VerticalPreference.either),
                ),
                ChoiceChip(
                  label: const Text('Elevator'),
                  selected:
                      verticalPreference == VerticalPreference.elevatorOnly,
                  onSelected: (_) => onVerticalPreferenceChanged(
                    VerticalPreference.elevatorOnly,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Stairs'),
                  selected: verticalPreference == VerticalPreference.stairsOnly,
                  onSelected: (_) => onVerticalPreferenceChanged(
                    VerticalPreference.stairsOnly,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentStepText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: hasNext ? onNextStep : null,
                  child: const Text('Next Step'),
                ),
              ],
            ),
            if (directions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: directions.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${index + 1}. ${directions[index]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MatchedRoom {
  final Floor floor;
  final Room room;

  const _MatchedRoom({required this.floor, required this.room});
}
