import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/widgets/home/poi_detail_content.dart';

Poi testPoi({
  String id = '',
  LatLng boundary = const LatLng(0, 0),
  Campus campus = Campus.sgw,
  List<String> openingHours = const ['9-5'],
  String poiType = 'assets/coffee.png'
}) {
  return Poi(id: id, name: "POI$id", boundary: boundary, fullName: "POI$id", description: "Test POI $id", campus: campus, openingHours: openingHours, poiType: poiType);
}

CampusBuilding testBuilding({
  String id = '',
  Campus campus = Campus.sgw,
  List<LatLng> boundary = const [LatLng(0, 0)],
}) {
  return CampusBuilding(id: id, name: "B$id", campus: campus, boundary: boundary, fullName: "B$id", description: "Test Building $id");
}

PoiDetailContent testPOIContent() {
  return PoiDetailContent(
      building: testPoi(id: '01'),
      startBuilding: testBuilding(id: '1'),
      endBuilding: testBuilding(id: '2'),
      onSetDestination: () {},
      onSetStart: () {},
      onViewIndoorMap: () {},
  );
}

Widget buildPOI() {
  return MaterialApp(
    home: Scaffold(
      body: testPOIContent(),
      ),
    );
}

void main() {
  group('POI detail contents', () {

    testWidgets('Check the Header of POI detail contents', (WidgetTester tester) async {
      Widget testPoiDC = buildPOI();
      await tester.pumpWidget(testPoiDC);

      expect(find.text("POI01 - POI01"), findsOneWidget);
    });

    testWidgets('Check the inner Section of POI detail contents', (WidgetTester tester) async {
      Widget testPoiDC = buildPOI();
      await tester.pumpWidget(testPoiDC);

      expect(find.text("Opening Hours:"), findsOneWidget);
    });

    testWidgets('Check if \'Set as Destination\' button is there for POI detail contents', (WidgetTester tester) async {
      Widget testPoiDC = buildPOI();
      await tester.pumpWidget(testPoiDC);

      expect(find.text("Set as Destination"), findsOneWidget);
    });

    testWidgets('Check if the indoor view button is there for POI detail contents', (WidgetTester tester) async {
      Widget testPoiDC = buildPOI();
      await tester.pumpWidget(testPoiDC);

      expect(find.text("View indoor map"), findsOneWidget);
    });

  });
}