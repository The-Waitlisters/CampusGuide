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

  Widget _buildHeader() {
    return Text(
      '${building.name} ${isAnnex ? 'Annex' : '- ${building.fullName}'}',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAccessibilityIcons() {
    final bool show = building.isWheelchairAccessible ||
        building.hasBikeParking ||
        building.hasCarParking;
    if (!show) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (building.isWheelchairAccessible) const Icon(Icons.accessible),
        if (building.hasBikeParking) const Icon(Icons.pedal_bike),
        if (building.hasCarParking) const Icon(Icons.local_parking),
      ],
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...items.map((e) => Text(e == '-' ? 'None' : e)),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        // Direction selection buttons — always show both
        Row(
          children: [
            ElevatedButton(
              onPressed: startBuilding?.id == building.id ? null : onSetStart,
              child: const Text('Set as Start'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (endBuilding?.id == building.id || startBuilding?.id == building.id)
                  ? null
                  : onSetDestination,
              child: const Text('Set as Destination'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAccessibilityIcons(),
        const SizedBox(height: 12),
        Text(building.description ?? ''),
        const SizedBox(height: 12),
        _buildSection('Opening Hours:', building.openingHours),
        _buildSection('Departments:', building.departments),
        _buildSection('Services:', building.services),
      ],
    );
  }
}
