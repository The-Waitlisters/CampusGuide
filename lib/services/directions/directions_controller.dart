import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/campus.dart';
import '../../services/shuttle_service.dart';
import 'transport_mode_strategy.dart';

// ---------------------------------------------------------------------------
// Polyline styling
// ---------------------------------------------------------------------------

Color _colorForLeg(RouteLeg leg) {
  switch (leg.legMode) {
    case LegMode.walking:
      return const Color(0xFF555555);
    case LegMode.cycling:
      return const Color(0xFF34A853);
    case LegMode.driving:
      return const Color(0xFF1A73E8);
    case LegMode.transit:
      return leg.transitColor ?? const Color(0xFF1A73E8);
    case LegMode.shuttle:
      return const Color(0xFF912338); // Concordia burgundy
  }
}

/// Converts route legs into styled [Polyline]s.
///
/// On web, [PatternItem], [Cap], and [JointType] are not supported by
/// google_maps_flutter_web and cause the polyline to silently fail to render.
/// We guard all three behind a [kIsWeb] check so the polyline always draws.
Set<Polyline> legsToPolylines(List<RouteLeg> legs) {
  return legs.asMap().entries.map((entry) {
    final i        = entry.key;
    final leg      = entry.value;
    debugPrint('[legsToPolylines] leg[$i] mode=${leg.legMode} '
        'points=${leg.polylinePoints.length} '
        'duration=${leg.durationText} distance=${leg.distanceText}');
    final isWalking = leg.legMode == LegMode.walking;

    return Polyline(
      polylineId: PolylineId('route_leg_$i'),
      points:     leg.polylinePoints,
      color:      _colorForLeg(leg),
      width:      isWalking ? 5 : 7,
      geodesic:   true,
      zIndex:     2,
      // PatternItem, Cap and JointType are mobile-only —
      // google_maps_flutter_web silently drops the whole polyline when
      // these are set, so we skip them on web entirely.
      patterns:   kIsWeb || !isWalking
          ? const []
          : [PatternItem.dot, PatternItem.gap(8)],
      startCap:   kIsWeb ? Cap.buttCap   : Cap.roundCap,
      endCap:     kIsWeb ? Cap.buttCap   : Cap.roundCap,
      jointType:  kIsWeb ? JointType.mitered : JointType.round,
    );
  }).toSet();
}

// ---------------------------------------------------------------------------
// DirectionsViewState
// ---------------------------------------------------------------------------

@immutable
class DirectionsViewState {
  const DirectionsViewState({
    required this.isLoading,
    required this.errorMessage,
    required this.polylines,
    required this.legs,
    required this.durationText,
    required this.distanceText,
    this.placeholderMessage,
    this.etaType,
  });

  final bool isLoading;
  final String? errorMessage;

  /// One polyline per leg, styled by mode.
  final Set<Polyline> polylines;

  /// Individual route legs — used by DirectionsCard for per-step breakdown.
  final List<RouteLeg> legs;

  final String? durationText;
  final String? distanceText;

  /// Set when the mode shows a message instead of a live route.
  final String? placeholderMessage;

  /// Shuttle-specific: Realtime or Estimated.
  final ShuttleEtaType? etaType;

  // ---- Convenience getters ------------------------------------------------

  bool get hasRoute => polylines.isNotEmpty;

  /// Single-polyline convenience getter — keeps existing DirectionsCard
  /// callers compiling without any change.
  Polyline? get polyline => polylines.isEmpty ? null : polylines.first;

  factory DirectionsViewState.initial() => const DirectionsViewState(
    isLoading:          false,
    errorMessage:       null,
    polylines:          {},
    legs:               [],
    durationText:       null,
    distanceText:       null,
    placeholderMessage: null,
    etaType:            null,
  );
}

// ---------------------------------------------------------------------------
// DirectionsController
// ---------------------------------------------------------------------------

class DirectionsController extends ChangeNotifier {
  DirectionsController({
    required DirectionsClient client,
    TransportModeStrategy? initialMode,
    ShuttleRouteBuilder? shuttleBuilder,
  })  : _client         = client,
        _mode           = initialMode ?? WalkStrategy(),
        _shuttleBuilder = shuttleBuilder ?? ShuttleRouteBuilder(client: client);

  final DirectionsClient    _client;
  final ShuttleRouteBuilder _shuttleBuilder;

  TransportModeStrategy _mode;
  DirectionsViewState   _state = DirectionsViewState.initial();

  DirectionsViewState   get state => _state;
  TransportModeStrategy get mode  => _mode;

  void setMode(TransportModeStrategy mode) {
    _mode = mode;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // updateRoute
  // -------------------------------------------------------------------------

  Future<void> updateRoute({
    required LatLng? start,
    required LatLng? end,
    Campus? startCampus,
    Campus? endCampus,
  }) async {
    if (start == null || end == null) {
      _state = DirectionsViewState.initial();
      notifyListeners();
      return;
    }

    // ---- Shuttle -----------------------------------------------------------
    if (_mode is ShuttleStrategy) {
      final crossCampus = startCampus != null &&
          endCampus   != null &&
          startCampus != endCampus;

      if (!crossCampus) {
        _state = DirectionsViewState(
          isLoading:          false,
          errorMessage:       null,
          polylines:          const {},
          legs:               const [],
          durationText:       null,
          distanceText:       null,
          placeholderMessage: _shuttlePlaceholder(startCampus, endCampus),
        );
        notifyListeners();
        return;
      }

      _setLoading();

      try {
        final result = await _shuttleBuilder.buildRoute(
          origin:      start,
          destination: end,
          fromCampus:  startCampus,
          toCampus:    endCampus,
        );

        final routeLegs = result.routeResult.legs;
        _state = DirectionsViewState(
          isLoading:    false,
          errorMessage: null,
          polylines:    legsToPolylines(routeLegs),
          legs:         routeLegs,
          durationText: result.routeResult.durationText,
          distanceText: result.routeResult.distanceText,
          etaType:      result.etaType,
        );
        notifyListeners();
      } catch (e) {
        _setError(e.toString());
      }
      return;
    }

    // ---- Walk / Bike / Drive / Transit ------------------------------------
    _setLoading();

    try {
      final result = await _client.getRoute(
        origin:      start,
        destination: end,
        mode:        _mode,
      );

      final routeLegs = result.legs;
      _state = DirectionsViewState(
        isLoading:    false,
        errorMessage: null,
        polylines:    legsToPolylines(routeLegs),
        legs:         routeLegs,
        durationText: result.durationText,
        distanceText: result.distanceText,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _shuttlePlaceholder(Campus? start, Campus? end) {
    if (start == null || end == null) return 'Shuttle routing coming next';
    if (start == end) {
      return 'Shuttle is only available for cross-campus travel (SGW ↔ Loyola)';
    }
    return 'Shuttle routing coming next';
  }

  void _setLoading() {
    _state = DirectionsViewState(
      isLoading:    true,
      errorMessage: null,
      polylines:    _state.polylines,
      legs:         _state.legs,
      durationText: _state.durationText,
      distanceText: _state.distanceText,
    );
    notifyListeners();
  }

  void _setError(String message) {
    _state = DirectionsViewState(
      isLoading:    false,
      errorMessage: message,
      polylines:    const {},
      legs:         const [],
      durationText: null,
      distanceText: null,
    );
    notifyListeners();
  }
}