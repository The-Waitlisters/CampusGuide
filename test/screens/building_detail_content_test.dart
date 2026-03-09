import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/widgets/home/building_detail_content.dart'; // correct import

CampusBuilding _building({
  required String fullName,
  required bool accessible,
  required bool bike,
  required bool car,
  required List<String> openingHours,
  required List<String> departments,
  required List<String> services,
}) {
  return CampusBuilding(
    id: 'b1',
    name: 'Hall',
    campus: Campus.sgw,
    boundary: const [
      LatLng(0, 0),
      LatLng(0, 1),
      LatLng(1, 1),
      LatLng(1, 0),
    ],
    fullName: fullName,
    description: 'Desc',
    openingHours: openingHours,
    departments: departments,
    services: services,
    isWheelchairAccessible: accessible,
    hasBikeParking: bike,
    hasCarParking: car,
  );
}

// Helper to pump BuildingDetailContent with all required params
Widget _wrap(CampusBuilding b, {bool isAnnex = false, CampusBuilding? start}) {
  return MaterialApp(
    home: Material(
      child: BuildingDetailContent(
        building: b,
        isAnnex: isAnnex,
        startBuilding: start,      // null = no start set yet
        endBuilding: null,
        onSetStart: () {},
        onSetDestination: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('shows Annex in title when isAnnex=true', (tester) async {
    final b = _building(
      fullName: 'Hall Annex',
      accessible: false,
      bike: false,
      car: false,
      openingHours: const [],
      departments: const [],
      services: const [],
    );

    await tester.pumpWidget(_wrap(b, isAnnex: true));

    expect(find.textContaining('Hall Annex'), findsOneWidget);
  });

  testWidgets('shows fullName in title when isAnnex=false', (tester) async {
    final b = _building(
      fullName: 'Hall Building',
      accessible: false,
      bike: false,
      car: false,
      openingHours: const [],
      departments: const [],
      services: const [],
    );

    await tester.pumpWidget(_wrap(b, isAnnex: false));

    expect(find.textContaining('Hall - Hall Building'), findsOneWidget);
  });

  testWidgets('renders icons when corresponding flags are true', (tester) async {
    final b = _building(
      fullName: 'Hall Building',
      accessible: true,
      bike: false,
      car: true,
      openingHours: const [],
      departments: const [],
      services: const [],
    );

    await tester.pumpWidget(_wrap(b));

    expect(find.byIcon(Icons.accessible), findsOneWidget);
    expect(find.byIcon(Icons.local_parking), findsOneWidget);
    expect(find.byIcon(Icons.pedal_bike), findsNothing);
  });

  testWidgets('shows "Set as Start" button when no start building is set',
          (tester) async {
        final b = _building(
          fullName: 'Hall Building',
          accessible: false,
          bike: false,
          car: false,
          openingHours: const [],
          departments: const [],
          services: const [],
        );

        await tester.pumpWidget(_wrap(b, start: null));

        expect(find.text('Set as Start'), findsOneWidget);
        expect(find.text('Set as Destination'), findsOneWidget);
        // Start is enabled, Destination is enabled (no start set yet means
        // destination-first flow is allowed)
        expect(
          tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Set as Start'),
          ).onPressed,
          isNotNull,
        );
      });
  testWidgets('shows "Set as Destination" button when a start building is already set',
          (tester) async {
        final start = _building(
          fullName: 'Other Building',
          accessible: false,
          bike: false,
          car: false,
          openingHours: const [],
          departments: const [],
          services: const [],
        );
        final dest = CampusBuilding(
          id: 'b2',
          name: 'MB',
          campus: Campus.sgw,
          boundary: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
          fullName: 'MB Building',
          description: null,
        );

        await tester.pumpWidget(_wrap(dest, start: start));

        expect(find.text('Set as Start'), findsOneWidget);
        expect(find.text('Set as Destination'), findsOneWidget);
        // Destination is enabled since dest.id != start.id
        expect(
          tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Set as Destination'),
          ).onPressed,
          isNotNull,
        );
      });

  testWidgets('maps "-" to "None" in openingHours/departments/services',
          (tester) async {
        final b = _building(
          fullName: 'Hall Building',
          accessible: false,
          bike: false,
          car: false,
          openingHours: const ['-'],
          departments: const ['-', 'Math'],
          services: const ['-', '-'],
        );

        await tester.pumpWidget(_wrap(b));

        expect(find.text('Math'), findsOneWidget);
        // 1 from openingHours + 1 from departments + 2 from services = 4
        expect(find.text('None'), findsNWidgets(4));
      });
}