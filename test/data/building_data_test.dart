import 'package:flutter_test/flutter_test.dart';
import 'package:proj/data/building_data.dart';
import 'package:proj/models/campus.dart';

void main() {
  test('Building data contains SGW campus buildings', () {
    final sgwBuildings = campusBuildings
        .where((b) => b.campus == Campus.sgw)
        .toList();

    expect(sgwBuildings.isNotEmpty, true);
  });

  test('Building data contains Loyola campus buildings', () {
    final loyolaBuildings = campusBuildings
        .where((b) => b.campus == Campus.loyola)
        .toList();

    expect(loyolaBuildings.isNotEmpty, true);
  });

  test('SGW and Loyola buildings are distinct', () {
    final sgwBuildings = campusBuildings
        .where((b) => b.campus == Campus.sgw)
        .toList();
    final loyolaBuildings = campusBuildings
        .where((b) => b.campus == Campus.loyola)
        .toList();

    expect(sgwBuildings.any((b) => loyolaBuildings.contains(b)), false);
  });
}
