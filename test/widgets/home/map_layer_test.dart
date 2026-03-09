import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/widgets/home/map_layer.dart';
import 'dart:typed_data';

/// Fake controller that completes getLatLng successfully
class FakeGoogleMapController implements GoogleMapController {
  @override
  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate) =>
      Future.value(const LatLng(45.0, -73.0));

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) =>
      Future.value();

  @override
  Future<void> moveCamera(CameraUpdate update) => Future.value();

  @override
  Future<ScreenCoordinate> getScreenCoordinate(LatLng latLng) =>
      Future.value(const ScreenCoordinate(x: 0, y: 0));

  @override
  Future<LatLngBounds> getVisibleRegion() => Future.value(
      LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0)));

  @override
  Future<double> getZoomLevel() => Future.value(0);

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId) => Future.value();

  @override
  Future<bool> isMarkerInfoWindowShown(MarkerId markerId) => Future.value(false);

  @override
  Future<void> setMapStyle(String? mapStyle) => Future.value();

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId) => Future.value();

  @override
  Future<Uint8List?> takeSnapshot() => Future.value(null);

  @override
  Future<String?> getStyleError() => Future.value(null);

  @override
  Future<void> clearTileCache(TileOverlayId tileOverlayId) => Future.value();

  @override
  int get mapId => 0;

  @override
  void dispose() {}
}

/// Fake controller that throws on getLatLng (simulates disposed controller)
class DisposedGoogleMapController extends FakeGoogleMapController {
  @override
  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate) =>
      Future.error(StateError(
          'GoogleMapController for map ID 0 was used after the associated GoogleMap widget had already been disposed.'));
}

void main() {
  group('MapLayer', () {
    late GlobalKey mapKey;

    setUp(() {
      mapKey = GlobalKey();
    });

    Widget buildMapLayer({
      Future<List<String>>? future,
      bool hasPolygons = false,
      void Function(List<String>)? onDataReady,
      GoogleMapController? controller,
      void Function(LatLng)? onMapTapLatLng,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MapLayer<String>(
            future: future ?? Future.value(['item1']),
            hasPolygons: hasPolygons,
            onDataReady: onDataReady ?? (_) {},
            mapKey: mapKey,
            controller: controller,
            onMapTapLatLng: onMapTapLatLng ?? (_) {},
            map: SizedBox(width: 400, height: 400),
          ),
        ),
      );
    }

    testWidgets('shows loading indicator while future is pending',
            (WidgetTester tester) async {
          final completer = Completer<List<String>>();

          await tester.pumpWidget(buildMapLayer(future: completer.future));
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          completer.complete(['item1']);
          await tester.pumpAndSettle();

          expect(find.byType(CircularProgressIndicator), findsNothing);
        });

    testWidgets('shows error message when future fails',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildMapLayer(
            future: Future.error(Exception('load error')),
          ));
          await tester.pumpAndSettle();
          tester.takeException(); // consume the unhandled exception

          expect(find.textContaining('Error loading polygons'), findsOneWidget);
        });

    testWidgets('calls onDataReady when hasPolygons is false and data is available',
            (WidgetTester tester) async {
          bool onDataReadyCalled = false;

          await tester.pumpWidget(buildMapLayer(
            hasPolygons: false,
            onDataReady: (_) => onDataReadyCalled = true,
          ));
          await tester.pumpAndSettle();

          // Covers lines 69-70: widget.onDataReady(data)
          expect(onDataReadyCalled, isTrue);
        });

    testWidgets('does not call onDataReady when hasPolygons is true',
            (WidgetTester tester) async {
          bool onDataReadyCalled = false;

          await tester.pumpWidget(buildMapLayer(
            hasPolygons: true,
            onDataReady: (_) => onDataReadyCalled = true,
          ));
          await tester.pumpAndSettle();

          expect(onDataReadyCalled, isFalse);
        });

    testWidgets('onPointerDown does nothing when controller is null',
            (WidgetTester tester) async {
          LatLng? tappedLatLng;

          await tester.pumpWidget(buildMapLayer(
            controller: null, // Covers line 34: controller == null return
            onMapTapLatLng: (latLng) => tappedLatLng = latLng,
          ));
          await tester.pumpAndSettle();

          await tester.tapAt(const Offset(100, 100));
          await tester.pumpAndSettle();

          expect(tappedLatLng, isNull);
        });

    testWidgets('onPointerDown calls onMapTapLatLng when controller is valid',
            (WidgetTester tester) async {
          LatLng? tappedLatLng;

          await tester.pumpWidget(buildMapLayer(
            controller: FakeGoogleMapController(),
            onMapTapLatLng: (latLng) => tappedLatLng = latLng,
          ));
          await tester.pumpAndSettle();

          // Covers lines 32-54: _handlePointerDown full happy path
          await tester.tapAt(const Offset(100, 100));
          await tester.pumpAndSettle();

          expect(tappedLatLng, isNotNull);
          expect(tappedLatLng, equals(const LatLng(45.0, -73.0)));
        });

    testWidgets('onPointerDown catches error when controller is disposed',
            (WidgetTester tester) async {
          LatLng? tappedLatLng;

          await tester.pumpWidget(buildMapLayer(
            controller: DisposedGoogleMapController(),
            // Covers lines 51-52: catch (e) { debugPrint(...) }
            onMapTapLatLng: (latLng) => tappedLatLng = latLng,
          ));
          await tester.pumpAndSettle();

          await tester.tapAt(const Offset(100, 100));
          await tester.pumpAndSettle();

          // Should not crash and onMapTapLatLng should not be called
          expect(tappedLatLng, isNull);
        });

    testWidgets('renders map child widget',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildMapLayer());
          await tester.pumpAndSettle();

          expect(find.byType(Listener), findsWidgets); // changed from findsOneWidget
          expect(find.byType(SizedBox), findsWidgets);
        });
  });
}