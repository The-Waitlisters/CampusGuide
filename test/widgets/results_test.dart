import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/widgets/home/results.dart';

Poi _poi({
  String id = 'p1',
  String name = 'Test POI',
  String? description = 'A test poi',
  double rating = 4.0,
  bool? openNow = true,
  List<String> openingHours = const [],
  List<String?> photoName = const [],
  LatLng? boundary,
}) =>
    Poi(
      id: id,
      name: name,
      campus: Campus.sgw,
      description: description,
      boundary: boundary ?? const LatLng(45.497, -73.578),
      openNow: openNow,
      openingHours: openingHours,
      photoName: photoName,
      rating: rating,
      address: '1 Test St',
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 600, child: child),
      ),
    );

void main() {
  group('Results widget', () {
    testWidgets('shows title "Results" and close button', (tester) async {
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [],
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (_) {},
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsOneWidget);
      expect(find.byTooltip('Cancel'), findsOneWidget);
    });

    testWidgets('shows "No matching results" when list is empty', (tester) async {
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [],
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (_) {},
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsOneWidget);
    });

    testWidgets('onClose called when cancel icon tapped', (tester) async {
      var closed = false;
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [],
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (_) {},
        onClose: () => closed = true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('renders list items with name when POIs are present',
        (tester) async {
      final pois = [
        _poi(id: 'p1', name: 'Cafe A', description: 'Good coffee'),
        _poi(id: 'p2', name: 'Park B', description: ''),
      ];
      await tester.pumpWidget(_wrap(Results(
        poiPresent: pois,
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (_) {},
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Cafe A'), findsOneWidget);
      expect(find.text('Park B'), findsOneWidget);
    });

    testWidgets('onSelect called with correct POI when list item tapped',
        (tester) async {
      Poi? selected;
      final poi = _poi(id: 'p1', name: 'Cafe A', description: 'Good coffee');
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [poi],
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (p) => selected = p,
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cafe A'));
      await tester.pump();
      expect(selected, equals(poi));
    });

    testWidgets('shows distance in subtitle when description is non-empty',
        (tester) async {
      final poi = _poi(
        name: 'Near Cafe',
        description: 'Close by',
        boundary: const LatLng(45.497, -73.578),
      );
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [poi],
        locationPoint: const LatLng(45.497, -73.578),
        onSelect: (_) {},
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      // subtitle contains description and distance
      expect(find.textContaining('Close by'), findsOneWidget);
      expect(find.textContaining(' m'), findsOneWidget);
    });

    testWidgets('shows km in subtitle when distance >= 1km', (tester) async {
      final poi = _poi(
        name: 'Far Cafe',
        description: 'Far away',
        boundary: const LatLng(46.0, -74.0),
      );
      await tester.pumpWidget(_wrap(Results(
        poiPresent: [poi],
        locationPoint: const LatLng(45.0, -73.0),
        onSelect: (_) {},
        onClose: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining(' km'), findsOneWidget);
    });
  });
}
