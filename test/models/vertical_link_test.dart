import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/vertical_link.dart';

void main(){
  group('VerticalLink.fromJson', () {
    Map<String, dynamic> _json({
      required int fromFloor, required String fromNodeId,
      required int toFloor,   required String toNodeId,
      String kind = 'stairs',
      bool? oneWay,
    }) => {
      'from': {'floor': fromFloor, 'nodeId': fromNodeId},
      'to':   {'floor': toFloor,   'nodeId': toNodeId},
      'kind': kind,
      if (oneWay != null) 'oneWay': oneWay,
    };

    test('parses elevator kind', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 'e1',
        toFloor: 2,   toNodeId: 'e2',
        kind: 'elevator',
      ));
      expect(link.kind, VerticalLinkKind.elevator);
    });

    test('parses escalator kind', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 'e1',
        toFloor: 2,   toNodeId: 'e2',
        kind: 'escalator',
      ));
      expect(link.kind, VerticalLinkKind.escalator);
    });

    test('parses stairs kind', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 's1',
        toFloor: 2,   toNodeId: 's2',
        kind: 'stairs',
      ));
      expect(link.kind, VerticalLinkKind.stairs);
    });

    test('unknown kind string falls back to stairs', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 'n1',
        toFloor: 2,   toNodeId: 'n2',
        kind: 'ramp',
      ));
      expect(link.kind, VerticalLinkKind.stairs);
    });

    test('missing kind field falls back to stairs', () {
      final json = {
        'from': {'floor': 1, 'nodeId': 'n1'},
        'to':   {'floor': 2, 'nodeId': 'n2'},
      };
      final link = VerticalLink.fromJson(json);
      expect(link.kind, VerticalLinkKind.stairs);
    });

    test('parses floor and nodeId fields correctly', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 3, fromNodeId: 'elev_3',
        toFloor: 5,   toNodeId: 'elev_5',
        kind: 'elevator',
      ));
      expect(link.fromFloor, 3);
      expect(link.fromNodeId, 'elev_3');
      expect(link.toFloor, 5);
      expect(link.toNodeId, 'elev_5');
    });

    test('oneWay defaults to false when absent', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 'n1',
        toFloor: 2,   toNodeId: 'n2',
      ));
      expect(link.oneWay, false);
    });

    test('parses oneWay: true', () {
      final link = VerticalLink.fromJson(_json(
        fromFloor: 1, fromNodeId: 'n1',
        toFloor: 2,   toNodeId: 'n2',
        oneWay: true,
      ));
      expect(link.oneWay, true);
    });
  });
}