import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/campus_building.dart';
import '../models/floor.dart';
import '../models/indoor_map.dart';
import '../models/nav_graph.dart';
import '../services/directions/transport_mode_strategy.dart';
import '../services/indoor_multifloor_route.dart';
import '../services/multi_building_route_planner.dart';
import '../utilities/polygon_helper.dart';

enum NavigationPhase { indoorStart, outdoor, indoorEnd }

class MultiBuildingRouteScreen extends StatefulWidget {
  final CampusBuilding startBuilding;
  final CampusBuilding endBuilding;
  final String startRoomId;
  final String endRoomId;
  final IndoorMap startIndoorMap;
  final IndoorMap endIndoorMap;
  final String transportModeLabel;

  /// Outdoor route data (pre-computed by HomeScreen).
  final List<LatLng>? outdoorPolyline;
  final String? outdoorDuration;
  final String? outdoorDistance;

  final DirectionsClient? directionsClient;
  final Future<IndoorMap?> Function(CampusBuilding)? mapLoader;

  const MultiBuildingRouteScreen({
    super.key,
    required this.startBuilding,
    required this.endBuilding,
    required this.startRoomId,
    required this.endRoomId,
    required this.startIndoorMap,
    required this.endIndoorMap,
    required this.transportModeLabel,
    this.outdoorPolyline,
    this.outdoorDuration,
    this.outdoorDistance,
    this.directionsClient,
    this.mapLoader,
  });

  @override
  State<MultiBuildingRouteScreen> createState() =>
      _MultiBuildingRouteScreenState();
}

class _MultiBuildingRouteScreenState extends State<MultiBuildingRouteScreen> {
  NavigationPhase _phase = NavigationPhase.indoorStart;
  IndoorRoute? _startIndoorRoute;
  IndoorRoute? _endIndoorRoute;
  int _activeRouteSegment = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _computeRoutes();
  }

  Future<void> _computeRoutes() async {
    try {
      final startMap = widget.startIndoorMap;
      final endMap = widget.endIndoorMap;

      final startExitNode =
          MultiBuildingRoutePlanner.findEntryExitNode(startMap);
      final endEntryNode =
          MultiBuildingRoutePlanner.findEntryExitNode(endMap);

      final startFloor = IndoorMultifloorRoutePlanner.floorForRoom(
          startMap, widget.startRoomId);
      final endFloor = IndoorMultifloorRoutePlanner.floorForRoom(
          endMap, widget.endRoomId);

      debugPrint('MultiBuilding: startRoom=${widget.startRoomId} floor=$startFloor '
          'exitNode=$startExitNode');
      debugPrint('MultiBuilding: endRoom=${widget.endRoomId} floor=$endFloor '
          'entryNode=$endEntryNode');

      if (startFloor != null) {
        final exitNodeId = startExitNode ?? widget.startRoomId;
        final exitFloor = IndoorMultifloorRoutePlanner.floorForRoom(
                startMap, exitNodeId) ??
            startMap.floorLevels.first; // coverage:ignore-line

        if (exitNodeId != widget.startRoomId) {
          _startIndoorRoute = IndoorMultifloorRoutePlanner.buildRoute(
            map: startMap,
            startFloorLevel: startFloor,
            startRoomId: widget.startRoomId,
            destinationFloorLevel: exitFloor,
            destinationRoomId: exitNodeId,
            preference: VerticalPreference.either,
          );
          debugPrint('MultiBuilding: startRoute=${_startIndoorRoute != null ? '${_startIndoorRoute!.segments.length} segs' : 'NULL'}');
        }
      }

      if (endFloor != null) {
        final entryNodeId = endEntryNode ?? widget.endRoomId;
        final entryFloor = IndoorMultifloorRoutePlanner.floorForRoom(
                endMap, entryNodeId) ??
            endMap.floorLevels.first; // coverage:ignore-line

        if (entryNodeId != widget.endRoomId) {
          _endIndoorRoute = IndoorMultifloorRoutePlanner.buildRoute(
            map: endMap,
            startFloorLevel: entryFloor,
            startRoomId: entryNodeId,
            destinationFloorLevel: endFloor,
            destinationRoomId: widget.endRoomId,
            preference: VerticalPreference.either,
          );
          debugPrint('MultiBuilding: endRoute=${_endIndoorRoute != null ? '${_endIndoorRoute!.segments.length} segs' : 'NULL'}');
        }
      }
    // coverage:ignore-start
    } catch (e, st) {
      debugPrint('MultiBuilding: _computeRoutes ERROR: $e\n$st');
    }
    // coverage:ignore-end

    if (mounted) setState(() => _loading = false);
  }

  String get _startBldgName =>
      widget.startBuilding.fullName ?? widget.startBuilding.name;
  String get _endBldgName =>
      widget.endBuilding.fullName ?? widget.endBuilding.name;
  bool get _isCrossCampus =>
      widget.startBuilding.campus != widget.endBuilding.campus;

  /// Multi-floor indoor routes: advance one segment at a time before leaving the phase.
  bool get _indoorStartOnLastSegment {
    final r = _startIndoorRoute;
    if (r == null || r.segments.isEmpty) {
      return true;
    }
    return _activeRouteSegment >= r.segments.length - 1;
  }

  bool get _indoorEndOnLastSegment {
    final r = _endIndoorRoute;
    if (r == null || r.segments.isEmpty) {
      return true;
    }
    return _activeRouteSegment >= r.segments.length - 1;
  }

  void _onPhaseContinuePressed() {
    switch (_phase) {
      case NavigationPhase.indoorStart:
        if (_startIndoorRoute != null &&
            _startIndoorRoute!.segments.length > 1 &&
            !_indoorStartOnLastSegment) {
          setState(() => _activeRouteSegment++);
          return;
        }
        _completePhase();
      case NavigationPhase.outdoor:
        _completePhase();
      case NavigationPhase.indoorEnd:
        if (_endIndoorRoute != null &&
            _endIndoorRoute!.segments.length > 1 &&
            !_indoorEndOnLastSegment) {
          setState(() => _activeRouteSegment++);
          return;
        }
        _completePhase();
    }
  }

  void _completePhase() {
    setState(() {
      switch (_phase) {
        case NavigationPhase.indoorStart:
          _phase = NavigationPhase.outdoor;
          _activeRouteSegment = 0;
        case NavigationPhase.outdoor:
          _phase = NavigationPhase.indoorEnd;
          _activeRouteSegment = 0;
        case NavigationPhase.indoorEnd:
          Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // coverage:ignore-start
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preparing navigation...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // coverage:ignore-end

    return Scaffold(
      body: Column(
        children: [
          _buildPhaseBar(context),
          Expanded(child: _buildPhaseContent()),
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildPhaseBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Exit navigation',
                ),
                Expanded(
                  child: Text(
                    _phaseTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _phaseChip(
                  NavigationPhase.indoorStart,
                  Icons.map,
                  widget.startBuilding.name,
                ),
                _phaseArrow(),
                _phaseChip(
                  NavigationPhase.outdoor,
                  Icons.directions_walk,
                  widget.transportModeLabel,
                ),
                _phaseArrow(),
                _phaseChip(
                  NavigationPhase.indoorEnd,
                  Icons.map,
                  widget.endBuilding.name,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _phaseTitle => switch (_phase) {
        NavigationPhase.indoorStart =>
          'Navigate to exit — $_startBldgName',
        NavigationPhase.outdoor =>
          '${widget.transportModeLabel} to $_endBldgName',
        NavigationPhase.indoorEnd =>
          'Navigate inside — $_endBldgName',
      };

  Widget _phaseChip(NavigationPhase phase, IconData icon, String label) {
    final isActive = _phase == phase;
    final isDone = _phase.index > phase.index;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : isDone
            ? Colors.green
            : Colors.grey.shade400;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isActive ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDone ? Icons.check_circle : icon,
                size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child:
          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
    );
  }

  Widget _buildPhaseContent() {
    return switch (_phase) {
      NavigationPhase.indoorStart => _buildIndoorPhase(
          indoorMap: widget.startIndoorMap,
          indoorRoute: _startIndoorRoute,
          buildingName: _startBldgName,
          isStart: true,
        ),
      NavigationPhase.outdoor => _buildOutdoorPhase(),
      NavigationPhase.indoorEnd => _buildIndoorPhase(
          indoorMap: widget.endIndoorMap,
          indoorRoute: _endIndoorRoute,
          buildingName: _endBldgName,
          isStart: false,
        ),
    };
  }

  Widget _buildIndoorPhase({
    required IndoorMap indoorMap,
    required IndoorRoute? indoorRoute,
    required String buildingName,
    required bool isStart,
  }) {
    if (indoorRoute != null && indoorRoute.segments.isNotEmpty) {
      return _buildIndoorRouteView(indoorMap, indoorRoute);
    }

    // Fallback: show the floor plan for the relevant room's floor without a path
    final roomId = isStart ? widget.startRoomId : widget.endRoomId;
    final roomFloor = IndoorMultifloorRoutePlanner.floorForRoom(indoorMap, roomId);
    final floor = roomFloor != null
        ? indoorMap.getFloorByLevel(roomFloor)
        : indoorMap.floors.firstOrNull;

    if (floor == null) {
      return Center(
        child: Text(
          isStart
              ? 'Head to the exit of $buildingName'
              : 'Find your room in $buildingName',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            isStart
                ? 'Head to the exit — Floor ${floor.label}'
                : 'Navigate to your room — Floor ${floor.label}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: _IndoorFloorView(floor: floor, pathNodeIds: const []),
        ),
      ],
    );
  }

  Widget _buildIndoorRouteView(IndoorMap indoorMap, IndoorRoute indoorRoute) {
    final seg = indoorRoute.segments[_activeRouteSegment.clamp(
        0, indoorRoute.segments.length - 1)];
    final floor = indoorMap.getFloorByLevel(seg.floorLevel);

    // coverage:ignore-start
    if (floor == null) {
      return const Center(child: Text('Floor data unavailable'));
    }
    // coverage:ignore-end

    return Column(
      children: [
        if (indoorRoute.segments.length > 1)
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: indoorRoute.segments.length,
              itemBuilder: (context, i) {
                final s = indoorRoute.segments[i];
                final isActive = i == _activeRouteSegment;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text('Floor ${s.floorLevel}',
                        style: const TextStyle(fontSize: 11)),
                    selected: isActive,
                    onSelected: (_) =>
                        setState(() => _activeRouteSegment = i),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _IndoorFloorView(
            floor: floor,
            pathNodeIds: seg.nodeIds,
          ),
        ),
        if (seg.transitionInstruction != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.swap_vert, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    seg.transitionInstruction!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (indoorRoute.directions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 80),
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shrinkWrap: true,
              itemCount: indoorRoute.directions.length,
              itemBuilder: (context, i) => Text(
                '${i + 1}. ${indoorRoute.directions[i]}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOutdoorPhase() {
    final hasPolyline = widget.outdoorPolyline != null &&
        widget.outdoorPolyline!.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                _isCrossCampus
                    ? Icons.directions_transit
                    : Icons.directions_walk,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.transportModeLabel} from $_startBldgName to $_endBldgName',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (widget.outdoorDuration != null)
                _infoPill(Icons.timer, widget.outdoorDuration!),
              if (widget.outdoorDistance != null) ...[
                const SizedBox(height: 6),
                _infoPill(Icons.straighten, widget.outdoorDistance!),
              ],
              if (_isCrossCampus) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This route crosses campuses. Consider the Concordia shuttle bus.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasPolyline)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _OutdoorMapPreview(
                  polylinePoints: widget.outdoorPolyline!,
                  startBuilding: widget.startBuilding,
                  endBuilding: widget.endBuilding,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final (String buttonLabel, IconData buttonIcon) = switch (_phase) {
      NavigationPhase.indoorStart => (
          _startIndoorRoute != null &&
                  _startIndoorRoute!.segments.length > 1 &&
                  !_indoorStartOnLastSegment
              ? 'Next step'
              : "I've exited — continue to ${widget.transportModeLabel.toLowerCase()}",
          _startIndoorRoute != null &&
                  _startIndoorRoute!.segments.length > 1 &&
                  !_indoorStartOnLastSegment
              ? Icons.navigate_next
              : Icons.exit_to_app,
        ),
      NavigationPhase.outdoor => (
          "I've arrived at $_endBldgName",
          Icons.location_on,
        ),
      NavigationPhase.indoorEnd => (
          _endIndoorRoute != null &&
                  _endIndoorRoute!.segments.length > 1 &&
                  !_indoorEndOnLastSegment
              ? 'Next step'
              : 'Done — arrived at destination',
          _endIndoorRoute != null &&
                  _endIndoorRoute!.segments.length > 1 &&
                  !_indoorEndOnLastSegment
              ? Icons.navigate_next
              : Icons.check_circle,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('phase_continue_button'),
            icon: Icon(buttonIcon),
            label: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: _onPhaseContinuePressed,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Indoor floor view
// ---------------------------------------------------------------------------

class _IndoorFloorView extends StatelessWidget {
  final Floor floor;
  final List<String> pathNodeIds;

  const _IndoorFloorView({
    required this.floor,
    required this.pathNodeIds,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: floor.imageAspectRatio,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Stack(
          children: [
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
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePathPainter(
                  navGraph: floor.navGraph,
                  pathNodeIds: pathNodeIds,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route path painter
// ---------------------------------------------------------------------------

class _RoutePathPainter extends CustomPainter { // coverage:ignore-line
  final NavGraph? navGraph;
  final List<String> pathNodeIds;

  const _RoutePathPainter({
    required this.navGraph,
    required this.pathNodeIds,
  });

  // coverage:ignore-start
  @override
  void paint(Canvas canvas, Size size) {
    final graph = navGraph;
    if (graph == null || pathNodeIds.length < 2) return;

    final sw = size.width;
    final sh = size.height;

    final glowPaint = Paint()
      ..color = const Color(0x80FF9500)
      ..strokeWidth = size.shortestSide * 0.016
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = const Color(0xFFFF9500)
      ..strokeWidth = size.shortestSide * 0.007
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pathObj = Path();
    bool first = true;
    for (final id in pathNodeIds) {
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

    canvas.drawPath(pathObj, glowPaint);
    canvas.drawPath(pathObj, linePaint);

    final startNode = graph.nodeById(pathNodeIds.first);
    final endNode = graph.nodeById(pathNodeIds.last);
    final r = size.shortestSide * 0.02;

    if (startNode != null) {
      _drawDot(canvas, startNode.x * sw, startNode.y * sh, r,
          const Color(0xFF27AE60), 'A');
    }
    if (endNode != null) {
      _drawDot(canvas, endNode.x * sw, endNode.y * sh, r,
          const Color(0xFF2980B9), 'B');
    }
  }

  void _drawDot(Canvas canvas, double cx, double cy, double r, Color color,
      String label) {
    canvas.drawCircle(
        Offset(cx + 1, cy + 2), r, Paint()..color = Colors.black38);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: r * 1.1,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
  // coverage:ignore-end

  @override
  bool shouldRepaint(covariant _RoutePathPainter old) =>
      old.pathNodeIds != pathNodeIds || old.navGraph != navGraph;
}

// ---------------------------------------------------------------------------
// Outdoor map preview
// ---------------------------------------------------------------------------

// coverage:ignore-start
class _OutdoorMapPreview extends StatelessWidget {
  final List<LatLng> polylinePoints;
  final CampusBuilding startBuilding;
  final CampusBuilding endBuilding;

  const _OutdoorMapPreview({
    required this.polylinePoints,
    required this.startBuilding,
    required this.endBuilding,
  });

  @override
  Widget build(BuildContext context) {
    if (polylinePoints.isEmpty) {
      return const Center(child: Text('No outdoor route available'));
    }

    final startCenter = polygonCenter(startBuilding.boundary);
    final endCenter = polygonCenter(endBuilding.boundary);

    final midLat = (startCenter.latitude + endCenter.latitude) / 2;
    final midLng = (startCenter.longitude + endCenter.longitude) / 2;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(midLat, midLng),
        zoom: 15,
      ),
      polylines: {
        Polyline(
          polylineId: const PolylineId('outdoor_route'),
          points: polylinePoints,
          width: 5,
          color: const Color(0xFF1A73E8),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('start_building'),
          position: startCenter,
          infoWindow: InfoWindow(title: startBuilding.name),
        ),
        Marker(
          markerId: const MarkerId('end_building'),
          position: endCenter,
          infoWindow: InfoWindow(title: endBuilding.name),
        ),
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      // Lite mode draws a static bitmap on Android (no pinch/pan); keep full map for navigation.
      liteModeEnabled: false,
    );
  }
}
// coverage:ignore-end
