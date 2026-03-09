import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/data/indoor_map_data.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';

CampusBuilding _building(String name) => CampusBuilding(
      id: 'test',
      name: name,
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: null,
      description: null,
    );

const _validFloorJson = '''
{
  "imageWidth": 200,
  "imageHeight": 200,
  "nodes": [
    {"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801", "floor": 8},
    {"id": "wp1", "type": "hallway_waypoint", "x": 100, "y": 75, "label": ""}
  ],
  "edges": []
}
''';

void _mockAsset(String key, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? msg) async {
    if (msg == null) return null;
    final requestedKey = utf8.decode(msg.buffer.asUint8List());
    if (requestedKey == key) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      return ByteData.sublistView(bytes);
    }
    return null;
  });
}

void _mockAssetNotFound() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (_) async => null);
}

/// Advances the fake clock past the 150 ms delay in [loadIndoorMapForBuilding]
/// and processes any resulting microtasks.
Future<IndoorMap?> _load(
  WidgetTester tester,
  CampusBuilding building,
) async {
  final future = loadIndoorMapForBuilding(building);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(); // drain microtasks from setState / asset decode
  return future;
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  group('US-5.1: loadIndoorMapForBuilding', () {
    testWidgets('returns null for building with unknown name', (tester) async {
      expect(await _load(tester, _building('UNKNOWN')), isNull);
    });

    testWidgets('returns null for empty building name', (tester) async {
      expect(await _load(tester, _building('')), isNull);
    });

    testWidgets('returns null when asset is not found for a known building',
        (tester) async {
      _mockAssetNotFound();
      expect(await _load(tester, _building('H')), isNull);
    });

    testWidgets('returns IndoorMap with floors for valid H.json asset',
        (tester) async {
      _mockAsset('assets/indoor/H.json', _validFloorJson);
      final result = await _load(tester, _building('H'));
      expect(result, isNotNull);
      expect(result!.building.name, 'H');
      expect(result.floors, isNotEmpty);
    });

    testWidgets('returns IndoorMap for VL/VE building (mapped to VE key)',
        (tester) async {
      _mockAsset('assets/indoor/VE.json', _validFloorJson);
      expect(await _load(tester, _building('VL/VE')), isNotNull);
    });

    testWidgets('returns IndoorMap for MB building', (tester) async {
      _mockAsset('assets/indoor/MB.json', _validFloorJson);
      expect(await _load(tester, _building('MB')), isNotNull);
    });

    testWidgets('returns IndoorMap for CC building', (tester) async {
      _mockAsset('assets/indoor/CC.json', _validFloorJson);
      expect(await _load(tester, _building('CC')), isNotNull);
    });

    testWidgets('returns IndoorMap for LB building', (tester) async {
      _mockAsset('assets/indoor/LB.json', _validFloorJson);
      expect(await _load(tester, _building('LB')), isNotNull);
    });

    testWidgets('parsed IndoorMap contains the expected room', (tester) async {
      _mockAsset('assets/indoor/H.json', _validFloorJson);
      final result = await _load(tester, _building('H'));
      expect(result!.floors.first.rooms.first.id, 'r1');
    });

    testWidgets('returns null when JSON is invalid', (tester) async {
      _mockAsset('assets/indoor/H.json', 'NOT VALID JSON {{{{');
      expect(await _load(tester, _building('H')), isNull);
    });

    testWidgets('returns null when JSON has an empty floors list',
        (tester) async {
      _mockAsset('assets/indoor/H.json', '{"floors":[]}');
      expect(await _load(tester, _building('H')), isNull);
    });
  });
}
