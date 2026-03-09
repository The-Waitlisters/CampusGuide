import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/widgets/home/building_detail_content.dart';

class BuildingDetailSheet extends StatelessWidget {
  final CampusBuilding building;
  final bool isAnnex;
  final CampusBuilding? startBuilding;
  final CampusBuilding? endBuilding;

  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback? onViewIndoorMap;

  const BuildingDetailSheet({
    super.key,
    required this.building,
    required this.isAnnex,
    required this.startBuilding,
    required this.endBuilding,
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
            child: BuildingDetailContent(
              building: building,
              isAnnex: isAnnex,
              startBuilding: startBuilding,
              endBuilding: endBuilding,
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