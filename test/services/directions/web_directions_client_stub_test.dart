import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/services/directions/web_directions_client_stub.dart';
import 'package:proj/services/directions/transport_mode_strategy.dart';

void main() {
  test('WebDirectionsClient can be instantiated without throwing', () {
    expect(() => WebDirectionsClient(), returnsNormally);
  });

  test('WebDirectionsClient.getRoute throws UnsupportedError', () {
    final client = WebDirectionsClient();
    expect(
      () => client.getRoute(
        origin:      const LatLng(0, 0),
        destination: const LatLng(1, 1),
        mode:        WalkStrategy(),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
