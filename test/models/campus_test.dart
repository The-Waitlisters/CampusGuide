import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/campus.dart';

void main() {
  test('Campus enum contains SGW and Loyola', () {
    expect(Campus.values.contains(Campus.sgw), true);
    expect(Campus.values.contains(Campus.loyola), true);
  });

  test('Campus info exists for both campuses', () {
    expect(campusInfo.containsKey(Campus.sgw), true);
    expect(campusInfo.containsKey(Campus.loyola), true);
  });
}
