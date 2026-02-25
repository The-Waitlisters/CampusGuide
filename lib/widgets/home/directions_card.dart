import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsCard extends StatelessWidget {
  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;

  final bool isLoading;
  final String? errorMessage;
  final Polyline? polyline;
  final String? durationText;
  final String? distanceText;

  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const DirectionsCard({
    super.key,
    required this.startBuilding,
    required this.endBuilding,
    required this.isLoading,
    required this.errorMessage,
    required this.polyline,
    required this.durationText,
    required this.distanceText,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (startBuilding == null) {
      return const SizedBox.shrink();
    }

    final startLabel = startBuilding!.fullName ?? startBuilding!.name;
    final endLabel = endBuilding?.fullName ?? "Not set";

    return Positioned(
      top: 150,
      left: 12,
      right: 12,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Directions",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Start: $startLabel"),
              const SizedBox(height: 6),
              Text("Destination: $endLabel"),
              const SizedBox(height: 8),

              if (endBuilding == null)
                const Text(
                  'Select a destination to see a route.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                )
              else if (isLoading)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading directions...'),
                  ],
                )
              else if (errorMessage != null)
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Directions unavailable')),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (polyline != null)
                    Text(
                      '${durationText ?? ''}'
                          '${durationText != null && distanceText != null ? ' • ' : ''}'
                          '${distanceText ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}