import 'package:flutter/material.dart';
import 'package:proj/models/campus_building.dart';
import 'package:proj/models/location.dart';
import 'package:proj/models/poi.dart';

class SearchOverlay extends StatelessWidget {
  final TextEditingController controller;
  final bool showResults;
  final List<MapLocation> results;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSearch;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onTapField;
  final ValueChanged<MapLocation> onSelectResult;

  const SearchOverlay({
    super.key,
    required this.controller,
    required this.showResults,
    required this.results,
    required this.onChanged,
    required this.onClear,
    required this.onSearch,
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
                      PopupMenuItem(value: 'schedule', child: Text('Schedule')),
                    ],
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClear,
                        ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: controller.text.isEmpty ? null : onSearch,
                      ),
                    ],
                  ),
                ),
                onChanged: onChanged,
                onTap: onTapField,
              ),
            ),
          ),
          if (showResults)
            SearchResultsCard(results: results, onSelect: onSelectResult),
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
        // ignore: body_might_complete_normally_nullable
        itemBuilder: (context, i) {
          final b = results[i];
          if (b is CampusBuilding) {
            return ListTile(
              dense: true,
              title: Text(b.name),
              subtitle: (b.fullName != null && b.fullName!.trim().isNotEmpty)
                  ? Text(b.fullName!)
                  : null,
              onTap: () => onSelect(b),
            );
          } else if (b is Poi) {
            return ListTile(
              dense: true,
              title: Text(b.name),
              subtitle:
              (b.description != null && b.description!.trim().isNotEmpty)
                  ? Text(b.description!)
                  : null,
              onTap: () => onSelect(b),
            );
          }
        },
      ),
    );
  }
}