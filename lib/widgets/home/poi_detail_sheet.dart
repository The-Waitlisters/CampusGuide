import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/poi.dart';
import 'package:proj/widgets/home/poi_detail_content.dart';

class PoiDetailSheet extends StatelessWidget {
  final Poi building;
  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;
  final Poi? startPoi;
  final Poi? endPoi;
  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback? onViewIndoorMap;

  const PoiDetailSheet({
    super.key,
    required this.building,
    this.startBuilding,
    this.endBuilding,
    this.startPoi,
    this.endPoi,
    required this.onSetStart,
    required this.onSetDestination,
    this.onViewIndoorMap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: PoiDetailContent(
              building: building,
              startBuilding: startBuilding,
              endBuilding: endBuilding,
              startPoi: startPoi,
              endPoi: endPoi,
              onSetStart: onSetStart,
              onSetDestination: onSetDestination,
              onViewIndoorMap: onViewIndoorMap,
            ),
          ),
        );
      },
    );
  }
}