import 'package:flutter/material.dart';

class PoiOptionMenu extends StatelessWidget {
  final bool restaurants;
  final bool cafes;
  final bool parks;
  final bool parking;
  final bool fastFood;
  final bool nightClub;

  final double currentSliderValue;
  final double distanceSliderValue;

  final String sortBy;

  final ValueChanged<bool?> onRestaurantsChanged;
  final ValueChanged<bool?> onCafesChanged;
  final ValueChanged<bool?> onParksChanged;
  final ValueChanged<bool?> onParkingChanged;
  final ValueChanged<bool?> onFastFoodChanged;
  final ValueChanged<bool?> onNightClubChanged;
  final ValueChanged<double?> onNearbyChanged;
  final ValueChanged<String?> onSortByChanged;
  final ValueChanged<double?> onDistanceChanged;

  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback onClose;
  final VoidCallback onShow;

  const PoiOptionMenu({
    super.key,
    required this.restaurants,
    required this.cafes,
    required this.parks,
    required this.currentSliderValue,
    required this.onRestaurantsChanged,
    required this.onCafesChanged,
    required this.onParksChanged,
    required this.onNearbyChanged,
    required this.onReset,
    required this.onApply,
    required this.onClose,
    required this.sortBy,
    required this.onSortByChanged,
    required this.parking,
    required this.fastFood,
    required this.nightClub,
    required this.onParkingChanged,
    required this.onFastFoodChanged,
    required this.onNightClubChanged,
    required this.onShow,
    required this.distanceSliderValue,
    required this.onDistanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Card(
              elevation: 8,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Points of interest filter',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: restaurants,
                            onChanged: onRestaurantsChanged,
                          ),
                          Text('Restaurants'),
                          Checkbox(value: cafes, onChanged: onCafesChanged),
                          Text('Cafes'),
                          Checkbox(value: parks, onChanged: onParksChanged),
                          Text('Parks'),
                        ],
                      ),
                      Wrap(
                        children: [
                          Checkbox(value: parking, onChanged: onParkingChanged),
                          Text('Parking'),
                          Checkbox(
                            value: fastFood,
                            onChanged: onFastFoodChanged,
                          ),
                          Text('Fast Food'),
                          Checkbox(
                            value: nightClub,
                            onChanged: onNightClubChanged,
                          ),
                          Text('Night Clubs'),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Text(
                        'Set nearby points of interest per selected category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: currentSliderValue,
                        onChanged: onNearbyChanged,
                        divisions: 5,
                        max: 20,
                        label: currentSliderValue.round().toString(),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Set radius (km)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: distanceSliderValue,
                        onChanged: onDistanceChanged,
                        divisions: 5,
                        max: 5,
                        label: distanceSliderValue.round().toString(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sort by',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Transform.scale(
                        scale: 0.8,
                        alignment: Alignment.bottomLeft,
                        child: DropdownMenu(
                          enableFilter: true,
                          requestFocusOnTap: true,
                          leadingIcon: const Icon(Icons.search),
                          label: const Text('Select...'),
                          inputDecorationTheme: const InputDecorationTheme(
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 5.0),
                          ),
                          onSelected: onSortByChanged,
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(
                              value: 'POPULARITY',
                              label: 'Popularity',
                            ),
                            DropdownMenuEntry(
                              value: 'DISTANCE',
                              label: 'Distance',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onReset,
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: onApply,
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: OutlinedButton(
                          onPressed: onShow,
                          child: const Text('Show results'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
