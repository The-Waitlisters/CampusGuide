import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus_building.dart';

/// Pumps frames continuously for [duration] so the UI stays live.
/// Use instead of pumpAndSettle() when Google Maps is rendering (avoids infinite loop).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Call once at the top of each integration test file (before pumpWidget).
/// Loads .env so that Secrets.directionsApiKey is available in tests.
Future<void> loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Already loaded or file not present — ignore.
  }
}

/// Returns the centroid of a polygon boundary.
/// Used in tests to produce a point that is reliably inside a building shape.
LatLng polygonCenter(List<LatLng> points) {
  double lat = 0;
  double lng = 0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}

/// Returns the first building matching [campus] that also has a non-null,
/// non-empty fullName. Useful for tests that assert on fullName display.
CampusBuilding firstBuildingWithFullName(
    List<CampusBuilding> buildings, dynamic campus) {
  return buildings.firstWhere(
        (b) => b.campus == campus && (b.fullName ?? '').trim().isNotEmpty,
  );
}

// Set to true when you want to visually observe the tests on the emulator.
// Set to false for fast CI runs.
const bool kSlowMode = bool.fromEnvironment('SLOW_MODE', defaultValue: true);

Future<void> pause([int seconds = 2]) async {
  if (kSlowMode) {
    await Future.delayed(Duration(seconds: seconds));
  }
}