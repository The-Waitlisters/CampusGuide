import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';

class BuildingDetailContent extends StatelessWidget {
  const BuildingDetailContent({
    super.key,
    required this.building,
    required this.isAnnex,
    required this.startBuilding,
    required this.endBuilding,
    required this.onSetStart,
    required this.onSetDestination,
  });

  final CampusBuilding building;
  final bool isAnnex;

  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;

  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${building.name} ${isAnnex ? 'Annex' : '- ${building.fullName}'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Direction selection buttons
        if (startBuilding == null)
          ElevatedButton(
            onPressed: onSetStart,

            child: const Text('Set as Start'),
          )
        else
          ElevatedButton(
            onPressed: (startBuilding?.id == building.id)
                ? null
                : onSetDestination,
            child: const Text('Set as Destination'),
          ),

        const SizedBox(height: 12),
        if (building.isWheelchairAccessible ||
            building.hasBikeParking ||
            building.hasCarParking)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (building.isWheelchairAccessible)
                const Icon(Icons.accessible),
              if (building.hasBikeParking)
                const Icon(Icons.pedal_bike),
              if (building.hasCarParking)
                const Icon(Icons.local_parking),
            ],
          ),
        const SizedBox(height: 12),
        Text(building.description ?? ''),
        const SizedBox(height: 12),
        const Text(
          'Opening Hours:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.openingHours.map(
              (e) => Text((e == '-') ? 'None' : e),
        ),
        const SizedBox(height: 12),
        const Text(
          'Departments:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.departments.map(
              (e) => Text((e == '-') ? 'None' : e),
        ),
        const SizedBox(height: 12),
        const Text(
          'Services:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...building.services.map(
              (e) => Text((e == '-') ? 'None' : e),
        ),
      ],
    );
  }
}
