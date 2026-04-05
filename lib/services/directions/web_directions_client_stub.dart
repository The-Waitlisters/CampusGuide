import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'transport_mode_strategy.dart';

/// Non-web stub for [WebDirectionsClient].
///
/// Imported on non-web platforms via the conditional import in home_screen.dart.
/// Never actually instantiated there (guarded by [kIsWeb]), but must compile on
/// all platforms so the conditional-import pattern works.
class WebDirectionsClient implements DirectionsClient {
  @override
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportModeStrategy mode,
  }) =>
      throw UnsupportedError('WebDirectionsClient is only available on web.');
}
