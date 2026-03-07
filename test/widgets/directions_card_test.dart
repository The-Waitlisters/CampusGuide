import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/widgets/home/directions_card.dart';

void main(){
  testWidgets('tapping transport mode calls onModeChanged', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: CampusBuilding(
                name: 'H',
                fullName: 'Hall',
                campus: Campus.sgw,
                id: '', boundary: [], description: '',
              ),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (m) => selected = m,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.pump();

    expect(selected, 'bicycling');
  });
  testWidgets('shows location required message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: CampusBuilding(
                name: 'H',
                fullName: 'Hall',
                campus: Campus.sgw, id: '', boundary: [], description: '',
              ),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              locationRequiredMessage: 'Location permission needed',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Location permission needed'), findsOneWidget);
  });
  testWidgets('shows placeholder message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: CampusBuilding(
                name: 'H',
                fullName: 'Hall',
                campus: Campus.sgw, id: '', boundary: [], description: '',
              ),
              isLoading: false,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              placeholderMessage: 'Shuttle coming soon',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Shuttle coming soon'), findsOneWidget);
  });
  testWidgets('shows loading indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: CampusBuilding(
                name: 'H',
                fullName: 'Hall',
                campus: Campus.sgw, id: '', boundary: [], description: '',
              ),
              isLoading: true,
              errorMessage: null,
              polyline: null,
              durationText: null,
              distanceText: null,
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('shows duration and distance when route exists', (tester) async {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: const [LatLng(0,0), LatLng(1,1)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            DirectionsCard(
              startBuilding: null,
              endBuilding: CampusBuilding(
                name: 'H',
                fullName: 'Hall',
                campus: Campus.sgw, id: '', boundary: [], description: '',
              ),
              isLoading: false,
              errorMessage: null,
              polyline: polyline,
              durationText: '5 min',
              distanceText: '1 km',
              onCancel: () {},
              onRetry: () {},
              selectedModeParam: 'walking',
              onModeChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('5 min • 1 km'), findsOneWidget);
  });

}