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
    this.onViewIndoorMap, this.startPoi, this.endPoi,
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
      '${building?.name ?? poi?.name} ${isPoi ? '' : (isAnnex ? 'Annex' : '- ${building?.fullName ?? poi?.name}')}',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAccessibilityIcons() {
    final bool show = building!.isWheelchairAccessible ||
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
  if (poi!.photoName.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Text('No photos available'),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: poi!.photoName.length,
        itemBuilder: (context, index) {
          final imageUrl = poi!.photoName[index];

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
            )
          );
        },
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    String open = "";
    bool status = true;
    (poi) ?? status == false;
    
    (poi?.openNow ?? false) ? open = "Open": open = "Closed";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if(isPoi) Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${poi?.description ?? ''}, Rating: ${poi?.rating}/5'),
           Text(open, style: TextStyle(color: ((poi!.openNow ?? false) ? Colors.green : Colors.red)),)
          ],
          ),
          
        const SizedBox(height: 8),
        // Direction selection buttons — always show both
        Row(
          children: [
            ElevatedButton(
              onPressed: (((startBuilding?.id == building?.id)) ? null : onSetStart) ?? ((startPoi?.id == poi?.id) ? null : onSetStart),
              child: const Text('Set as Start'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
               onPressed: (((endBuilding?.id == building?.id)) ? null : onSetDestination) ?? ((endPoi?.id == poi?.id) ? null : onSetDestination),
              child: const Text('Set as Destination'),
            ),
          ],
        ),
        if(!isPoi) ...[
          const SizedBox(height: 12),
          _buildAccessibilityIcons(),
          const SizedBox(height: 12),
          Text(building!.description ?? ''),
          const SizedBox(height: 12),
          _buildSection('Opening Hours:', building!.openingHours),
          _buildSection('Departments:', building!.departments),
          _buildSection('Services:', building!.services),
          if (onViewIndoorMap != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('view_indoor_map_button'),
              icon: const Icon(Icons.map),
              label: const Text('View indoor map'),
              onPressed: onViewIndoorMap,
            ),
          ],],
        if(isPoi) ...[
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _buildPhotoGallery(),
          const SizedBox(height: 18),
          Text('Opening Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          const SizedBox(height: 12),
          for(final hour in poi!.openingHours) Text(hour),
          if(poi!.openingHours.isEmpty) Text('Location is closed for the forseeable future')
          ],
          
          
      ],
    );
  }
}
