import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/widgets/home/building_detail_content.dart';

import 'home_screen_test.dart';

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

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: BuildingDetailContent(building: b, isAnnex: true,
            startBuilding: null,
            endBuilding: null,
            onSetStart: () {},
            onSetDestination: () {},),
        ),
      ),
    );

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

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: BuildingDetailContent(building: b, isAnnex: false,
            startBuilding: null,
            endBuilding: null,
            onSetStart: () {},
            onSetDestination: () {},),
        ),
      ),
    );

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

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: BuildingDetailContent(building: b, isAnnex: false,
            startBuilding: null,
            endBuilding: null,
            onSetStart: () {},
            onSetDestination: () {},),
        ),
      ),
    );

    expect(find.byIcon(Icons.accessible), findsOneWidget);
    expect(find.byIcon(Icons.local_parking), findsOneWidget);
    expect(find.byIcon(Icons.pedal_bike), findsNothing);
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

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: BuildingDetailContent(
                building: b,
                isAnnex: false,
                startBuilding: null,
                endBuilding: null,
                onSetStart: () {},
                onSetDestination: () {},
              ),
            ),
          ),
        );

        expect(find.text('Math'), findsOneWidget);
        // 1 from openingHours + 1 from departments + 2 from services = 4
        expect(find.text('None'), findsNWidgets(4));
      });

  testWidgets('destination button is disabled when startBuilding is same as building',
      (tester) async {
    final b = _building(
      fullName: 'Hall Building',
      accessible: false,
      bike: false,
      car: false,
      openingHours: const ['-'],
      departments: const ['-'],
      services: const ['-'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuildingDetailContent(
            building: b,
            isAnnex: false,
            startBuilding: b, // same id
            endBuilding: null,
            onSetStart: () {},
            onSetDestination: () {},
          ),
        ),
      ),
    );

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Set as Destination'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('destination button enabled when startBuilding differs and calls onSetDestination',
          (WidgetTester tester) async {
        var called = false;
        final startB = buildTestBuilding(id: 's', name: 'S', fullName: 'Start');
        final b = buildTestBuilding(id: 'b', name: 'B', fullName: 'Building');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuildingDetailContent(
                building: b,
                isAnnex: false,
                startBuilding: startB, // different id -> enabled
                endBuilding: null,
                onSetStart: () {},
                onSetDestination: () {
                  called = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Set as Destination'));
        await tester.pump();
        expect(called, isTrue);
      });
}