// ignore_for_file: deprecated_member_use, prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:proj/data/data_parser.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proj/models/campus.dart';
import 'package:proj/models/location.dart';
import 'package:proj/widgets/home/poi_option_menu.dart';
import 'package:proj/services/markerIconLoader.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus_building.dart';
import 'package:geolocator/geolocator.dart';
import 'package:proj/services/building_locator.dart';
import 'package:proj/widgets/home/campus_map.dart';
import 'package:proj/widgets/home/results.dart';
import '../config/secrets.dart';
import '../main.dart';
import '../services/directions/directions_controller.dart';
import '../services/directions/transport_mode_strategy.dart';
import '../services/route_logic.dart';
import '../utilities/polygon_helper.dart';
import '../widgets/home/building_detail_sheet.dart';
import '../widgets/home/directions_card.dart';
import '../widgets/home/map_layer.dart';
import '../widgets/home/search_overlay.dart';
import 'indoor_map_screen.dart';
import '../widgets/use_as_start.dart';
import '../models/poi.dart';
import '../widgets/schedule/schedule_overlay.dart';
import '../models/course_schedule_entry.dart';
import '../services/concordia_api.dart';
import '../services/schedule_lookup.dart';

typedef MarkerImageLoader = Future<Uint8List> Function(String path, int width);

extension StringExtension on String {
  String capitalize() {
    List<String> current =
        "${this[0].toUpperCase()}${substring(1).toLowerCase()}".split(' ');
    String newOne = "";
    for (final b in current) {
      newOne += "${b[0].toUpperCase()}${b.substring(1).toLowerCase()} ";
    }

    return newOne;
  }
}

class HomeScreen extends StatefulWidget {
  final DataParser? dataParser;
  final BuildingLocator? buildingLocator;

  /// For tests: when non-null, used instead of the map's controller future
  /// so [ _goToCampus ] can complete without a real map.
  final Completer<GoogleMapController>? testMapControllerCompleter;

  final DirectionsController? testDirectionsController;

  const HomeScreen({
    super.key,
    this.dataParser,
    this.buildingLocator,
    this.testMapControllerCompleter,
    this.testDirectionsController,
    MarkerImageLoader? markerImageLoader,
  }) : markerImageLoader = markerImageLoader ?? defaultMarkerImageLoader;

  final MarkerImageLoader markerImageLoader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Public state type so tests can call [handleMapTap] to cover map-tap logic.
abstract class HomeScreenState extends State<HomeScreen> {
  // ignore: strict_top_level_inference
  get markers => [];

  /// Called when the map is tapped. Exposed for tests; production code calls
  /// this from [GoogleMap.onTap]. [sheetContext] should have a [Scaffold]
  /// ancestor (e.g. from LayoutBuilder in build); if null, [context] is used.
  void handleMapTap(LatLng point, [BuildContext? sheetContext]);
}

class _HomeScreenState extends HomeScreenState {
  bool? isAnnex;
  late DataParser data;
  GoogleMapController? _mapController;
  Campus _campus = Campus.sgw;
  // ignore: unused_field
  LatLng? _cursorPoint;
  LatLng? lastTap;
  CampusBuilding? _cursorBuilding;
  CampusBuilding? _startBuilding;
  CampusBuilding? _endBuilding;
  Poi? _startPoi;
  Poi? _endPoi;

  /// True when user chose destination first; route start is current GPS location.
  bool _startFromCurrentLocation = false;

  /// Shown when destination-first but location is unavailable.
  String? _locationRequiredMessage;

  /// When true, do not auto-apply default transport mode (user chose manually).
  bool _modeChangedByUser = false;
  late Future<List<CampusBuilding>> _buildingsFuture;
  List<Poi> poiPresent = [];
  final TextEditingController _searchController = TextEditingController();
  List<CampusBuilding> buildingsPresent = [];
  Set<Polygon> _polygons = {};
  PolygonId? _selectedId;
  Timer? _searchDebounce;
  Timer? _markerRebuildDebounce;
  final Map<PolygonId, CampusBuilding> _polygonToBuilding = {};
  bool campusChange = false;
  final GlobalKey _mapKey = GlobalKey();
  final List<MapLocation> _searchResults = <MapLocation>[];
  bool _showSearchResults = false;
  late final DirectionsController _directions;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _sheetController;
  static const double _sheetLiftMax = 210.0;

  late BuildingLocator _buildingLocator;

  StreamSubscription<Position>? _gpsSub;
  CampusBuilding? _currentBuildingFromGPS;

  bool isInBuilding = false;
  bool _showScheduleOverlay = false;

  final List<Marker> _markers = <Marker>[];

  LatLng locationPoint = LatLng(0, 0);

  bool firstRun = false;

  // ignore: unused_field
  bool _loading = false;

  bool showPoiSettings = false;
  bool restaurants = false;
  bool cafes = false;
  bool parks = false;
  bool parking = false;
  bool fastFood = false;
  bool nightClub = false;
  double nearbyPois = 0;
  String type = "";
  double distance = 0;
  bool notCampus = false;

  bool showResults = false;

  @override
  @visibleForTesting
  List<Marker> get markers => _markers;

  @override
  void initState() {
    super.initState();

    _initDependencies();
    _initDirections();
    _tryInitLocationTracking();
  }

  void resetFilters() {
    setState(() {
      restaurants = false;
      cafes = false;
      parks = false;
      parking = false;
      fastFood = false;
      nightClub = false;
      nearbyPois = 0;
      distance = 0;
      _markers.clear();
      poiPresent.clear();
    });
  }

  void applyFilters() {
    _loadNearbyPois(
      restaurants,
      cafes,
      parks,
      parking,
      fastFood,
      nightClub,
      nearbyPois,
      type,
      distance*1000
    );
  }

  double _iconSizeForZoom(double zoom) {
    const double minZoom = 13.0;
    const double maxZoom = 20.0;
    const double minSize = 24.0;
    const double maxSize = 56.0;
    final t = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minSize + t * (maxSize - minSize);
  }

  @visibleForTesting
  Future<void> simulatePointerDown(Offset position) async {
    GoogleMapController? controller;
    if (widget.testMapControllerCompleter != null) {
      controller = await widget.testMapControllerCompleter!.future;
    } else {
      controller = _mapController;
    }
    if (controller == null) return;
    final latLng = await controller.getLatLng(
      ScreenCoordinate(x: position.dx.round(), y: position.dy.round()),
    );
    setState(() {
      lastTap = latLng;
    });
  }

  void _initDependencies() {
    data = widget.dataParser ?? DataParser();
    _buildingLocator =
        widget.buildingLocator ??
        BuildingLocator(enterThresholdMeters: 15, exitThresholdMeters: 25);

    _refreshBuildingsFromParser();
  }

  void _initDirections() {
    _directions = widget.testDirectionsController ?? DirectionsController(
      client: GoogleDirectionsClient(apiKey: Secrets.directionsApiKey),
    );
    assert(() {
      if (Secrets.directionsApiKey.isEmpty) {
        debugPrint( // coverage:ignore-line
            'Directions API key is missing (DIRECTIONS_API_KEY not set).');
      }
      return true;
    }());
    _directions.addListener(() {
      if (!mounted) return;
      setState(() {}); // reflect polyline/loading/error in UI
    });
  }

  bool _isLocationPermissionDenied(LocationPermission permission) {
    return permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
  }

  Future<LocationPermission> _checkAndMaybeRequestLocationPermission({
    required bool requestIfDenied,
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (requestIfDenied && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<void> _tryInitLocationTracking() async {
    if (isE2EMode) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    final permission = await _checkAndMaybeRequestLocationPermission(
      requestIfDenied: true,
    );

    if (_isLocationPermissionDenied(permission)) {
      debugPrint('Location permission denied.');
      return;
    }

    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position pos) {
          final userPoint = LatLng(pos.latitude, pos.longitude);
          locationPoint = userPoint;
          final result = _buildingLocator.update(
            userPoint: userPoint,
            campus: _campus,
            buildings: buildingsPresent,
          );

          if (!mounted) return;

          final oldId = _currentBuildingFromGPS?.id;
          final newId = result.building?.id;

          setState(() {
            _currentBuildingFromGPS = result.building;

            final CampusBuilding? b = result.building;
            isInBuilding = b != null && isPointInPolygon(userPoint, b.boundary);
          });

          if (oldId != newId) {
            _refreshBuildingsFromParser();
          }
        });
  }

  void _refreshBuildingsFromParser() {
    _buildingsFuture = data.getBuildingInfoFromJSON().then((list) {
      if (!mounted) {
        return list;
      }

      setState(() {
        buildingsPresent = list;
        _polygons = _buildPolygons(list);
      });

      return list;
    });
  }

  Future<void> _loadNearbyPois(
    bool restaurant,
    bool cafe,
    bool park,
    bool parking,
    bool fastFood,
    bool nightClub,
    double nearbyPois,
    String type,
    double distance
  ) async {
    if (_mapController == null) return;

    setState(() {
      _loading = true;
      _markers.clear();
      poiPresent.clear();
    });

    try {
      type = type.toUpperCase();

      final double zoom = _mapController != null
          ? await _mapController!.getZoomLevel()
          : 15.0;
      final double logicalSize = _iconSizeForZoom(zoom);

      final Uint8List markIconResto = await widget.markerImageLoader(
        "assets/restaurant.png",
        logicalSize.round(),
      );

      final Uint8List markIconCoffee = await widget.markerImageLoader(
        "assets/coffee.png",
        logicalSize.round(),
      );

      final Uint8List markIconPark = await widget.markerImageLoader(
        "assets/park.png",
        logicalSize.round(),
      );

      final Uint8List markIconParking = await widget.markerImageLoader(
        "assets/parking.png",
        logicalSize.round(),
      );

      final Uint8List markIconFastFood = await widget.markerImageLoader(
        "assets/hamburger.png",
        logicalSize.round(),
      );

      final Uint8List markIconNightClub = await widget.markerImageLoader(
        "assets/night-club.png",
        logicalSize.round(),
      );

      final places;
      final places2;
      final places3;
      final places4;
      final places5;
      final places6;

      if (restaurant) {
        places = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['restaurant'],
          rankPreference: type,
        );
        _finishLoadingPois(places, markIconResto, logicalSize);
      }

      if (cafe) {
        places2 = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['cafe'],
          rankPreference: type,
        );
        _finishLoadingPois(places2, markIconCoffee, logicalSize);
      }

      if (park) {
        places3 = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['park'],
          rankPreference: type,
        );
        _finishLoadingPois(places3, markIconPark, logicalSize);
      }

      if (parking) {
        places4 = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['parking'],
          rankPreference: type,
        );
        _finishLoadingPois(places4, markIconParking, logicalSize);
      }

      if (fastFood) {
        places5 = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['fast_food_restaurant'],
          rankPreference: type,
        );
        _finishLoadingPois(places5, markIconFastFood, logicalSize);
      }

      if (nightClub) {
        places6 = await _searchNearbyPlaces(
          latitude: locationPoint.latitude,
          longitude: locationPoint.longitude,
          radiusMeters: distance,
          maxResultCount: nearbyPois,
          includedTypes: ['night_club'],
          rankPreference: type,
        );
        _finishLoadingPois(places6, markIconNightClub, logicalSize);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load places: $e')));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _finishLoadingPois(
    List<dynamic> places,
    Uint8List markIcon,
    double logicalSize,
  ) {
    final Set<Marker> newMarkers = places.map((place) {
      final placeId = place['id'] as String? ?? UniqueKey().toString();
      final displayName =
          (place['displayName']?['text'] as String?) ?? 'Unknown place';
      final location = place['location'] as Map<String, dynamic>? ?? {};
      final lat = (location['latitude'] as num).toDouble();
      final lng = (location['longitude'] as num).toDouble();

      String? primaryType = place['primaryType'] as String?;
      primaryType = primaryType!.replaceAll('_', ' ').capitalize();
      final rating = place['rating'].toDouble() ?? 0;
      final address = place['shortFormattedAddress'];

      final photos = (place['photos'] as List?) ?? [];

      List<String?> photoName = [];
      if (photos.isNotEmpty) {
        for (Map<String, dynamic> photo in photos) {
          photoName.add(
            buildPhotoUrl(
              photoName: photo['name'],
              apiKey: Secrets.directionsApiKey,
            ),
          );
        }
      }

      final regularOpeningHours =
          place['regularOpeningHours'] as Map<String, dynamic>?;
      final weekdayDescriptions =
          (regularOpeningHours?['weekdayDescriptions'] as List?)
              ?.cast<String>() ??
          const [];

      final openNow = regularOpeningHours?['openNow'] as bool?;

      Poi newPoi = Poi(
        id: placeId,
        name: displayName,
        boundary: LatLng(lat, lng),
        description: primaryType,
        openingHours: weekdayDescriptions,
        openNow: openNow,
        rating: rating,
        address: address,
        photoName: photoName,
        campus: _currentBuildingFromGPS?.campus ?? _campus,
      ); //set current building as campus, otherwise, set currently toggled campus

      poiPresent.add(newPoi);
      return Marker(
        markerId: MarkerId(placeId),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.fromBytes(
          markIcon,
          size: Size(logicalSize, logicalSize),
        ),
        onTap: () => setState(() {
          _showPoiDetailSheet(newPoi);
        }),
      );
    }).toSet();

    setState(() {
      _markers.addAll(newMarkers);
    });
  }

  String buildPhotoUrl({
    //Helper function to build photo url to be able to fetch with Places API
    required String photoName,
    required String apiKey,
    int maxWidthPx = 400,
  }) {
    return 'https://places.googleapis.com/v1/$photoName/media'
        '?key=$apiKey&maxWidthPx=$maxWidthPx';
  }

  Future<List<dynamic>> _searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required double maxResultCount,
    required String rankPreference,
    required List<String> includedTypes,
  }) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:searchNearby',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': Secrets.directionsApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.rating,places.regularOpeningHours,places.priceRange,places.userRatingCount,places.shortFormattedAddress,places.photos',
      },
      body: jsonEncode({
        'includedPrimaryTypes': includedTypes,
        'maxResultCount': maxResultCount,
        'rankPreference': rankPreference.toUpperCase(),
        'locationRestriction': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': radiusMeters,
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Places API error ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> jsonBody = jsonDecode(response.body);
    return (jsonBody['places'] as List<dynamic>?) ?? [];
  }

  CameraPosition get _initialCamera {
    final info = campusInfo[_campus]!;
    return CameraPosition(target: info.center, zoom: info.zoom);
  }

  Future<String> getPlaceMarks(LatLng coords) async {
    try {
      double x = coords.latitude;
      double y = coords.longitude;
      List<Placemark> placemarks = [];

      if (_cursorBuilding != null &&
          isPointInPolygon(coords, _cursorBuilding!.boundary)) {
        placemarks = await placemarkFromCoordinates(x, y);
      }

      String address = '';

      if (placemarks.isNotEmpty) {
        address =
            '${placemarks[0].street ?? ''}, '
            '${placemarks[0].locality ?? ''}, '
            '${placemarks[0].postalCode ?? ''}';
      }

      return address;
    } catch (e) {
      debugPrint("Error getting placemarks: $e");
      return "No Address";
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final String q = value.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() {
          _searchResults.clear();
          _showSearchResults = false;
        });
        return;
      }

      final List<MapLocation> totalResults = [];

      List<MapLocation> results = buildingsPresent
          .where(
            (b) =>
                b.name.toLowerCase().contains(q) ||
                (b.fullName ?? "").toLowerCase().contains(q),
          )
          .take(8)
          .toList();

      List<MapLocation> results2 = poiPresent
          .where(
            (b) =>
                b.name.toLowerCase().contains(q) ||
                (b.description ?? "").toLowerCase().contains(q),
          )
          .take(120)
          .toList();

      totalResults.addAll(results);
      totalResults.addAll(results2);

      setState(() {
        _searchResults
          ..clear()
          ..addAll(totalResults);
        _showSearchResults = totalResults.isNotEmpty;
      });
    });
  }

  /// Returns which campus (if any) contains [point] using building boundaries.
  Campus? _campusAtPoint(LatLng point) =>
      RouteLogic.campusAtPoint(point, buildingsPresent);

  /// Applies default transport mode. No-op if user changed mode or no destination.
  /// - Building-to-building: same campus → Walk, different campuses → Shuttle.
  /// - Current-location start: distance < 2.5 km → Walk, else → Shuttle.
  void _applyDefaultTransportMode({
    required Campus? endCampus,
    required Campus? startCampus,
    required LatLng? startPoint,
    required LatLng? endPoint,
    required bool isCurrentLocationStart,
  }) {
    if (_modeChangedByUser) return;
    final mode = RouteLogic.defaultMode(
      endCampus: endCampus,
      startCampus: startCampus,
      startPoint: startPoint,
      endPoint: endPoint,
      isCurrentLocationStart: isCurrentLocationStart,
    );
    if (mode != null) _directions.setMode(mode);
  }

  /// Resolves the route start point: from selected building or from current GPS when destination-first.
  Future<LatLng?> _getRouteStartPoint() async {
    if (_startBuilding != null) {
      return polygonCenter(_startBuilding!.boundary);
    }
    if (!_startFromCurrentLocation) return null;
    try {
      final permission = await _checkAndMaybeRequestLocationPermission(
        requestIfDenied: false,
      );
      if (_isLocationPermissionDenied(permission)) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('location timeout'),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateDirectionsIfReady() async {
    debugPrint(
      '_updateDirectionsIfReady start=${_startBuilding?.name ?? _startPoi?.name} end=${_endBuilding?.name ?? _endPoi?.name}',
    );

    if (_endBuilding == null && _endPoi == null) {
      setState(() => _locationRequiredMessage = null);
      await _directions.updateRoute(start: null, end: null);
      return;
    }

    var start;
    var end;

    if (_startPoi == null) {
      start = await _getRouteStartPoint();
    } else {
      start = _startPoi!.boundary;
    }

    if (_endPoi == null) {
      end = polygonCenter(_endBuilding!.boundary);
    } else {
      end = _endPoi!.boundary;
    }

    if (_startFromCurrentLocation && start == null) {
      setState(() {
        _locationRequiredMessage =
            'To create a route from your current location, please allow location access.';
      });
      await _directions.updateRoute(start: null, end: null);
      return;
    }

    setState(() => _locationRequiredMessage = null);

    final startCampus =
        _startBuilding?.campus ??
        (start != null ? _campusAtPoint(start) : null);
    var endCampus;
    if (_endPoi == null) {
      endCampus = _endBuilding!.campus;
    } else {
      endCampus = _endPoi!.campus;
    }
    _applyDefaultTransportMode(
      endCampus: endCampus,
      startCampus: startCampus,
      startPoint: start,
      endPoint: end,
      isCurrentLocationStart: _startFromCurrentLocation,
    );

    await _directions.updateRoute(
      start: start,
      end: end,
      startCampus: startCampus,
      endCampus: endCampus,
    );

    debugPrint(
      'Directions done: err=${_directions.state.errorMessage} '
      'points=${_directions.state.polyline?.points.length}',
    );

    if (start != null && _directions.state.polyline != null) {
      await _zoomToRoute(start, end); // coverage:ignore-line
    }
  }

  Future<void> _handleSetAsStart(CampusBuilding building) async {
    debugPrint('Set as Start: ${building.name}');
    setState(() {
      _startBuilding = building;
      _endBuilding = null;
      _startFromCurrentLocation = false;
      _locationRequiredMessage = null;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handleSetAsDestination(CampusBuilding building) async {
    debugPrint('Set as Destination: ${building.name}');
    setState(() {
      _endBuilding = building;
      if (_startBuilding == null && _startPoi == null) {
        _startFromCurrentLocation = true;
      }
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handlePoiAsStart(Poi poi) async {
    debugPrint('Set as Start: ${poi.name}');
    setState(() {
      _startPoi = poi;
      _endPoi = null;
      _startFromCurrentLocation = false;
      _locationRequiredMessage = null;
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _handlePoiAsDestination(Poi poi) async {
    debugPrint('Set as Destination: ${poi.name}');
    setState(() {
      _endPoi = poi;
      if (_startPoi == null && _startBuilding == null) {
        _startFromCurrentLocation = true;
      }
    });
    await _updateDirectionsIfReady();
  }

  Future<void> _zoomToRoute(LatLng a, LatLng b) async {
    final controller = widget.testMapControllerCompleter != null
        ? await widget.testMapControllerCompleter!.future // coverage:ignore-line
        : _mapController;
    if (controller == null) return;
    final bounds = boundsForRoute(a, b);

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _onBuildingTapped(CampusBuilding? building) {
    debugPrint('_onBuildingTapped called with: ${building?.name}');
    if (building == null) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not part of campus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Please select a shaded building'),
              ],
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        //final bool canSetStart = _startBuilding == null || (_startBuilding?.id != building.id);
        //final bool canSetEnd = _endBuilding == null || (_endBuilding?.id != building.id);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${building.campus.name.toUpperCase()} - ${building
                    .name} - ${building.fullName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(building.description ?? 'No description available'),

              const SizedBox(height: 16),

              Row(
                children: [
                  ElevatedButton(
                    onPressed: _startBuilding?.id == building.id
                        ? null
                        : () async {
                      Navigator.pop(context);
                      await _handleSetAsStart(building);
                    },
                    child: const Text('Set as Start'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _endBuilding?.id == building.id
                        ? null
                        : () async {
                      Navigator.pop(context);
                      await _handleSetAsDestination(building);
                    },
                    child: const Text('Set as Destination'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _goToCampus(Campus campus) async {
    final controller = widget.testMapControllerCompleter != null
        ? await widget.testMapControllerCompleter!.future
        : _mapController;
    if (controller == null) return;
    final info = campusInfo[campus]!;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: info.center, zoom: info.zoom),
      ),
    );

    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      //_currentBuildingFromGPS = null;
    });
  }

  Set<Polygon> _buildPolygons(List<CampusBuilding> buildings) {
    _polygonToBuilding.clear();

    return buildings.map((e) {
      final pid = PolygonId(e.id);
      _polygonToBuilding[pid] = e;
      final bool isActiveGps = _currentBuildingFromGPS?.id == e.id;
      if (isActiveGps) {
        isInBuilding =
            isActiveGps; // As soon as there's a building we are in, global variable is set to true
      }
      return Polygon(
        polygonId: pid,
        points: e.boundary,
        consumeTapEvents: true,
        fillColor: isActiveGps
            ? const Color(0x803197F6)
            : const Color(0x80912338),
        strokeColor: isActiveGps ? Colors.blue : const Color(0xFF741C2C),
        strokeWidth: isActiveGps ? 3 : 2,
        onTap: () {
          _cursorBuilding = e;
          _updateOnTap(pid);
        },
      );
    }).toSet();
  }

  void _showPoiDetailSheet(Poi poi) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;
      notCampus = false;
      _sheetController?.close();
      _sheetController = null;

      _sheetController = scaffoldState.showBottomSheet((context) {
        return BuildingDetailSheet(
          poi: poi,
          isPoi: true,
          isAnnex: false,
          startBuilding: _startBuilding,
          endBuilding: _endBuilding,
          startPoi: _startPoi,
          endPoi: _endPoi,
          onSetStart: () async {
            await _handlePoiAsStart(poi);
            _sheetController?.close();
            _sheetController = null;
          },
          onSetDestination: () async {
            await _handlePoiAsDestination(poi);
            _sheetController?.close();
            _sheetController = null;
          },
        );
      });
      _attachSheetAnimation(_sheetController);
    });
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _cursorPoint = point;
      _cursorBuilding = findBuildingAtPoint(point, buildingsPresent, _campus);
    });
  }

  @override
  void handleMapTap(LatLng point, [BuildContext? sheetContext]) {
    if (_sheetController != null) {
      _sheetController?.close();
      _sheetController = null;
      return;
    }

    final CampusBuilding? building = findBuildingAtPoint(
      point,
      buildingsPresent,
      _campus,
    );

    lastTap = point;

    if (building == null) {
      _showNotCampusSheet();
    } else {
      _cursorBuilding = building;
      _updateOnTap(PolygonId(building.id));
    }

    setState(() {
      _cursorPoint = point;
    });
  }

  //logic separated
  void _showNotCampusSheet() {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) {
      return;
    }
    notCampus = true;
    _sheetController?.close();
    _sheetController = scaffoldState.showBottomSheet(
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not part of campus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Please select a shaded building'),
          ],
        ),
      ),
    );
    _attachSheetAnimation(_sheetController);
  }

  void _attachSheetAnimation(PersistentBottomSheetController? controller) {
    if (mounted) {
      setState(() {});
    }
  }

  void _updateOnTap(PolygonId id) {
    final building = _polygonToBuilding[id];
    if (building == null) return;
    final bool isAnnex = building.fullName?.contains("Annex") ?? false;
    final tap = lastTap;
    if (tap == null) return;

    _handleMapTap(tap);
    _applyPolygonSelection(id, building);
    _showBuildingDetailSheet(building, isAnnex);
  }

  void _applyPolygonSelection(PolygonId id, CampusBuilding building) {
    setState(() {
      _selectedId = id;
      _cursorBuilding = building;
      _polygons = _polygons.map((p) => _recolorPolygon(p)).toSet();
    });
  }

  Polygon _recolorPolygon(Polygon p) {
    final isSelected = p.polygonId == _selectedId;
    final isGps =
        _currentBuildingFromGPS != null &&
        p.polygonId == PolygonId(_currentBuildingFromGPS!.id);

    const Color selectedFill = Color.fromARGB(255, 124, 115, 29);
    const Color gpsFill = Color(0x803197F6);
    const Color defaultFill = Color(0x80912338);

    const Color selectedStroke = Colors.yellow;
    const Color gpsStroke = Colors.blue;
    const Color defaultStroke = Color(0xFF741C2C);

    Color fillColor;
    if (isSelected) {
      fillColor = selectedFill;
    } else if (isGps) {
      fillColor = gpsFill;
    } else {
      fillColor = defaultFill;
    }

    Color strokeColor;
    if (isSelected) {
      strokeColor = selectedStroke;
    } else if (isGps) {
      strokeColor = gpsStroke;
    } else {
      strokeColor = defaultStroke;
    }

    return p.copyWith(fillColorParam: fillColor, strokeColorParam: strokeColor);
  }

  void _showBuildingDetailSheet(CampusBuilding building, bool isAnnex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;
      notCampus = false;
      _sheetController?.close();
      _sheetController = null;

      _sheetController = scaffoldState.showBottomSheet((context) {
        return BuildingDetailSheet(
          building: building,
          isAnnex: isAnnex,
          startBuilding: _startBuilding,
          endBuilding: _endBuilding,
          onSetStart: () async {
            await _handleSetAsStart(building);
            _sheetController?.close();
            _sheetController = null;
          },
          onSetDestination: () async {
            await _handleSetAsDestination(building);
            _sheetController?.close();
            _sheetController = null;
          },
          onViewIndoorMap: () {
            _sheetController?.close();
            _sheetController = null;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IndoorMapScreen(building: building),
              ),
            );
          },
          isPoi: false,
        );
      });
      _attachSheetAnimation(_sheetController);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('The Waitlisters')),
      body: Stack(
        children: [
          if (!isE2EMode) _buildMapLayer(),
          _buildGpsStatusCard(),
          _buildCampusToggleCard(),
          _buildDirectionsCard(),
          _buildSearchOverlay(),
          //_buildPOISection(),
          if (_currentBuildingFromGPS != null &&
              (_startBuilding == null && _startPoi == null))
            _buildSetCurrentAsStartCard(),
          if (isE2EMode) _buildE2ECampusLabel(),
          if (showPoiSettings)
            PoiOptionMenu(
              restaurants: restaurants,
              cafes: cafes,
              parks: parks,
              currentSliderValue: nearbyPois,
              sortBy: type,
              parking: parking,
              fastFood: fastFood,
              nightClub: nightClub,
              onRestaurantsChanged: (value) {
                setState(() {
                  restaurants = value ?? false;
                });
              },
              onCafesChanged: (value) {
                setState(() {
                  cafes = value ?? false;
                });
              },
              onParksChanged: (value) {
                setState(() {
                  parks = value ?? false;
                });
              },
              onNearbyChanged: (value) {
                setState(() {
                  nearbyPois = value ?? 0;
                });
              },
              onSortByChanged: (value) {
                setState(() {
                  type = value ?? '';
                });
              },
              onReset: resetFilters,
              onApply: applyFilters,
              onClose: () {
                setState(() {
                  showPoiSettings = false;
                });
              },
              onParkingChanged: (value) {
                setState(() {
                  parking = value ?? false;
                });
              },
              onFastFoodChanged: (value) {
                setState(() {
                  fastFood = value ?? false;
                });
              },
              onNightClubChanged: (value) {
                setState(() {
                  nightClub = value ?? false;
                });
              },
              onShow: () {
                setState(() {
                  showPoiSettings = false;
                  showResults = true;
                });
              }, distanceSliderValue: distance, 
              onDistanceChanged: (value) {  
                setState(() {
                  distance = value ?? 0;
                });
              },
            ),
          if (_showScheduleOverlay)
            ScheduleOverlay(
              onClose: () {
                setState(() {
                  _showScheduleOverlay = false;
                });
              },
              onRoomSelected: (CourseScheduleEntry entry) {
                debugPrint('Selected room: ${entry.room}');

                setState(() {
                  _showScheduleOverlay = false;
                });
              },
              lookupService: ScheduleLookupService(
                api: ConcordiaApiService(
                  userId: dotenv.env['CONCORDIA_USER_ID'] ?? '',
                  apiKey: dotenv.env['CONCORDIA_API_KEY'] ?? '',
                ),
              ),
            ),

          if (showResults)
            Results(
              poiPresent: poiPresent,
              locationPoint: locationPoint,
              onSelect: (b) {
                setState(() {
                  _showPoiDetailSheet(b);
                });
              }, onClose: () { setState(() {
                showResults = false;
              }); },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            showPoiSettings = true;
          });
        },
        label: const Text('Points of Interest'),
        icon: const Icon(Icons.place),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
    );
  }

  Widget _buildMapLayer() {
    return MapLayer<CampusBuilding>(
      future: _buildingsFuture,
      hasPolygons: _polygons.isNotEmpty,
      onDataReady: (data) {
        _polygons = _buildPolygons(data);
      },
      mapKey: _mapKey,
      controller: _mapController,
      onMapTapLatLng: (latLng) {
        lastTap = latLng;
      },
      map: _buildGoogleMapWidget(),
    );
  }

  Widget _buildGoogleMapWidget() {
    return CampusMap(
      initialCamera: _initialCamera,
      polygons: _polygons,
      polylines: _directions.state.polyline == null
          ? <Polyline>{}
          : <Polyline>{_directions.state.polyline!}, // coverage:ignore-line
      markers: Set<Marker>.of(_markers),
      myLocationEnabled: !isE2EMode,
      myLocationButtonEnabled: !isE2EMode,
      onMapCreated: (GoogleMapController controller) {
        // coverage:ignore-start
        setState(() {
          _mapController = controller;
        });
      },
      onTap: (LatLng point) {
        handleMapTap(point);

        if (_searchResults.isNotEmpty) {
          setState(() {
            _showSearchResults = true;
          });
        }

        FocusScope.of(context).unfocus();
        // coverage:ignore-end
      },

      // onCameraMove: _onCameraMove,
    );
  }

  Widget _buildGpsStatusCard() {
    final text =
        _currentBuildingFromGPS?.fullName ??
        _currentBuildingFromGPS?.name ??
        'Not in a building';
    return _topCard(
      top: 12,
      elevation: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCampusToggleCard() {
    return _topCard(
      top: 70,
      padding: const EdgeInsets.all(8),
      child: CampusToggle(selected: _campus, onChanged: _goToCampus),
    );
  }

  Widget _buildSetCurrentAsStartCard() {
    if (_currentBuildingFromGPS == null ||
        !isInBuilding ||
        _startBuilding != null ||
        _startPoi != null) {
      return const SizedBox.shrink();
    }

    if (_endBuilding != null || _endPoi != null) {
      return const SizedBox.shrink();
    }

    final bool sheetOpen = _sheetController != null;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 0,
      bottom: sheetOpen ? (notCampus ? 90 : _sheetLiftMax) : 25,
      child: UseAsStart(
        selected: _currentBuildingFromGPS!,
        onSetStart: () {
          debugPrint(
            'Set as Start pressed for ${_currentBuildingFromGPS?.name}',
          );

          setState(() {
            _startBuilding = _currentBuildingFromGPS;
            _endBuilding = null;
          });

          _updateDirectionsIfReady();

          if (_sheetController != null) { // coverage:ignore-start
            _sheetController?.close();
            setState(() {
              _sheetController = null;
            });
          } // coverage:ignore-end
        },
      ),
    );
  }

  Widget _topCard({
    required double top,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    double? elevation,
  }) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top, 12, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Card(
            elevation: elevation,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsCard() {
    return DirectionsCard(
      startBuilding: _startBuilding,
      startPoi: _startPoi,
      endBuilding: _endBuilding,
      endPoi: _endPoi,
      useCurrentLocationAsStart:
          _startFromCurrentLocation && _startBuilding == null,
      locationRequiredMessage: _locationRequiredMessage,
      isLoading: _directions.state.isLoading,
      errorMessage: _directions.state.errorMessage,
      polyline: _directions.state.polyline,
      durationText: _directions.state.durationText,
      distanceText: _directions.state.distanceText,
      onCancel: () {
        setState(() {
          _startPoi = null;
          _startBuilding = null;
          _endBuilding = null;
          _endPoi = null;
          _startFromCurrentLocation = false;
          _locationRequiredMessage = null;
          _modeChangedByUser = false;
        });
        _directions.updateRoute(start: null, end: null);
        debugPrint('Directions cancelled');
      },
      onRetry: _updateDirectionsIfReady,
      placeholderMessage: _directions.state.placeholderMessage,
      selectedModeParam: _directions.mode.modeParam,
      onModeChanged: (modeParam) {
        setState(() => _modeChangedByUser = true);
        _directions.setMode(strategyForModeParam(modeParam));
        _updateDirectionsIfReady();
      },
    );
  }

  Widget _buildSearchOverlay() {
    return SearchOverlay(
      controller: _searchController,
      showResults: _showSearchResults,
      results: _searchResults,
      onChanged: _onSearchChanged,
      onTapField: () {
        if (_searchResults.isNotEmpty) {
          setState(() {
            _showSearchResults = true;
          });
        }
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchResults.clear();
          _showSearchResults = false;
        });
      },
      onMenuSelected: (String value) {
        if (value == 'schedule') {
          setState(() {
            _showScheduleOverlay = true;
          });
        }
      },
      onSelectResult: (b) {
        debugPrint('Tapped search result: ${b.name}');
        _searchController.text = b.name;

        setState(() {
          _showSearchResults = false;
          _searchResults.clear();
        });
        if (b is CampusBuilding) {
          _onBuildingTapped(b);
        } else if (b is Poi) {
          _showPoiDetailSheet(b);
        }
      },
    );
  }

  Widget _buildE2ECampusLabel() { // coverage:ignore-start
    return Text(
      _campus == Campus.loyola ? "campus:loyola" : "campus:sgw",
      key: const Key("campus_label"),
    );
  } // coverage:ignore-end

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _markerRebuildDebounce?.cancel();
    _searchController.dispose();
    _gpsSub?.cancel();
    _directions.dispose();
    super.dispose();
  }

  //to call _updateOnTap() in tests.
  @visibleForTesting
  void simulatePolygonTap(PolygonId id, LatLng tapPoint) {
    lastTap = tapPoint;
    _updateOnTap(id);
  }

  /// For tests: trigger the onTap handler of the Polygon built in `_buildPolygons`.
  /// This covers the `Polygon.onTap` closure (cursor building assignment + _updateOnTap).
  @visibleForTesting
  void triggerPolygonOnTap(PolygonId id) {
    final Polygon? poly = _polygons.cast<Polygon?>().firstWhere(
      (p) => p != null && p.polygonId == id,
      orElse: () => null,
    );
    poly?.onTap?.call();
  }

  /// For tests: invoke the private `_onBuildingTapped` method, including the null branch.
   @visibleForTesting
  void simulateBuildingTap(CampusBuilding? building) {
    _onBuildingTapped(building);
  }

  /// For tests: complete the internal map controller completer so the Listener
  /// `onPointerDown` logic can await `_controller.future`.
  @visibleForTesting
  void completeInternalMapController(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  //test sheet render and bypass calling the tap methods.
  @visibleForTesting
  void simulateBuildingSelection(CampusBuilding building, LatLng tapPoint) {
    lastTap = tapPoint;
    final bool isAnnex = building.fullName?.contains("Annex") ?? false;

    _showBuildingDetailSheet(building, isAnnex);

    setState(() {
      _cursorBuilding = building;
      _cursorPoint = tapPoint;
    });
  }

  @visibleForTesting
  void setCurrentBuildingFromGPS(CampusBuilding building) {
    setState(() {
      _currentBuildingFromGPS = building;
    });
  }

  @visibleForTesting
  void simulateCampusChange(Campus campus) {
    setState(() {
      _campus = campus;
      _buildingLocator.reset();
      _currentBuildingFromGPS = null;
      _polygons = _buildPolygons(buildingsPresent);
    });
  }

  @visibleForTesting
  void simulateGpsLocation(LatLng point) {
    final result = _buildingLocator.update(
      userPoint: point,
      campus: _campus,
      buildings: buildingsPresent,
    );
    setState(() {
      _currentBuildingFromGPS = result.building;
      _polygons = _buildPolygons(buildingsPresent);
    });
  }

  @visibleForTesting
  Set<Polygon> get testPolygons => _polygons;

  @visibleForTesting // coverage:ignore-line
  Polyline? get testPolyline => _directions.state.polyline; // coverage:ignore-line

  @visibleForTesting // coverage:ignore-line
  String get testSelectedModeParam => _directions.mode.modeParam; // coverage:ignore-line

  @visibleForTesting
  Future<void> zoomToRouteForTest(LatLng a, LatLng b) {
    return _zoomToRoute(a, b);
  }

  @visibleForTesting
  void setIsInBuildingForTest(bool value) {
    setState(() {
      isInBuilding = value;
    });
  }

  @visibleForTesting
  void setShowScheduleOverlayForTest(bool value) {
    setState(() {
      _showScheduleOverlay = value;
    });
  }

  @visibleForTesting
  void setMapControllerForTest(GoogleMapController controller) {
    _mapController = controller;
  }
}

// For tests: Make sure we cover route-zoom math without a real map
LatLngBounds boundsForRoute(LatLng a, LatLng b) {
  final sw = LatLng(
    a.latitude < b.latitude ? a.latitude : b.latitude,
    a.longitude < b.longitude ? a.longitude : b.longitude,
  );
  final ne = LatLng(
    a.latitude > b.latitude ? a.latitude : b.latitude,
    a.longitude > b.longitude ? a.longitude : b.longitude,
  );

  return LatLngBounds(southwest: sw, northeast: ne);
}
