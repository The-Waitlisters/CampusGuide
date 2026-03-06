import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/campus.dart';
import 'transport_mode_strategy.dart';

@immutable
class DirectionsViewState {
  const DirectionsViewState({
    required this.isLoading,
    required this.errorMessage,
    required this.polyline,
    required this.durationText,
    required this.distanceText,
    this.placeholderMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final Polyline? polyline;
  final String? durationText;
  final String? distanceText;
  /// When set (e.g. for Shuttle mode), UI shows this instead of route; no API call.
  final String? placeholderMessage;

  factory DirectionsViewState.initial() => const DirectionsViewState(
    isLoading: false,
    errorMessage: null,
    polyline: null,
    durationText: null,
    distanceText: null,
    placeholderMessage: null,
  );
}

class DirectionsController extends ChangeNotifier {
  DirectionsController({
    required DirectionsClient client,
    TransportModeStrategy? initialMode,
  })  : _client = client,
        _mode = initialMode ?? WalkStrategy();

  final DirectionsClient _client;

  TransportModeStrategy _mode;
  DirectionsViewState _state = DirectionsViewState.initial();

  DirectionsViewState get state => _state;
  TransportModeStrategy get mode => _mode;

  void setMode(TransportModeStrategy mode) {
    _mode = mode;
    notifyListeners();
  }

  String _shuttlePlaceholderMessage(Campus? startCampus, Campus? endCampus) {
    if (startCampus == null || endCampus == null) {
      return 'Shuttle routing coming next';
    }
    if (startCampus != endCampus) {
      return 'Shuttle service is coming soon for SGW ↔ Loyola travel';
    }
    return 'Shuttle is only available for cross-campus travel';
  }

  /// Call this whenever start/end changes.
  /// [startCampus] and [endCampus] are used for Shuttle mode placeholder messages.
  Future<void> updateRoute({
    required LatLng? start,
    required LatLng? end,
    Campus? startCampus,
    Campus? endCampus,
  }) async {
    // Acceptance criteria: if missing start/end -> no route shown
    if (start == null || end == null) {
      _state = DirectionsViewState.initial();
      notifyListeners();
      return;
    }

    // Shuttle: no API call; show campus-aware placeholder
    if (_mode is ShuttleStrategy) {
      final msg = _shuttlePlaceholderMessage(startCampus, endCampus);
      _state = DirectionsViewState(
        isLoading: false,
        errorMessage: null,
        polyline: null,
        durationText: null,
        distanceText: null,
        placeholderMessage: msg,
      );
      notifyListeners();
      return;
    }

      _state = DirectionsViewState(
        isLoading: true,
        errorMessage: null,
        polyline: _state.polyline, // keep old route while loading (optional)
        durationText: _state.durationText,
        distanceText: _state.distanceText,
        placeholderMessage: null,
      );
    notifyListeners();

    try {
      final result = await _client.getRoute(
        origin: start,
        destination: end,
        mode: _mode,
      );

      _state = DirectionsViewState(
        isLoading: false,
        errorMessage: null,
        polyline: Polyline(
          polylineId: const PolylineId('route'),
          points: result.polylinePoints,
          width: 7,
          color: const Color(0xFF1A73E8), // Google Maps-like blue
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          geodesic: true,
          zIndex: 2,
        ),
        durationText: result.durationText,
        distanceText: result.distanceText,
      );
      notifyListeners();
    } catch (e) {
      // Acceptance criteria: if generation fails, show “Retry/Get directions” later.
      _state = DirectionsViewState(
        isLoading: false,
        errorMessage: e.toString(),
        polyline: null,
        durationText: null,
        distanceText: null,
      );
      notifyListeners();
    }
  }
}