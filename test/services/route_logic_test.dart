import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/services/route_logic.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';

void main() {
  final sgwBuilding = CampusBuilding(
    id: 'sgw1', name: 'H', fullName: 'Hall', campus: Campus.sgw,
    description: '',
    boundary: [LatLng(0,0), LatLng(0,1), LatLng(1,1), LatLng(1,0)],
  );
  final loyolaBuilding = CampusBuilding(
    id: 'loy1', name: 'SP', fullName: 'Stinger', campus: Campus.loyola,
    description: '',
    boundary: [LatLng(5,5), LatLng(5,6), LatLng(6,6), LatLng(6,5)],
  );
  final buildings = [sgwBuilding, loyolaBuilding];

  group('RouteLogic.campusAtPoint', () {
    test('returns sgw for point inside SGW building', () {
      expect(RouteLogic.campusAtPoint(const LatLng(0.5, 0.5), buildings), Campus.sgw);
    });

    test('returns loyola for point inside Loyola building', () {
      expect(RouteLogic.campusAtPoint(const LatLng(5.5, 5.5), buildings), Campus.loyola);
    });

    test('returns null for point outside all buildings', () {
      expect(RouteLogic.campusAtPoint(const LatLng(99, 99), buildings), isNull);
    });
  });

  group('RouteLogic.defaultMode', () {
    test('returns null when endCampus is null', () {
      expect(
        RouteLogic.defaultMode(
          endCampus: null, isCurrentLocationStart: false,
        ),
        isNull,
      );
    });

    test('same campus → Walk', () {
      final mode = RouteLogic.defaultMode(
        startCampus: Campus.sgw, endCampus: Campus.sgw,
        isCurrentLocationStart: false,
      );
      expect(mode, isA<WalkStrategy>());
    });

    test('different campuses → Shuttle', () {
      final mode = RouteLogic.defaultMode(
        startCampus: Campus.sgw, endCampus: Campus.loyola,
        isCurrentLocationStart: false,
      );
      expect(mode, isA<ShuttleStrategy>());
    });

    test('null startCampus returns null', () {
      expect(
        RouteLogic.defaultMode(
          startCampus: null, endCampus: Campus.sgw,
          isCurrentLocationStart: false,
        ),
        isNull,
      );
    });

    test('current location start, close distance → Walk', () {
      final mode = RouteLogic.defaultMode(
        endCampus: Campus.sgw,
        startPoint: const LatLng(45.4970, -73.5780),
        endPoint: const LatLng(45.4975, -73.5785), // ~60m apart
        isCurrentLocationStart: true,
      );
      expect(mode, isA<WalkStrategy>());
    });

    test('current location start, far distance → Shuttle', () {
      final mode = RouteLogic.defaultMode(
        endCampus: Campus.loyola,
        startPoint: const LatLng(45.4970, -73.5780), // SGW area
        endPoint: const LatLng(45.4582, -73.6405),   // Loyola (~5km)
        isCurrentLocationStart: true,
      );
      expect(mode, isA<ShuttleStrategy>());
    });

    test('current location start but missing points → falls through to startCampus logic', () {
      // startPoint is null, so distance branch is skipped
      final mode = RouteLogic.defaultMode(
        endCampus: Campus.sgw,
        startCampus: Campus.sgw,
        startPoint: null,
        endPoint: null,
        isCurrentLocationStart: true,
      );
      expect(mode, isA<WalkStrategy>());
    });
  });
}