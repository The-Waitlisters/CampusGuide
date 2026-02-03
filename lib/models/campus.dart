import 'package:google_maps_flutter/google_maps_flutter.dart';

enum Campus
{
  sgw,
  loyola,
}

class CampusInfo
{
  final LatLng center;
  final double zoom;

  const CampusInfo({
    required this.center,
    required this.zoom,
  });
}

const Map<Campus, CampusInfo> campusInfo =
{
  Campus.sgw: CampusInfo(
    center: LatLng(45.4973, -73.5789),
    zoom: 16,
  ),
  Campus.loyola: CampusInfo(
    center: LatLng(45.4582, -73.6405),
    zoom: 16,
  ),
};
