import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/data/indoor_map_data.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/vertical_link.dart';

CampusBuilding _building(String name) => CampusBuilding(
      id: 'test',
      name: name,
      campus: Campus.sgw,
      boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)],
      fullName: null,
      description: null,
    );

const _validJson = '''
{
  "imageWidth": 200, "imageHeight": 200,
  "nodes": [{"id": "r1", "type": "room", "x": 50, "y": 50, "label": "H-801", "floor": 8}],
  "edges": [],
  "verticalLinks": [
    "not_a_map",
    {
      "from": {"floor": 8, "nodeId": "r1"},
      "to":   {"floor": 9, "nodeId": "r2"},
      "kind": "elevator",
      "oneWay": false
    }
  ]
}
''';

const notJson = 'ayyy lmao {..[][';

void _mockAsset(String key, String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? msg) async {
    if (msg == null) return null;
    if (utf8.decode(msg.buffer.asUint8List()) == key) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
    }
    return null;
  });
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('returns null for unknown building', (tester) async {
    _mockAsset('assets/indoor/H.json', notJson);
    final future = loadIndoorMapForBuilding(_building('H'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(await future, isNull);
  });

  testWidgets('returns IndoorMap when asset is mocked', (tester) async {
    _mockAsset('assets/indoor/H.json', _validJson);
    final future = loadIndoorMapForBuilding(_building('H'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    final result = await future;
    expect(result, isNotNull);
    expect(result!.building.name, 'H');
    expect(result.floors, isNotEmpty);
    expect(result.verticalLinks.length, 1);
    expect(result.verticalLinks.first.kind, VerticalLinkKind.elevator);
  });
}
