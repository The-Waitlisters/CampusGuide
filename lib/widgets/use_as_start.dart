import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';

class UseAsStart extends StatelessWidget {
  const UseAsStart({
    super.key,
    required this.selected,
    required this.onSetStart,
  });

  final CampusBuilding selected;
  final VoidCallback onSetStart;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onSetStart, child: const Text('Start from Current Building', style: TextStyle(fontSize: 12),));

  }
}
