import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';

class useAsStart extends StatelessWidget {
  const useAsStart({
    super.key,
    required this.selected,
    required this.onSetStart,
  });

  final CampusBuilding selected;
  final VoidCallback onSetStart;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onSetStart, child: const Text('Set Current building as starting point'));

  }
}
