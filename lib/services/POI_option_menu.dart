import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/poi.dart';

class POIOptionMenu extends StatelessWidget {

  final LatLng position;
  final List<Poi> allPOIs;
  final void Function(String) onDistanceSubmit;
  final void Function(String) onAmountSubmit;
  final double Function(LatLng, LatLng) calcDist;

  const POIOptionMenu({
    super.key,

    required this.position,
    required this.allPOIs,
    required this.onDistanceSubmit,
    required this.onAmountSubmit,
    required this.calcDist,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 12,
      right: 12,
      child: Card(
        child: Column(
          children: [
            TextField(maxLength: 4,
              onSubmitted: onDistanceSubmit,
              decoration: InputDecoration(
                hintText: "Maximum distance (km)",
              ),
            ),

            TextField(maxLength: 2,
              onSubmitted: onAmountSubmit,
              decoration: InputDecoration(
                hintText: "Maximum amount of POIs",
              ),
            ),

            for(var p in allPOIs)
              Row(
                children: [
                  Image.asset(p.poiType, height: 35, width: 35,),
                  Text(" : ${p.name}"),
                  Spacer(),
                  Text("Distance: ${calcDist(position, p.boundary).toStringAsFixed(2)} km",),
                ]
              )
          ],
        ),
      ),

    );
  }

}