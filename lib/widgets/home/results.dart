import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/poi.dart';

class Results extends StatelessWidget {
  final List<Poi> poiPresent;
  final LatLng locationPoint;
  final ValueChanged<Poi> onSelect;
  final VoidCallback onClose;

  const Results({
    super.key,
    required this.poiPresent,
    required this.locationPoint,
    required this.onSelect,
    required this.onClose,
  });

  // Simple Haversine distance in metres.
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.cancel),
              onPressed: onClose,
            ),
          ],
        ),
        const Divider(height: 1),
        // Body
        if (poiPresent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No matching results')),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: poiPresent.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final poi = poiPresent[i];
                final dist = _distanceMeters(locationPoint, poi.boundary);
                final desc = poi.description;
                final subtitle = (desc != null && desc.isNotEmpty)
                    ? '$desc  •  ${_formatDistance(dist)}'
                    : null;

                return ListTile(
                  title: Text(poi.name),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  onTap: () => onSelect(poi),
                );
              },
            ),
          ),
      ],
    );
  }
}
