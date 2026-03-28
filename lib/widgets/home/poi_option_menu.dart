import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/poi.dart';

class POIOptionMenu extends StatelessWidget {

  final LatLng position;
  final List<Poi> allPOIs;
  final int currentPOICount;
  final void Function(String) onDistanceSubmit;
  final void Function(String) onAmountSubmit;
  final double Function(LatLng, LatLng) calcDist;
  final VoidCallback onTap;

  const POIOptionMenu({
    super.key,
    required this.onTap,
    required this.position,
    required this.allPOIs,
    required this.currentPOICount,
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
            ElevatedButton(
                onPressed: onTap,
                child: Text("X")
            ),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  onSubmitted: onDistanceSubmit,
                  decoration: InputDecoration(
                    hintText: 'Maximum distance (km)',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  onSubmitted: onAmountSubmit,
                  decoration: InputDecoration(
                    hintText: 'Points of Interest to show',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            
            SizedBox(
              width: 500,
              height: currentPOICount <= 5 ? currentPOICount * 43.0 : 200,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for(var i = 0; i < currentPOICount; i++)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                              children: [
                                Image.asset(allPOIs[i].poiType, height: 35, width: 35,),
                                Text(" : ${allPOIs[i].name}"),
                                Spacer(),
                                Text("Distance: ${calcDist(position, allPOIs[i].boundary).toStringAsFixed(2)} km",),
                              ]
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        )
      )
    );
  }

}
