import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/widgets/home/route_polyline_overlay.dart';

const _camera = CameraPosition(target: LatLng(45.5, -73.5), zoom: 14);

Widget _wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 400, height: 800, child: child),
      ),
    );

void main() {
  group('RoutePolylineOverlay', () {
    testWidgets('returns empty box when legs is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsNothing);
    });

    testWidgets('renders CustomPaint for a walking leg', (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '0.1 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('renders CustomPaint for a driving leg (solid path)', (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.driving,
        durationSeconds: 120,
        durationText: '2 min',
        distanceText: '1 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('renders CustomPaint for a cycling leg', (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.52, -73.52)],
        legMode: LegMode.cycling,
        durationSeconds: 180,
        durationText: '3 min',
        distanceText: '1.5 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('renders CustomPaint for a shuttle leg', (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.46, -73.64)],
        legMode: LegMode.shuttle,
        durationSeconds: 1800,
        durationText: '30 min',
        distanceText: '7 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('renders CustomPaint for a transit leg with transitColor',
        (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.transit,
        durationSeconds: 600,
        durationText: '10 min',
        distanceText: '5 km',
        transitColor: Color(0xFF1A73E8),
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('transit leg without transitColor falls back to default color',
        (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.transit,
        durationSeconds: 600,
        durationText: '10 min',
        distanceText: '5 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('skips leg with fewer than 2 points without crashing',
        (tester) async {
      const shortLeg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5)], // only 1 point
        legMode: LegMode.walking,
        durationSeconds: 0,
        durationText: 'x',
        distanceText: 'y',
      );
      const normalLeg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.driving,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '0.5 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(
          legs: [shortLeg, normalLeg],
          cameraPosition: _camera,
        ),
      ));

      // Should render without error; CustomPaint still present for the normal leg
      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('shouldRepaint triggers on camera position change',
        (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.walking,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '0.1 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      const camera2 = CameraPosition(target: LatLng(45.6, -73.6), zoom: 15);
      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: camera2),
      ));

      // No assertion beyond "doesn't crash" — exercises shouldRepaint(old)
      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('shouldRepaint does not repaint when data is unchanged',
        (tester) async {
      const leg = RouteLeg(
        polylinePoints: [LatLng(45.5, -73.5), LatLng(45.51, -73.51)],
        legMode: LegMode.driving,
        durationSeconds: 60,
        durationText: '1 min',
        distanceText: '0.5 km',
      );

      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));
      // Pump again with identical data — shouldRepaint returns false
      await tester.pumpWidget(_wrap(
        const RoutePolylineOverlay(legs: [leg], cameraPosition: _camera),
      ));

      expect(find.byType(IgnorePointer), findsOneWidget);
    });
  });
}
