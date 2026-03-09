import 'package:flutter_test/flutter_test.dart';
import 'package:proj/data/floor_plan_editor_loader.dart';

Map<String, dynamic> _singleFloorJson({
  double imgW = 2000,
  double imgH = 2000,
  String? label,
  List<Map<String, dynamic>> nodes = const [],
  List<Map<String, dynamic>> edges = const [],
}) =>
    {
      'imageWidth': imgW,
      'imageHeight': imgH,
      ?'label': label,
      'nodes': nodes,
      'edges': edges,
    };

Map<String, dynamic> _roomNode(String id, double x, double y,
        {String label = ''}) =>
    {'id': id, 'type': 'room', 'x': x, 'y': y, 'label': label};

Map<String, dynamic> _waypointNode(String id, double x, double y) =>
    {'id': id, 'type': 'hallway_waypoint', 'x': x, 'y': y, 'label': ''};

Map<String, dynamic> _edge(String src, String tgt, {double weight = 100}) =>
    {'source': src, 'target': tgt, 'weight': weight};

// ---------------------------------------------------------------------------

void main() {
  group('US-5.1: FloorPlanEditorLoader — parseFloor', () {
    test('parses floor level from level parameter', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(),
        level: 8,
      );
      expect(floor.level, 8);
    });

    test('uses default level 1 when none provided', () {
      final floor = FloorPlanEditorLoader.parseFloor(_singleFloorJson());
      expect(floor.level, 1);
    });

    test('uses custom label from JSON when present', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(label: 'VE 2'),
        level: 2,
      );
      expect(floor.label, 'VE 2');
    });

    test('generates label from prefix and level when JSON label is absent', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(),
        level: 3,
        floorLabelPrefix: 'Floor ',
      );
      expect(floor.label, 'Floor 3');
    });

    test('normalizes node x coordinate by imageWidth', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(
          imgW: 1000,
          imgH: 1000,
          nodes: [_roomNode('r1', 500, 250)],
        ),
      );
      final node = floor.navGraph!.nodeById('r1');
      expect(node?.x, closeTo(0.5, 0.001));
    });

    test('normalizes node y coordinate by imageHeight', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(
          imgW: 1000,
          imgH: 1000,
          nodes: [_roomNode('r1', 500, 250)],
        ),
      );
      final node = floor.navGraph!.nodeById('r1');
      expect(node?.y, closeTo(0.25, 0.001));
    });

    test('uses node id as name when label is empty', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(nodes: [_roomNode('801', 100, 100, label: '')]),
      );
      final node = floor.navGraph!.nodeById('801');
      expect(node?.name, '801');
    });

    test('uses explicit label when non-empty', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(
            nodes: [_roomNode('r1', 100, 100, label: 'Room 101')]),
      );
      final node = floor.navGraph!.nodeById('r1');
      expect(node?.name, 'Room 101');
    });

    test('only room-type nodes appear in floor.rooms', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(nodes: [
          _roomNode('r1', 200, 200),
          _waypointNode('w1', 500, 500),
        ]),
      );
      expect(floor.rooms.any((r) => r.id == 'r1'), true);
      expect(floor.rooms.any((r) => r.id == 'w1'), false);
    });

    test('waypoint nodes appear in navGraph but not in rooms list', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(nodes: [_waypointNode('w1', 500, 500)]),
      );
      expect(floor.navGraph!.nodeById('w1'), isNotNull);
      expect(floor.rooms.any((r) => r.id == 'w1'), false);
    });

    test('imageAspectRatio equals imageWidth / imageHeight', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(imgW: 2000, imgH: 1000),
      );
      expect(floor.imageAspectRatio, closeTo(2.0, 0.001));
    });

    test('imageAspectRatio defaults to 1.0 when imageWidth equals imageHeight',
        () {
      final floor = FloorPlanEditorLoader.parseFloor(_singleFloorJson());
      expect(floor.imageAspectRatio, closeTo(1.0, 0.001));
    });

    test('defaults imageWidth and imageHeight to 1024 when absent', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        {'nodes': [], 'edges': []},
      );
      expect(floor.imageAspectRatio, closeTo(1.0, 0.001));
    });

    test('imagePath is set when provided', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(),
        imagePath: 'assets/indoor/H_8.png',
      );
      expect(floor.imagePath, 'assets/indoor/H_8.png');
    });

    test('imagePath is null when not provided', () {
      final floor = FloorPlanEditorLoader.parseFloor(_singleFloorJson());
      expect(floor.imagePath, isNull);
    });

    test('edges are parsed and path can be found between connected rooms', () {
      final floor = FloorPlanEditorLoader.parseFloor(
        _singleFloorJson(
          nodes: [
            _roomNode('r1', 200, 1000),
            _waypointNode('w1', 500, 1000),
            _waypointNode('w2', 1500, 1000),
            _roomNode('r2', 1800, 1000),
          ],
          edges: [
            _edge('w1', 'w2'),
          ],
        ),
      );
      final path = floor.navGraph!.findPath('r1', 'r2');
      expect(path, isNotNull);
      expect(path!.first, 'r1');
      expect(path.last, 'r2');
    });
  });

  // ---------------------------------------------------------------------------

  group('US-5.1: FloorPlanEditorLoader — parseMultiFloor', () {
    test('parses multiple floors from floors array', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor({
        'floors': [
          {
            'level': 8,
            'label': 'H 8',
            'imageWidth': 2000,
            'imageHeight': 2000,
            'nodes': [],
            'edges': [],
          },
          {
            'level': 9,
            'label': 'H 9',
            'imageWidth': 2000,
            'imageHeight': 2000,
            'nodes': [],
            'edges': [],
          },
        ],
      });
      expect(floors.length, 2);
      expect(floors[0].level, 8);
      expect(floors[1].level, 9);
    });

    test('floor labels from JSON are preserved', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor({
        'floors': [
          {
            'level': 1,
            'label': 'VE 1',
            'imageWidth': 2000,
            'imageHeight': 2000,
            'nodes': [],
            'edges': [],
          },
          {
            'level': 2,
            'label': 'VE 2',
            'imageWidth': 2000,
            'imageHeight': 2000,
            'nodes': [],
            'edges': [],
          },
        ],
      });
      expect(floors[0].label, 'VE 1');
      expect(floors[1].label, 'VE 2');
    });

    test('falls back to single floor when no floors array present', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor(
        _singleFloorJson(nodes: [_roomNode('r1', 100, 100)]),
      );
      expect(floors.length, 1);
      expect(floors.first.rooms.any((r) => r.id == 'r1'), true);
    });

    test('falls back to single floor when floors array is empty', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor({'floors': []});
      expect(floors.length, 1);
    });

    test('image path is constructed from prefix and level', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor(
        {
          'floors': [
            {
              'level': 8,
              'imageWidth': 2000,
              'imageHeight': 2000,
              'nodes': [],
              'edges': [],
            },
          ],
        },
        imageAssetPrefix: 'assets/indoor/H',
      );
      expect(floors.first.imagePath, 'assets/indoor/H_8.png');
    });

    test('imagePath is null when no prefix is supplied', () {
      final floors = FloorPlanEditorLoader.parseMultiFloor({
        'floors': [
          {
            'level': 1,
            'imageWidth': 2000,
            'imageHeight': 2000,
            'nodes': [],
            'edges': [],
          },
        ],
      });
      expect(floors.first.imagePath, isNull);
    });
  });
}
