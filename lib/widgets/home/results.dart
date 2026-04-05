import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/poi.dart';

class Results extends StatelessWidget {
  final List<Poi> poiPresent;
  final LatLng locationPoint;

  final ValueChanged<Poi> onSelect;
  final VoidCallback onClose;

  const Results({
    super.key,
    required this.poiPresent,
    required this.locationPoint,
    required this.onSelect, required this.onClose,
  });

  String _computeDistance(LatLng point1, LatLng point2) {
    //distance in km
    double R = 6356;

    double x = R * (pi / 180) * (point2.latitude - point1.latitude);
    double y =
        R *
        (pi / 180) *
        (point2.longitude - point1.longitude) *
        cos(point1.latitude);

    double distance = sqrt(pow(x, 2) + pow(y, 2));
    String roundedDistance;
    if(distance < 1) {
      distance *= 1000;
      roundedDistance = distance.toStringAsFixed(2);
      roundedDistance += ' m';
    } else {
      roundedDistance = distance.toStringAsFixed(2);
      roundedDistance += ' km';
    }
    

    return roundedDistance;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Card(
              elevation: 8,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Results',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: poiPresent.isEmpty
                            ? const Center(child: Text('No matching results'))
                            : ListView.builder(
                                itemCount: poiPresent.length,
                                itemBuilder: (context, i) {
                                  final result = poiPresent[i];

                                  String subtitle = "";

                                  if (result.description!.trim().isNotEmpty) {
                                    subtitle =
                                        '${result.description} • ${_computeDistance(locationPoint, result.boundary)}';
                                  }

                                  return ListTile(
                                    title: Text(result.name),
                                    subtitle: Text(subtitle),
                                    onTap: () => onSelect(result),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
