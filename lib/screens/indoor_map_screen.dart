import 'dart:math' show sqrt;

import 'package:flutter/material.dart';

import '../data/indoor_map_data.dart';
import '../models/campus_building.dart';
import '../models/floor.dart';
import '../models/indoor_map.dart';
import '../models/nav_graph.dart';
import '../models/room.dart';

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
  Room? _destinationRoom;
  List<String>? _path; // node IDs in Dijkstra result

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.mapLoader ?? loadIndoorMapForBuilding;
      final map = await loader(widget.building);
      if (!mounted) return;
      setState(() {
        _indoorMap = map;
        _loading = false;
        if (map == null) {
          _error = 'No indoor map for this building';
        } else if (map.floors.isNotEmpty) {
          _selectedFloorLevel = map.floorLevels.first;
          _navGraph = _currentFloorOf(map)?.navGraph;

          // Pre-set destination room if provided
          final destId = widget.initialDestinationRoomId;
          if (destId != null) {
            for (final floor in map.floors) {
              final match = floor.rooms.cast<Room?>().firstWhere(
                    (r) => r!.id == destId ||
                    r.name == destId ||
                    r.id == destId.replaceAll(RegExp(r'^[A-Za-z]+-?'), '') ||
                    r.name == destId.replaceAll(RegExp(r'^[A-Za-z]+-?'), ''),
                orElse: () => null,
              );
              if (match != null) {
                _destinationRoom = match;
                _selectedFloorLevel = floor.level;
                _navGraph = floor.navGraph;
                _computePath();
                break;
              }
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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
      _path = null;
    });
  }

  void _onRoomSelected(Room room, {bool fromSearch = false}) {
    setState(() => _selectedRoom = room);
    if (fromSearch) {
      // Clear search + hide keyboard so the map is visible with the selection
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _setStart() {
    setState(() {
      _startRoom = _selectedRoom;
      _computePath();
    });
  }

  void _setDestination() {
    setState(() {
      _destinationRoom = _selectedRoom;
      _computePath();
    });
  }

  void _computePath() {
    if (_startRoom == null || _destinationRoom == null || _navGraph == null) {
      _path = null;
      return;
    }
    _path = _navGraph!.findPath(_startRoom!.id, _destinationRoom!.id);
  }

  void _clearRoute() {
    setState(() {
      _startRoom = null;
      _destinationRoom = null;
      _path = null;
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
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.play_circle, color: Colors.green),
              title: const Text('Set as Start'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedRoom = room;
                  _startRoom = room;
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
                Text(_error ?? 'No indoor map available',
                    textAlign: TextAlign.center),
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
              onRoomTap: _onRoomSelected,
              ),
            ),
          // Route controls
          _RouteControls(
            selectedRoom: _selectedRoom,
            startRoom: _startRoom,
            destinationRoom: _destinationRoom,
            path: _path,
            onSetStart: _setStart,
            onSetDestination: _setDestination,
            onClear: _clearRoute,
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
                      final displayName =
                          room.name.isNotEmpty ? room.name : room.id;
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
                                  color:
                                      Theme.of(context).colorScheme.primary,
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
                                    icon: const Icon(Icons.play_circle,
                                        color: Colors.green, size: 20),
                                    tooltip: 'Set as Start',
                                    onPressed: _setStart,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.flag,
                                        color: Colors.blue, size: 20),
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
// Indoor map sheet — renders indoor map as a draggable bottom sheet
// ---------------------------------------------------------------------------

class IndoorMapSheet extends StatefulWidget {
  const IndoorMapSheet({
    super.key,
    required this.building,
    this.initialDestinationRoomId,
    this.mapLoader,
  });

  final CampusBuilding building;
  final String? initialDestinationRoomId;
  final Future<IndoorMap?> Function(CampusBuilding)? mapLoader;

  @override
  State<IndoorMapSheet> createState() => _IndoorMapSheetState();
}

class _IndoorMapSheetState extends State<IndoorMapSheet> {
  IndoorMap? _indoorMap;
  bool _loading = true;
  String? _error;
  int _selectedFloorLevel = 1;
  NavGraph? _navGraph;
  Room? _selectedRoom;
  Room? _startRoom;
  Room? _destinationRoom;
  List<String>? _path;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadIndoorMap();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIndoorMap() async {
    setState(() { _loading = true; _error = null; });
    try {
      final loader = widget.mapLoader ?? loadIndoorMapForBuilding;
      final map = await loader(widget.building);
      if (!mounted) return;
      setState(() {
        _indoorMap = map;
        _loading = false;
        if (map == null) {
          _error = 'No indoor map for this building';
        } else if (map.floors.isNotEmpty) {
          _selectedFloorLevel = map.floorLevels.first;
          _navGraph = _currentFloorOf(map)?.navGraph;
          final destId = widget.initialDestinationRoomId;
          if (destId != null) {
            for (final floor in map.floors) {
              final stripped = destId.replaceAll(RegExp(r'^[A-Za-z]+-?'), '');
              final match = floor.rooms.cast<Room?>().firstWhere(
                    (r) => r!.id == destId || r.name == destId || r.id == stripped || r.name == stripped,
                orElse: () => null,
              );
              if (match != null) {
                _destinationRoom = match;
                _selectedFloorLevel = floor.level;
                _navGraph = floor.navGraph;
                _computePath();
                break;
              }
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Floor? _currentFloorOf(IndoorMap? m) => m?.getFloorByLevel(_selectedFloorLevel);
  Floor? get _currentFloor => _currentFloorOf(_indoorMap);

  List<Room> get _filteredRooms {
    final floor = _currentFloor;
    if (floor == null) return [];
    final q = _searchQuery.trim();
    if (q.isEmpty) return floor.rooms;
    return floor.searchByNameOrNumber(q);
  }

  void _onFloorChanged(int level) {
    setState(() {
      _selectedFloorLevel = level;
      _navGraph = _indoorMap?.getFloorByLevel(level)?.navGraph;
      _path = null;
    });
  }

  void _onRoomSelected(Room room, {bool fromSearch = false}) {
    setState(() { _selectedRoom = room; });
  }

  void _setStart() {
    if (_selectedRoom == null) return;
    setState(() { _startRoom = _selectedRoom; _computePath(); });
  }

  void _setDestination() {
    if (_selectedRoom == null) return;
    setState(() { _destinationRoom = _selectedRoom; _computePath(); });
  }

  void _computePath() {
    if (_startRoom == null || _destinationRoom == null || _navGraph == null) {
      setState(() { _path = null; });
      return;
    }
    final result = _navGraph!.findPath(_startRoom!.id, _destinationRoom!.id);
    setState(() { _path = result; });
    if (result == null) { _startRoom = null; _destinationRoom = null; }
  }

  void _clearRoute() {
    setState(() { _startRoom = null; _destinationRoom = null; _path = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _indoorMap == null) {
      return Center(child: Text(_error ?? 'No indoor map available', textAlign: TextAlign.center));
    }

    final floorLevels = _indoorMap!.floorLevels;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.building.fullName ?? widget.building.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text('Floor:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: _selectedFloorLevel,
                isDense: true,
                items: floorLevels.map((l) {
                  final f = _indoorMap!.getFloorByLevel(l);
                  return DropdownMenuItem(value: l, child: Text(f?.label ?? 'Floor $l'));
                }).toList(),
                onChanged: (v) { if (v != null) _onFloorChanged(v); },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
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
        if (_currentFloor != null)
          Flexible(
            child: _MapView(
              floor: _currentFloor!,
              navGraph: _navGraph,
              selectedRoom: _selectedRoom,
              startRoom: _startRoom,
              destinationRoom: _destinationRoom,
              path: _path,
              onRoomTap: _onRoomSelected,
            ),
          ),
        _RouteControls(
          selectedRoom: _selectedRoom,
          startRoom: _startRoom,
          destinationRoom: _destinationRoom,
          path: _path,
          onSetStart: _setStart,
          onSetDestination: _setDestination,
          onClear: _clearRoute,
        ),
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
              final displayName = room.name.isNotEmpty ? room.name : room.id;
              return ListTile(
                leading: Icon(
                  isStart ? Icons.play_circle : isDest ? Icons.flag : Icons.meeting_room_outlined,
                  color: isStart ? Colors.green : isDest ? Colors.blue : isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(displayName,
                  style: isSelected ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary) : null,
                ),
                subtitle: room.accessible ? null : const Text('Not accessible'),
                selected: isSelected,
                onTap: () => _onRoomSelected(room, fromSearch: true),
                trailing: isSelected ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.play_circle, color: Colors.green, size: 20), tooltip: 'Set as Start', onPressed: _setStart, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.flag, color: Colors.blue, size: 20), tooltip: 'Set as Destination', onPressed: _setDestination, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> showIndoorMapSheet(
    BuildContext context, {
      required CampusBuilding building,
      String? initialDestinationRoomId,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, __) => IndoorMapSheet(
        building: building,
        initialDestinationRoomId: initialDestinationRoomId,
      ),
    ),
  );
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
    required this.onRoomTap,
  });

  final Floor floor;
  final NavGraph? navGraph;
  final Room? selectedRoom;
  final Room? startRoom;
  final Room? destinationRoom;
  final List<String>? path;
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
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
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
  });

  final NavGraph? navGraph;
  final String? selectedRoomId;
  final String? startRoomId;
  final String? destinationRoomId;
  final List<String>? path;

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
        if (n == null || (!n.isWaypoint)) continue;
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
        _drawRoomDot(canvas, cx, cy, r * 1.4, const Color(0xFF27AE60),
            const Color(0xFFFFFFFF), label: 'A');
      } else if (n.id == destinationRoomId) {
        _drawRoomDot(canvas, cx, cy, r * 1.4, const Color(0xFF2980B9),
            const Color(0xFFFFFFFF), label: 'B');
      } else if (n.id == selectedRoomId) {
        _drawRoomDot(canvas, cx, cy, r * 1.2, const Color(0xFFE67E22),
            const Color(0xFFFFFFFF));
      } else if (pathIds.contains(n.id)) {
        _drawRoomDot(
            canvas, cx, cy, r * 0.9, const Color(0xCCFF9500), Colors.white);
      }
      // Unselected rooms: no indicator drawn — the floor plan image shows them
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
      tp.paint(
          canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FloorOverlayPainter old) {
    return old.selectedRoomId != selectedRoomId ||
        old.startRoomId != startRoomId ||
        old.destinationRoomId != destinationRoomId ||
        old.path != path ||
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
    required this.onSetStart,
    required this.onSetDestination,
    required this.onClear,
  });

  final Room? selectedRoom;
  final Room? startRoom;
  final Room? destinationRoom;
  final List<String>? path;
  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback onClear;

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
                    label:
                        startRoom!.name.isNotEmpty ? startRoom!.name : startRoom!.id,
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
          ],
        ],
      ),
    );
  }
}


class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.color,
    required this.label,
  });

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
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
