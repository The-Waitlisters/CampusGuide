import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/poi.dart';

class PoiDetailContent extends StatelessWidget {
  const PoiDetailContent({
    super.key,
    required this.building,
    required this.startBuilding,
    required this.endBuilding,
    required this.onSetDestination,
    this.onViewIndoorMap, this.startPoi, this.endPoi, required this.onSetStart,
  });

  final Poi building;
  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;
  final Poi? startPoi;
  final Poi? endPoi;
  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback? onViewIndoorMap;

  Widget _buildHeader() {
    return Text(
      '${building.name} ${'- ${building.fullName}'}',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              onPressed: (startBuilding?.id ?? startPoi?.id) == building.id ? null : onSetStart,
              child: const Text('Set as Start'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: ((endBuilding?.id ?? endPoi?.id) == building.id || (startBuilding?.id ?? startPoi?.id) == building.id)
                  ? null
                  : onSetDestination,
              child: const Text('Set as Destination'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        Text(building.description ?? ''),
        const SizedBox(height: 12),
        _buildSection('Opening Hours:', building.openingHours),
        if (onViewIndoorMap != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('view_indoor_map_button'),
            icon: const Icon(Icons.map),
            label: const Text('View indoor map'),
            onPressed: onViewIndoorMap,
          ),
        ],
      ],
    );
  }
}