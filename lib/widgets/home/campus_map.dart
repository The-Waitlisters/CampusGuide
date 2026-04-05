import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CampusMap extends StatelessWidget {
  const CampusMap({
    super.key,
    required this.initialCamera,
    required this.polygons,
    required this.polylines,
    required this.markers,
    required this.onMapCreated,
    required this.onTap,
    required this.myLocationEnabled,
    required this.myLocationButtonEnabled,
  //  required this.onCameraMove,
  });

  final CameraPosition initialCamera;
  final Set<Polygon> polygons;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final void Function(GoogleMapController controller) onMapCreated;
  final void Function(LatLng point) onTap;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
 // final void Function(CameraPosition position) onCameraMove;

  static const String _hidePoiStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [
        { "visibility": "off" }
      ]
    }
  ]
  ''';

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      key: const Key("google_map"),
      mapType: MapType.normal,
      initialCameraPosition: initialCamera,
      onMapCreated: onMapCreated,
      zoomControlsEnabled: false,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      mapToolbarEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: true,
      polygons: polygons,
      polylines: polylines,
      markers: markers,
      onTap: onTap,
      style: _hidePoiStyle,
      //onCameraMove: onCameraMove,
    );
  }
}