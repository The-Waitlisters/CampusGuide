
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
    

    expect(result.length == 36, true);
  });

  test('Building data contains Loyola campus buildings', () async {
    TestWidgetsFlutterBinding.ensureInitialized();


    final allBuildings = await DataParser().getBuildingInfoFromJSON();
    final result = allBuildings
            .where((b) => b.campus == Campus.loyola)
            .toList();
    

    expect(result.length == 26, true);
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
}
