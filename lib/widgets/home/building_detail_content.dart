import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/poi.dart';

class BuildingDetailContent extends StatelessWidget {
  const BuildingDetailContent({
    super.key,
    this.building,
    this.poi,
    required this.isAnnex,
    this.startBuilding,
    this.endBuilding,
    required this.onSetStart,
    required this.onSetDestination,
    required this.isPoi,
    this.onViewIndoorMap,
    this.startPoi,
    this.endPoi,
  });

  final Poi? poi;

  final CampusBuilding? building;
  final bool isAnnex;

  final bool isPoi;

  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;

  final Poi? startPoi;
  final Poi? endPoi;

  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback? onViewIndoorMap;

  Widget _buildHeader() {
    return Text(
      _buildHeaderTitle(),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  String _buildHeaderTitle() {
    final String baseName = building?.name ?? poi?.name ?? '';

    if (isPoi) {
      return baseName;
    }

    if (isAnnex) {
      return '$baseName Annex';
    }

    final String fullName = building?.fullName ?? poi?.name ?? '';
    return '$baseName - $fullName';
  }

  Widget _buildAccessibilityIcons() {
    final bool show =
        building!.isWheelchairAccessible ||
        building!.hasBikeParking ||
        building!.hasCarParking ||
        building!.hasMetroAccess;
    if (!show) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (building!.isWheelchairAccessible) const Icon(Icons.accessible),
        if (building!.hasBikeParking) const Icon(Icons.pedal_bike),
        if (building!.hasCarParking) const Icon(Icons.local_parking),
        if (building!.hasMetroAccess) const Icon(Icons.train),
      ],
    );
  }

    Widget _buildSection(
        String title,
        List<String> items, {
          TextStyle? itemStyle,
        }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...items.map((e) => Text(e == '-' ? 'None' : e, style: itemStyle)),        const SizedBox(height: 12),
      ],
    );
  }

  void _openZoomableImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: Icon(Icons.broken_image, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

Widget _buildPhotoGallery() {
  if (poi!.photoName == null || poi!.photoName!.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No photos available'),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: poi!.photoName!.length,
        itemBuilder: (context, index) {
          final imageUrl = poi!.photoName![index];

          return GestureDetector(
            onTap: () => _openZoomableImage(context, imageUrl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool poiOpenNow = poi?.openNow ?? false;
    final String openText = poiOpenNow ? 'Open' : 'Closed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(),
        if (isPoi)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${poi?.description ?? ''}, Rating: ${poi?.rating}/5'),
              Text(
                openText,
                style: TextStyle(color: poiOpenNow ? Colors.green : Colors.red),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            ElevatedButton(
              onPressed: _startAction(),
              child: const Text('Set as Start'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _destinationAction(),
              child: const Text('Set as Destination'),
            ),
          ],
        ),
<<<<<<< HEAD
        const SizedBox(height: 12),
        _buildAccessibilityIcons(),
        const SizedBox(height: 12),
        Text(building.description ?? ''),
        const SizedBox(height: 12),
        _buildSection(
          'Opening Hours:',
          building!.openingHours,
          itemStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000), //Dark Red
          ),
        ),        _buildSection('Departments:', building.departments),
        _buildSection('Services:', building.services),
        if (onViewIndoorMap != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('view_indoor_map_button'),
            icon: const Icon(Icons.map),
            label: const Text('View indoor map'),
            onPressed: onViewIndoorMap,
=======
        if (!isPoi) ...<Widget>[
          const SizedBox(height: 12),
          _buildAccessibilityIcons(),
          const SizedBox(height: 12),
          Text(building?.description ?? ''),
          const SizedBox(height: 12),
          _buildSection('Opening Hours:', building!.openingHours),
          _buildSection('Departments:', building!.departments),
          _buildSection('Services:', building!.services),
          if (onViewIndoorMap != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('view_indoor_map_button'),
              icon: const Icon(Icons.map),
              label: const Text('View indoor map'),
              onPressed: onViewIndoorMap,
            ),
          ],
        ],
        if (isPoi) ...<Widget>[
          const SizedBox(height: 12),
          _buildPhotoGallery(),
          const SizedBox(height: 18),
          const Text(
            'Opening Hours',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
>>>>>>> 21b40a6c7e6cefe8fd13a45d63e397277f9f6269
          ),
          const SizedBox(height: 12),
          for (final String hour in poi?.openingHours ?? <String>[]) Text(hour),
          if ((poi?.openingHours ?? <String>[]).isEmpty)
            const Text('Location is closed for the foreseeable future'),
        ],
      ],
    );
  }

  VoidCallback? _startAction() {
    if (isPoi) {
      if (startPoi?.id == poi?.id) {
        return null;
      }

      return onSetStart;
    }

    if (startBuilding?.id == building?.id) {
      return null;
    }

    return onSetStart;
  }

  VoidCallback? _destinationAction() {
    if (isPoi) {
      if (endPoi?.id == poi?.id) {
        return null;
      }

      return onSetDestination;
    }

    if (endBuilding?.id == building?.id) {
      return null;
    }

    return onSetDestination;
  }
}
