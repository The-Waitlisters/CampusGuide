import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';
import 'package:proj/services/shuttle_service.dart';

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

  /// Called when user picks a mode.
  final void Function(String modeParam) onModeChanged;

  // ── New optional params ────────────────────────────────────────────────────

  /// Shuttle ETA type: Realtime or Estimated. Null for non-shuttle modes.
  final ShuttleEtaType? etaType;

  /// Individual route legs — used to render the per-step breakdown.
  /// When null or has only one leg, the compact single-line summary is shown.
  final List<RouteLeg>? legs;

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
    // New optional — default null keeps backwards compatibility
    this.etaType,
    this.legs,
  });

  static String _campusLabel(Campus c) => c == Campus.sgw ? 'SGW' : 'Loyola';

  // ── Mode icons ─────────────────────────────────────────────────────────────

  static IconData _iconForLegMode(LegMode mode) {
    switch (mode) {
      case LegMode.walking:   return Icons.directions_walk;
      case LegMode.cycling:   return Icons.directions_bike;
      case LegMode.driving:   return Icons.directions_car;
      case LegMode.transit:   return Icons.directions_bus;
      case LegMode.shuttle:   return Icons.airport_shuttle;
    }
  }

  static Color _colorForLegMode(LegMode mode, {Color? transitColor}) {
    switch (mode) {
      case LegMode.walking:   return const Color(0xFF555555);
      case LegMode.cycling:   return const Color(0xFF34A853);
      case LegMode.driving:   return const Color(0xFF1A73E8);
      case LegMode.transit:   return transitColor ?? const Color(0xFF1A73E8);
      case LegMode.shuttle:   return const Color(0xFF912338); // Concordia burgundy
    }
  }

  static String _labelForLegMode(LegMode mode) {
    switch (mode) {
      case LegMode.walking:   return 'Walk';
      case LegMode.cycling:   return 'Bike';
      case LegMode.driving:   return 'Drive';
      case LegMode.transit:   return 'Transit';
      case LegMode.shuttle:   return 'Shuttle';
    }
  }

  // ── ETA badge ──────────────────────────────────────────────────────────────

  Widget _etaBadge() {
    final isRealtime = etaType == ShuttleEtaType.realtime;
    final color = isRealtime
        ? const Color(0xFF34A853)   // green for realtime
        : const Color(0xFFF57C00);  // amber for estimated

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

  // ── Step breakdown ─────────────────────────────────────────────────────────

  /// Shows one row per leg: colored icon + mode label + duration + distance.
  Widget _stepsBreakdown(BuildContext context) {
    final effectiveLegs = legs;
    if (effectiveLegs == null || effectiveLegs.isEmpty) return const SizedBox.shrink();

    // Only show the breakdown when there are multiple legs (multi-modal).
    // Single-leg routes use the compact summary line below.
    if (effectiveLegs.length == 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        // Per-leg rows
        ...effectiveLegs.map((leg) {
          final color = _colorForLegMode(leg.legMode,
              transitColor: leg.transitColor);
          final icon  = _iconForLegMode(leg.legMode);
          final label = leg.lineName ?? _labelForLegMode(leg.legMode);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                // Colored mode icon
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
                // Mode name
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
                // Duration
                Text(
                  leg.durationText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Distance (only when non-empty and not the shuttle "≈ 7 km" filler)
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

        // Total line
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

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (startBuilding == null && endBuilding == null) {
      return const SizedBox.shrink();
    }

    final startLabel = startBuilding != null
        ? '${_campusLabel(startBuilding!.campus)} - '
        '${startBuilding!.fullName ?? startBuilding!.name}'
        : (useCurrentLocationAsStart ? 'Current location' : 'Not set');
    final endLabel = endBuilding != null
        ? '${_campusLabel(endBuilding!.campus)} - '
        '${endBuilding!.fullName ?? endBuilding!.name}'
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
              // ── Header ────────────────────────────────────────────────────
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

              // ── Mode chips ────────────────────────────────────────────────
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

              // ── Status area ───────────────────────────────────────────────
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
                    else if (polyline != null || (legs != null && legs!.isNotEmpty)) ...[
                        // ── Single-leg compact summary (or multi-leg top-line) ──────
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

                        // ── Multi-leg step breakdown ───────────────────────────────
                        _stepsBreakdown(context),
                      ],
            ],
          ),
        ),
      ),
    );
  }
}