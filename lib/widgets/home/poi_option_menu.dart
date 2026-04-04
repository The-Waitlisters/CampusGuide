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
    required this.parking,
    required this.fastFood,
    required this.nightClub,
    required this.currentSliderValue,
    required this.distanceSliderValue,
    required this.sortBy,
    required this.onRestaurantsChanged,
    required this.onCafesChanged,
    required this.onParksChanged,
    required this.onParkingChanged,
    required this.onFastFoodChanged,
    required this.onNightClubChanged,
    required this.onNearbyChanged,
    required this.onSortByChanged,
    required this.onDistanceChanged,
    required this.onReset,
    required this.onApply,
    required this.onClose,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Points of interest filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.cancel),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category checkboxes (order: 0=restaurants, 1=cafes, 2=parks,
          //                              3=parking, 4=fastFood, 5=nightClub)
          CheckboxListTile(
            title: const Text('Restaurants'),
            value: restaurants,
            onChanged: onRestaurantsChanged,
          ),
          CheckboxListTile(
            title: const Text('Cafes'),
            value: cafes,
            onChanged: onCafesChanged,
          ),
          CheckboxListTile(
            title: const Text('Parks'),
            value: parks,
            onChanged: onParksChanged,
          ),
          CheckboxListTile(
            title: const Text('Parking'),
            value: parking,
            onChanged: onParkingChanged,
          ),
          CheckboxListTile(
            title: const Text('Fast food'),
            value: fastFood,
            onChanged: onFastFoodChanged,
          ),
          CheckboxListTile(
            title: const Text('Night clubs'),
            value: nightClub,
            onChanged: onNightClubChanged,
          ),

          const SizedBox(height: 8),

          // Nearby slider (first)
          const Text('Nearby radius'),
          Slider(
            value: currentSliderValue,
            min: 0,
            max: 5000,
            onChanged: onNearbyChanged,
          ),

          const SizedBox(height: 8),

          // Distance slider (last)
          const Text('Max distance'),
          Slider(
            value: distanceSliderValue,
            min: 0,
            max: 10000,
            onChanged: onDistanceChanged,
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: onReset, child: const Text('Reset')),
              ElevatedButton(onPressed: onApply, child: const Text('Apply')),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onShow,
            child: const Text('Show results'),
          ),
        ],
      ),
    );
  }
}
