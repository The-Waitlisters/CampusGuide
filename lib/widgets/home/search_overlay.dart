import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/location.dart';
import 'package:proj/models/poi.dart';

class SearchOverlay extends StatelessWidget {
  final TextEditingController controller;
  final bool showResults;
  final List<CampusBuilding> results;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onTapField;
  final ValueChanged<CampusBuilding> onSelectResult;

  const SearchOverlay({
    super.key,
    required this.controller,
    required this.showResults,
    required this.results,
    required this.onChanged,
    required this.onClear,
    required this.onMenuSelected,
    required this.onTapField,
    required this.onSelectResult,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search building...',
                  border: InputBorder.none,
                  prefixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.menu),
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'schedule',
                        child: Text('Schedule'),
                      ),
                    ],
                  ),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClear,
                  ),
                ),
                onChanged: onChanged,
                onTap: onTapField,
              ),
            ),
          ),
          if (showResults)
            SearchResultsCard(
              results: results.cast<MapLocation>().toList(),
              onSelect: (loc) => onSelectResult(loc as CampusBuilding),
            ),
        ],
      ),
    );
  }
}

class SearchResultsCard extends StatelessWidget {
  final List<MapLocation> results;
  final ValueChanged<MapLocation> onSelect;

  const SearchResultsCard({
    super.key,
    required this.results,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final loc = results[i];

          String? subtitle;
          if (loc is CampusBuilding) {
            final fn = loc.fullName;
            if (fn != null && fn.trim().isNotEmpty) subtitle = fn;
          } else if (loc is Poi) {
            final desc = loc.description;
            if (desc != null && desc.isNotEmpty) subtitle = desc;
          }

          return ListTile(
            dense: true,
            title: Text(loc.name),
            subtitle: subtitle != null ? Text(subtitle) : null,
            onTap: () => onSelect(loc),
          );
        },
      ),
    );
  }
}