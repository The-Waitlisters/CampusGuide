import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLayer<T> extends StatelessWidget {
  final Future<List<T>> future;
  final bool hasPolygons;
  final void Function(List<T> data) onDataReady;

  final GlobalKey mapKey;
  final Future<GoogleMapController> controllerFuture;

  final void Function(LatLng latLng) onMapTapLatLng;

  final Widget map;

  const MapLayer({
    super.key,
    required this.future,
    required this.hasPolygons,
    required this.onDataReady,
    required this.mapKey,
    required this.controllerFuture,
    required this.onMapTapLatLng,
    required this.map,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading polygons: ${snapshot.error}'),
          );
        }

        final data = snapshot.data;
        if (!hasPolygons && data != null) {
          onDataReady(data);
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) async {
            final box = mapKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;

            final local = box.globalToLocal(event.position);
            final pixelRatio = MediaQuery.of(context).devicePixelRatio;

            final screenCoordinate = ScreenCoordinate(
              x: (local.dx * pixelRatio).round(),
              y: (local.dy * pixelRatio).round(),
            );

            final controller = await controllerFuture;
            if (mapKey.currentContext == null) return;

            final latLng = await controller.getLatLng(screenCoordinate);
            if (mapKey.currentContext == null) return;

            onMapTapLatLng(latLng);
          },
          child: SizedBox(
            key: mapKey,
            width: double.infinity,
            height: double.infinity,
            child: map,
          ),
        );
      },
    );
  }
}