import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/campus.dart';
import '../models/campus_building.dart';

typedef FindBuildingAtPoint = CampusBuilding? Function(
    LatLng point,
    List<CampusBuilding> buildings,
    Campus campus,
    );

typedef ShowNotCampusSheet = void Function(BuildContext ctx);
typedef ShowBuildingDetailSheet = void Function(CampusBuilding building, bool isAnnex);
typedef UpdateState = void Function(
    {
    LatLng? cursorPoint,
    CampusBuilding? cursorBuilding,
    PolygonId? selectedId,
    Set<Polygon>? polygons,
    });

class MapInteractionController {
  MapInteractionController({
    required FindBuildingAtPoint findBuildingAtPoint,
    required ShowNotCampusSheet showNotCampusSheet,
    required ShowBuildingDetailSheet showBuildingDetailSheet,
    required UpdateState updateState,
  })  : _findBuildingAtPoint = findBuildingAtPoint,
        _showNotCampusSheet = showNotCampusSheet,
        _showBuildingDetailSheet = showBuildingDetailSheet,
        _updateState = updateState;

  final FindBuildingAtPoint _findBuildingAtPoint;
  final ShowNotCampusSheet _showNotCampusSheet;
  final ShowBuildingDetailSheet _showBuildingDetailSheet;
  final UpdateState _updateState;

  PersistentBottomSheetController? sheetController;
  LatLng? lastTap;

  void handleMapTap({
    required LatLng point,
    required BuildContext sheetContext,
    required List<CampusBuilding> buildings,
    required Campus campus,
    required Map<PolygonId, CampusBuilding> polygonToBuilding,
    required Set<Polygon> polygons,
  }) {
    if (sheetController != null) {
      sheetController?.close();
      sheetController = null;
      return;
    }

    lastTap = point;

    final CampusBuilding? building = _findBuildingAtPoint(point, buildings, campus);

    if (building == null) {
      _showNotCampusSheet(sheetContext);
      _updateState(cursorPoint: point, cursorBuilding: null);
      return;
    }

    _updateState(cursorPoint: point, cursorBuilding: building);

    _updateOnTap(
      PolygonId(building.id),
      polygonToBuilding: polygonToBuilding,
      polygons: polygons,
    );
  }

  void updateOnPolygonTap({
    required PolygonId polygonId,
    required Map<PolygonId, CampusBuilding> polygonToBuilding,
    required Set<Polygon> polygons,
  }) {
    _updateOnTap(
      polygonId,
      polygonToBuilding: polygonToBuilding,
      polygons: polygons,
    );
  }

  void _updateOnTap(
      PolygonId id, {
        required Map<PolygonId, CampusBuilding> polygonToBuilding,
        required Set<Polygon> polygons,
      }) {
    final building = polygonToBuilding[id];
    if (building == null) {
      return;
    }

    final bool isAnnex = building.fullName?.contains("Annex") ?? false;

    final updatedPolygons = _applyPolygonSelection(
      polygons: polygons,
      selectedId: id,
    );

    _updateState(
      selectedId: id,
      cursorBuilding: building,
      polygons: updatedPolygons,
    );

    _showBuildingDetailSheet(building, isAnnex);
  }

  Set<Polygon> _applyPolygonSelection({
    required Set<Polygon> polygons,
    required PolygonId selectedId,
  }) {
    return polygons.map((p) {
      final isSelected = (p.polygonId == selectedId);
      return p.copyWith(
        fillColorParam: isSelected
            ? const Color.fromARGB(255, 124, 115, 29)
            : const Color(0x80912338),
        strokeColorParam: isSelected ? Colors.yellow : const Color(0xFF741C2C),
      );
    }).toSet();
  }
}