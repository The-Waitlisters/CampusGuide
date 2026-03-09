import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLayer<T> extends StatefulWidget {
  final Future<List<T>> future;
  final bool hasPolygons;
  final void Function(List<T> data) onDataReady;
  final GlobalKey mapKey;
  final GoogleMapController? controller;
  final void Function(LatLng latLng) onMapTapLatLng;
  final Widget map;

  const MapLayer({
    super.key,
    required this.future,
    required this.hasPolygons,
    required this.onDataReady,
    required this.mapKey,
    this.controller,
    required this.onMapTapLatLng,
    required this.map,
  });

  @override
  State<MapLayer<T>> createState() => _MapLayerState<T>();
}

class _MapLayerState<T> extends State<MapLayer<T>> {

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading polygons: ${snapshot.error}'));
        }

        final data = snapshot.data;
        if (!widget.hasPolygons && data != null) {
          widget.onDataReady(data);
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) async {
            final controller = widget.controller;
            if (controller == null || !mounted) return;

            final box = widget.mapKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;

            final local = box.globalToLocal(event.position);
            final pixelRatio = MediaQuery.of(context).devicePixelRatio;

            final screenCoordinate = ScreenCoordinate(
              x: (local.dx * pixelRatio).round(),
              y: (local.dy * pixelRatio).round(),
            );

            try {
              final latLng = await controller.getLatLng(screenCoordinate);
              if (!mounted) return;
              widget.onMapTapLatLng(latLng);
            } catch (e) {
              debugPrint('MapLayer: controller disposed during pointer event: $e');
            }
          },
          child: SizedBox(
            key: widget.mapKey,
            width: double.infinity,
            height: double.infinity,
            child: widget.map,
          ),
        );
      },
    );
  }
}