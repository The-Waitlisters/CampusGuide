import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/models/floor.dart';
import 'package:proj/models/room.dart';

Room _room(String id, String name) => Room(
      id: id,
      name: name,
      boundary: const [
        Offset(0, 0),
        Offset(0.1, 0),
        Offset(0.1, 0.1),
        Offset(0, 0.1),
      ],
    );

void main() {
  group('US-5.1: Floor', () {
    late Floor floor;

    setUp(() {
      floor = Floor(
        level: 8,
        label: 'H 8',
        rooms: [
          _room('801', 'Room 801'),
          _room('802', 'Conference Room'),
          _room('803', ''),
        ],
        imageAspectRatio: 1.5,
      );
    });

    test('roomById returns correct room', () {
      expect(floor.roomById('801')?.id, '801');
    });

    test('roomById returns null for unknown id', () {
      expect(floor.roomById('999'), isNull);
    });

    test('searchByNameOrNumber returns all rooms for empty query', () {
      expect(floor.searchByNameOrNumber('').length, 3);
    });

    test('searchByNameOrNumber matches by room number substring', () {
      final results = floor.searchByNameOrNumber('801');
      expect(results.length, 1);
      expect(results.first.id, '801');
    });

    test('searchByNameOrNumber matches by name substring case-insensitively',
        () {
      final results = floor.searchByNameOrNumber('conference');
      expect(results.length, 1);
      expect(results.first.id, '802');
    });

    test('searchByNameOrNumber returns empty list for no match', () {
      expect(floor.searchByNameOrNumber('999xyz'), isEmpty);
    });

    test('imageAspectRatio is stored correctly', () {
      expect(floor.imageAspectRatio, closeTo(1.5, 0.001));
    });

    test('imageAspectRatio defaults to 1.0', () {
      final f = Floor(level: 1, label: 'F1', rooms: const []);
      expect(f.imageAspectRatio, closeTo(1.0, 0.001));
    });

    test('imagePath is null by default', () {
      final f = Floor(level: 1, label: 'F1', rooms: const []);
      expect(f.imagePath, isNull);
    });

    test('imagePath is stored when provided', () {
      final f = Floor(
        level: 8,
        label: 'H 8',
        rooms: const [],
        imagePath: 'assets/indoor/H_8.png',
      );
      expect(f.imagePath, 'assets/indoor/H_8.png');
    });

    test('navGraph is null by default', () {
      final f = Floor(level: 1, label: 'F1', rooms: const []);
      expect(f.navGraph, isNull);
    });
  });
}
