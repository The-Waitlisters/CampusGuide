import 'package:flutter_test/flutter_test.dart';

void main() {
  group('POI Option Menu', () {
    /*testWidgets('Check the inner Section of POI Option Menu', (WidgetTester tester) async {
      Widget testPOIMenu = MaterialApp(
          home: Stack(
              children: [POIOptionMenu(
                currentPOICount: 1,
                position: LatLng(0, 0),
                allPOIs: [Poi(id: '0', name: '0', boundary: LatLng(0, 0), fullName: '0', description: '0', campus: Campus.sgw, poiType: "assets/coffee.png")],
                onDistanceSubmit: (str) {},
                onAmountSubmit: (str) {},
                calcDist: (l1, l2) { return 1; }, onTap: () {  },
                )
              ]
          )
      );

      await tester.pumpWidget(testPOIMenu);

      expect(find.text("Maximum distance (km)"), findsOneWidget);
      expect(find.text("Distance: 1.00 km"), findsOneWidget);
    });*/

    testWidgets("Check", (WidgetTester tester) async {

    });

  });
}