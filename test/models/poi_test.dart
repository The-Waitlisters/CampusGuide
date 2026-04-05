import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/poi.dart';

Poi _poi({String id = 'p1'}) => Poi(
      id: id,
      name: 'Test POI',
      campus: Campus.sgw,
      description: 'A test poi',
      boundary: const LatLng(45.497, -73.578),
    );

void main() {
  group('Poi equality and hashCode', () {
    test('two Poi instances with the same id are equal', () {
      final a = _poi(id: 'abc');
      final b = _poi(id: 'abc');
      expect(a == b, isTrue);
    });

    test('two Poi instances with different ids are not equal', () {
      final a = _poi(id: 'x');
      final b = _poi(id: 'y');
      expect(a == b, isFalse);
    });

    test('a Poi is equal to itself', () {
      final a = _poi();
      expect(a == a, isTrue);
    });

    test('a Poi is not equal to a non-Poi object', () {
      final a = _poi(id: 'p1');
      // ignore: unrelated_type_equality_checks
      expect(a == 'p1', isFalse);
    });

    test('hashCode matches for equal Poi instances', () {
      final a = _poi(id: 'abc');
      final b = _poi(id: 'abc');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('can be used as a Map key (exercises hashCode)', () {
      final poi = _poi(id: 'key1');
      final map = {poi: 'value'};
      expect(map[poi], 'value');
    });
  });
}
