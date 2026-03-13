import 'package:flutter/material.dart';

/// A room on a floor. [boundary] is in relative coordinates (0..1) for the floor canvas.
class Room {
  final String id;
  final String name;
  final List<Offset> boundary;
  final bool accessible;

  const Room({
    required this.id,
    required this.name,
    required this.boundary,
    this.accessible = true,
  });

  /// Display label for search (e.g. "H-521" or "Room 521").
  String get displayLabel => name;
}
