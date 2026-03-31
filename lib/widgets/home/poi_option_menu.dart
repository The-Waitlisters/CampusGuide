import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/poi.dart';

class PoiOptionMenu extends StatelessWidget {

  final bool restaurants;
  final bool cafes;
  final bool parks;

  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;

  final double currentSliderValue;
  
  final String sortBy;

  final ValueChanged<bool?> onRestaurantsChanged;
  final ValueChanged<bool?> onCafesChanged;
  final ValueChanged<bool?> onParksChanged;
  final ValueChanged<double?> onNearbyChanged;
  final ValueChanged<String?> onSortByChanged;

  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback onClose;

  const PoiOptionMenu({
    super.key,
    required this.restaurants,
    required this.cafes,
    required this.parks,
    required this.minPriceController,
    required this.maxPriceController,
    required this.currentSliderValue,
    required this.onRestaurantsChanged,
    required this.onCafesChanged,
    required this.onParksChanged,
    required this.onNearbyChanged,
    required this.onReset,
    required this.onApply,
    required this.onClose, required this.sortBy, required this.onSortByChanged,
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
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
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
                              'Filter places',
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
                      Row(children: [Checkbox(value: restaurants, onChanged: onRestaurantsChanged), Text('Restaurants'), Checkbox(value: cafes, onChanged: onCafesChanged), Text('Cafes'), Checkbox(value: parks, onChanged: onParksChanged), Text('Parks')], )
                      
                      ,// Row(children: [Checkbox(value: restaurants, onChanged: onRestaurantsChanged), Text('Restaurants')],)
                      //,
                      
                      const SizedBox(height: 12),
                      const Text(
                        'Price range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min',
                                hintText: '0',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max',
                                hintText: '100',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                        const Text(
                        'Set number of points of interest',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Slider(value: currentSliderValue, onChanged: onNearbyChanged, divisions: 5, max: 20, label: currentSliderValue.round().toString(),),
                      const SizedBox(height: 12),
                        const Text(
                        'Sort by',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Transform.scale(scale: 0.8, alignment: Alignment.bottomLeft,child: 
                      DropdownMenu(
                        enableFilter: true,
                        requestFocusOnTap: true,
                        leadingIcon: const Icon(Icons.search),
                        label: const Text('Select...'),
                        inputDecorationTheme: const InputDecorationTheme(
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 5.0),
                        ),
                        onSelected: onSortByChanged,
                        dropdownMenuEntries: [DropdownMenuEntry(value: sortBy, label: 'Popularity'), DropdownMenuEntry(value: sortBy, label: 'Distance')],
                      ),),
                       
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
