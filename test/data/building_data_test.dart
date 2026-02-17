
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/data/data_parser.dart';

void main() {
  test('Building data contains SGW campus buildings', () async {
    

    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    final result = allBuildings
            .where((b) => b.campus == Campus.sgw)
            .toList();
    

    expect(result.length, 36);
  });

  test('Building data contains Loyola campus buildings', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    final result = allBuildings
            .where((b) => b.campus == Campus.loyola)
            .toList();
    

    expect(result.length, 26);
  });

  test('SGW and Loyola buildings are distinct', () async {

    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();


    final sgwBuildings = allBuildings
        .where((b) => b.campus == Campus.sgw)
        .toList();
    final loyolaBuildings = allBuildings
        .where((b) => b.campus == Campus.loyola)
        .toList();

    expect(sgwBuildings.any((b) => loyolaBuildings.contains(b)), false);
  });

  test('openinghours,departments and services not a list,thus return empty list', () {
    final parser = DataParser();

    final fakeJson = {
      "features": [
        {
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [-73.0, 45.0],
                [-73.1, 45.1],
                [-73.2, 45.2],
              ]
            ]
          },
          "properties": {
            "id": "1",
            "name": "Test Building",
            "campus": "sgw",
            "description": "desc",
            "fullName": "Test Full Name",
            "isWheelchairAccessible": true,
            "hasBikeParking": false,
            "hasCarParking": false,
            "openingHours": "closed due to ...",
            "departments": "not a list",
            "services": "still not a list"
          }
        }
      ]
    };

    final result = parser.parseBuildings(fakeJson);

    final building = result.first;

    expect(building.openingHours, isEmpty);
    expect(building.departments, isEmpty);
    expect(building.services, isEmpty);
  });
}
