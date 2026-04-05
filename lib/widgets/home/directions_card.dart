import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/indoor_map.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/services/shuttle_service.dart';

class DirectionsCard extends StatelessWidget {
  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;
  final Poi? startPoi;
  final Poi? endPoi;

  final bool isLoading;
  final String? errorMessage;
  final Polyline? polyline;
  final String? durationText;
  final String? distanceText;

  final VoidCallback onCancel;
  final VoidCallback onRetry;

  final bool useCurrentLocationAsStart;

  /// Shown when destination-first but location permission unavailable.
  final String? locationRequiredMessage;
  final String? placeholderMessage;

  final String selectedModeParam;

  /// Called when user picks a mode.
  final void Function(String modeParam) onModeChanged;

  /// Shuttle ETA type: Realtime or Estimated. Null for non-shuttle modes.
  final ShuttleEtaType? etaType;

  /// Individual route legs — used to render the per-step breakdown.
  /// When null or has only one leg, the compact single-line summary is shown.
  final List<RouteLeg>? legs;

  // Room-to-room state
  final bool roomToRoomEnabled;
  final ValueChanged<bool> onRoomToRoomToggled;
  final IndoorMap? startIndoorMap;
  final IndoorMap? endIndoorMap;
  final int? startFloorFilter;
  final int? endFloorFilter;
  final String? startRoomId;
  final String? endRoomId;
  final ValueChanged<int> onStartFloorChanged;
  final ValueChanged<int> onEndFloorChanged;
  final ValueChanged<String?> onStartRoomChanged;
  final ValueChanged<String?> onEndRoomChanged;
  final VoidCallback? onStartNavigation;
  final bool indoorMapsLoading;

  const DirectionsCard({
    super.key,
    this.startBuilding,
    this.endBuilding,
    this.startPoi,
    this.endPoi,
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
    this.etaType,
    this.legs,
    this.roomToRoomEnabled = false,
    required this.onRoomToRoomToggled,
    this.startIndoorMap,
    this.endIndoorMap,
    this.startFloorFilter,
    this.endFloorFilter,
    this.startRoomId,
    this.endRoomId,
    required this.onStartFloorChanged,
    required this.onEndFloorChanged,
    required this.onStartRoomChanged,
    required this.onEndRoomChanged,
    this.onStartNavigation,
    this.indoorMapsLoading = false,
  });

  static String _campusLabel(Campus c) => c == Campus.sgw ? 'SGW' : 'Loyola';

  static IconData _iconForLegMode(LegMode mode) {
    switch (mode) {
      case LegMode.walking:
        return Icons.directions_walk;
      case LegMode.cycling:
        return Icons.directions_bike;
      case LegMode.driving:
        return Icons.directions_car;
      case LegMode.transit:
        return Icons.directions_bus;
      case LegMode.shuttle:
        return Icons.airport_shuttle;
    }
  }

  static Color _colorForLegMode(LegMode mode, {Color? transitColor}) {
    switch (mode) {
      case LegMode.walking:
        return const Color(0xFF555555);
      case LegMode.cycling:
        return const Color(0xFF34A853);
      case LegMode.driving:
        return const Color(0xFF1A73E8);
      case LegMode.transit:
        return transitColor ?? const Color(0xFF1A73E8);
      case LegMode.shuttle:
        return const Color(0xFF912338);
    }
  }

  static String _labelForLegMode(LegMode mode) {
    switch (mode) {
      case LegMode.walking:
        return 'Walk';
      case LegMode.cycling:
        return 'Bike';
      case LegMode.driving:
        return 'Drive';
      case LegMode.transit:
        return 'Transit';
      case LegMode.shuttle:
        return 'Shuttle';
    }
  }

  Widget _etaBadge() {
    final isRealtime = etaType == ShuttleEtaType.realtime;
    final color = isRealtime
        ? const Color(0xFF34A853)
        : const Color(0xFFF57C00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRealtime ? Icons.wifi : Icons.schedule,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isRealtime ? 'Realtime' : 'Estimated',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows one row per leg: colored icon + mode label + duration + distance.
  Widget _stepsBreakdown(BuildContext context) {
    final effectiveLegs = legs;
    if (effectiveLegs == null || effectiveLegs.isEmpty) {
      return const SizedBox.shrink();
    }
    if (effectiveLegs.length == 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        ...effectiveLegs.map((leg) {
          final color = _colorForLegMode(leg.legMode,
              transitColor: leg.transitColor);
          final icon = _iconForLegMode(leg.legMode);
          final label = leg.lineName ?? _labelForLegMode(leg.legMode);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  leg.durationText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (leg.distanceText.isNotEmpty) ...[
                  const Text(
                    ' · ',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    leg.distanceText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const Divider(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Text(
                  '${durationText ?? ''}'
                      '${durationText != null && distanceText != null ? ' · ' : ''}'
                      '${distanceText ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (etaType != null) ...[
                  const SizedBox(width: 8),
                  _etaBadge(),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if ((startBuilding == null && endBuilding == null)) {
      if (startPoi == null && endPoi == null) {
        return const SizedBox.shrink();
      }
    }

    final startLabel = startBuilding != null
        ? '${_campusLabel(startBuilding!.campus)} - ${startBuilding!.fullName ?? startBuilding!.name}'
        : (startPoi != null
            ? '${_campusLabel(startPoi!.campus)} - ${startPoi!.name}'
            : (useCurrentLocationAsStart ? 'Current location' : 'Not set'));
    final endLabel = endBuilding != null
        ? '${_campusLabel(endBuilding!.campus)} - ${endBuilding!.fullName ?? endBuilding!.name}'
        : (endPoi != null ? endPoi!.name : 'Not set');

    final bothBuildingsSet = startBuilding != null &&
        endBuilding != null &&
        startBuilding!.id != endBuilding!.id;
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
                    'Directions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Start: $startLabel'),
              const SizedBox(height: 6),
              Text('Destination: $endLabel'),
              if (endBuilding != null || endPoi != null) ...[
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
              if (endBuilding == null && endPoi == null)
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
              else if (polyline != null ||
                  (legs != null && legs!.isNotEmpty)) ...[
                if (legs == null || legs!.length <= 1)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${durationText ?? ''}'
                              '${durationText != null && distanceText != null ? ' · ' : ''}'
                              '${distanceText ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (etaType != null) _etaBadge(),
                    ],
                  ),
                _stepsBreakdown(context),
              ],
              if (bothBuildingsSet) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.meeting_room, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Room-to-Room Navigation',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Switch(
                      key: const Key('room_to_room_toggle'),
                      value: roomToRoomEnabled,
                      onChanged: onRoomToRoomToggled,
                    ),
                  ],
                ),
                if (roomToRoomEnabled) ...[
                  if (indoorMapsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading indoor maps...',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  else if (startIndoorMap == null || endIndoorMap == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Indoor maps not available for one or both buildings.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 4),
                    _RoomPicker(
                      label: 'Start room',
                      buildingName: startBuilding!.name,
                      map: startIndoorMap!,
                      floorFilter:
                          startFloorFilter ?? startIndoorMap!.floorLevels.first,
                      selectedRoomId: startRoomId,
                      chipColor: Colors.green,
                      onFloorChanged: onStartFloorChanged,
                      onRoomChanged: onStartRoomChanged,
                    ),
                    const SizedBox(height: 6),
                    _RoomPicker(
                      label: 'Dest room',
                      buildingName: endBuilding!.name,
                      map: endIndoorMap!,
                      floorFilter:
                          endFloorFilter ?? endIndoorMap!.floorLevels.first,
                      selectedRoomId: endRoomId,
                      chipColor: Colors.blue,
                      onFloorChanged: onEndFloorChanged,
                      onRoomChanged: onEndRoomChanged,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('start_navigation_button'),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Start Navigation'),
                        onPressed: onStartNavigation,
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPicker extends StatelessWidget {
  final String label;
  final String buildingName;
  final IndoorMap map;
  final int floorFilter;
  final String? selectedRoomId;
  final Color chipColor;
  final ValueChanged<int> onFloorChanged;
  final ValueChanged<String?> onRoomChanged;

  const _RoomPicker({
    required this.label,
    required this.buildingName,
    required this.map,
    required this.floorFilter,
    required this.selectedRoomId,
    required this.chipColor,
    required this.onFloorChanged,
    required this.onRoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final floors = map.floorLevels;
    final rooms = map.getFloorByLevel(floorFilter)?.rooms ?? [];

    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: chipColor),
        const SizedBox(width: 4),
        Text('$label ($buildingName)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: floorFilter,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: floors.map((l) {
            final f = map.getFloorByLevel(l);
            return DropdownMenuItem(
              value: l,
              child: Text(f?.label ?? 'F$l',
                  style: const TextStyle(fontSize: 11)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              onFloorChanged(v);
              onRoomChanged(null);
            }
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButton<String>(
            value: selectedRoomId,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('Room', style: TextStyle(fontSize: 11)),
            items: rooms.map((r) {
              final name = r.name.isNotEmpty ? r.name : r.id;
              return DropdownMenuItem(
                value: r.id,
                child: Text(name, style: const TextStyle(fontSize: 11)),
              );
            }).toList(),
            onChanged: onRoomChanged,
          ),
        ),
      ],
    );
  }
}