import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';

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

  /// True when route start is user's current location (destination-first flow).
  final bool useCurrentLocationAsStart;
  /// Shown when destination-first but location permission unavailable.
  final String? locationRequiredMessage;

  /// Placeholder message when mode doesn't use Directions API (e.g. Shuttle).
  final String? placeholderMessage;

  /// Current transport mode param (e.g. 'walking'). Used to show selected mode.
  final String selectedModeParam;
  /// Called when user picks a mode; [modeParam] is e.g. 'walking', 'bicycling', 'driving', 'transit'.
  final void Function(String modeParam) onModeChanged;

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
    this.useCurrentLocationAsStart = false,
    this.locationRequiredMessage,
    this.placeholderMessage,
    required this.selectedModeParam,
    required this.onModeChanged,
  });

  static String _campusLabel(Campus c) => c == Campus.sgw ? 'SGW' : 'Loyola';

  @override
  Widget build(BuildContext context) {
    if (startBuilding == null && endBuilding == null) {
      return const SizedBox.shrink();
    }

    final startLabel = startBuilding != null
        ? '${_campusLabel(startBuilding!.campus)} - ${startBuilding!.fullName ?? startBuilding!.name}'
        : (useCurrentLocationAsStart ? 'Current location' : 'Not set');
    final endLabel = endBuilding != null
        ? '${_campusLabel(endBuilding!.campus)} - ${endBuilding!.fullName ?? endBuilding!.name}'
        : 'Not set';

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
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
              if (endBuilding != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: kTransportModes.map((m) {
                    final selected = selectedModeParam == m.modeParam;
                    return ChoiceChip(
                      label: Text(m.label),
                      selected: selected,
                      onSelected: (_) => onModeChanged(m.modeParam),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),

              if (endBuilding == null)
                const Text(
                  'Select a destination to see a route.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                )
              else if (locationRequiredMessage != null)
                Text(
                  locationRequiredMessage!,
                  style: const TextStyle(fontSize: 12),
                )
              else if (placeholderMessage != null)
                Text(
                  placeholderMessage!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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