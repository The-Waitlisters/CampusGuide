import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/room.dart';

void main() {
  group('US-5.1: Room', () {
    test('displayLabel returns name', () {
      const room = Room(
        id: '801',
        name: 'H-801',
        boundary: [Offset(0, 0), Offset(0.1, 0), Offset(0.1, 0.1), Offset(0, 0.1)],
      );
      expect(room.displayLabel, 'H-801');
    });

    test('displayLabel returns empty string when name is empty', () {
      const room = Room(
        id: 'wp1',
        name: '',
        boundary: [Offset(0.5, 0.5), Offset(0.6, 0.5), Offset(0.6, 0.6), Offset(0.5, 0.6)],
      );
      expect(room.displayLabel, '');
    });
  });
}
